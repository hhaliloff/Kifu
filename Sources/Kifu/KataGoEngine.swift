import Foundation
import GoCore

/// Uses the official KataGo engine embedded in this process through the
/// Objective-C-compatible C bridge. The model and native engine are shared so
/// ordinary moves, hints, and reviews reuse their neural cache and search tree.
struct KataGoEngineFactory: GoEngineFactory {
    func makeEngine() -> any GoEngine { KataGoEngineService.shared }
}

private actor KataGoEngineService: GoEngine {
    static let shared = KataGoEngineService()

    private var handle: OpaquePointer?
    private var startupAttempted = false
    private var syncedPosition: SyncedPosition?

    func search(request: EngineRequest) async throws -> SearchResult {
        try Task.checkCancellation()
        let engineHandle = try ensureStarted()
        try Task.checkCancellation()
        try synchronize(request, using: engineHandle)
        try Task.checkCancellation()
        try setSearchLimits(request.config, using: engineHandle)
        try Task.checkCancellation()

        let maxMoves = request.config.tacticalFocus ? 24 : 12
        var command = "kata-search_analyze_cancellable \(request.colorToPlay.gtpToken) 10 maxmoves \(maxMoves) rootInfo true"
        if request.config.tacticalFocus {
            let focus = Self.tacticalFocusVertices(on: request.board, toPlay: request.colorToPlay)
            if !focus.isEmpty {
                command += " focus \(focus.joined(separator: ",")) 0.5"
            }
        }
        let stopSignal = GTPStopSignal(handle: engineHandle)
        let timeLimit = min(max(request.config.timeLimit ?? 4, 0.5), 30)
        let timeout = DispatchWorkItem { stopSignal.stop() }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + timeLimit + 2,
            execute: timeout
        )

        do {
            let response = try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try stopSignal.beginAnalysis(command)
                return try readResponse(using: engineHandle)
            } onCancel: {
                stopSignal.stop()
            }
            stopSignal.finish()
            timeout.cancel()
            try Task.checkCancellation()
            let result = try parse(response, request: request)
            guard result.simulations > 0 else { throw KataGoError.noSearchResult }
            return result
        } catch {
            stopSignal.finish()
            timeout.cancel()
            throw error
        }
    }

    private func ensureStarted() throws -> OpaquePointer {
        if let handle { return handle }
        guard !startupAttempted else { throw KataGoError.startupFailed }
        guard let configURL = Self.resourceURL(name: "Kifu-iOS", extension: "cfg"),
              let modelURL = Self.resourceURL(name: "kata1-b10c128-s1141046784-d204142634.txt", extension: "gz") else {
            throw KataGoError.missingResources
        }
        // KataGo initializes process-global tables once. Retrying a failed
        // native startup in this process triggers an assertion in that setup.
        startupAttempted = true
        let created = configURL.path.withCString { configPath in
            modelURL.path.withCString { modelPath in
                katago_gtp_create(configPath, modelPath)
            }
        }
        guard let created else { throw KataGoError.startupFailed }
        handle = created
        return created
    }

    private static func resourceURL(name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "KataGo")
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension)
    }

    private func synchronize(_ request: EngineRequest, using handle: OpaquePointer) throws {
        let base = PositionBase(request: request)
        let reconstructed = Self.replayPosition(request)
        let historyMatchesBoard = reconstructed.isLegal
            && Self.boardSignature(request.board) == Self.boardSignature(reconstructed.board)

        if let syncedPosition,
           historyMatchesBoard,
           syncedPosition.base == base,
           request.context.moveHistory.starts(with: syncedPosition.moves) {
            let additions = request.context.moveHistory.dropFirst(syncedPosition.moves.count)
            var expectedBoard = syncedPosition.board
            var canExtend = true
            for move in additions {
                if let point = move.point {
                    guard case .played = expectedBoard.play(color: move.color, at: point) else {
                        canExtend = false
                        break
                    }
                } else {
                    expectedBoard.pass()
                }
                do {
                    try send("play \(move.color.gtpToken) \(move.point.map { $0.gtpVertex(on: request.board.size) } ?? "pass")", using: handle)
                } catch {
                    canExtend = false
                    break
                }
            }
            if canExtend && Self.boardSignature(request.board) == Self.boardSignature(expectedBoard) {
                self.syncedPosition = SyncedPosition(base: base, moves: request.context.moveHistory, board: expectedBoard)
                return
            }
        }

        try send("boardsize \(request.board.size.n)", using: handle)
        try send("clear_board", using: handle)
        try send("kata-set-rules \(request.context.ruleset == .chinese ? "chinese-ogs" : "japanese")", using: handle)
        try send("komi \(request.context.komi)", using: handle)

        var historyReplaySucceeded = historyMatchesBoard
        if historyReplaySucceeded {
            do {
                try setUpInitialPosition(for: request, using: handle)
                for move in request.context.moveHistory {
                    try send("play \(move.color.gtpToken) \(move.point.map { $0.gtpVertex(on: request.board.size) } ?? "pass")", using: handle)
                }
            } catch {
                historyReplaySucceeded = false
            }
        }
        if !historyReplaySucceeded {
            // SGF editors and position-analysis screens may hand us a board
            // that is not exactly represented by a legal move history.
            // Start from that explicit position rather than analyze stale data.
            try send("clear_board", using: handle)
            let stones = request.board.stones.map {
                "\($0.color.gtpToken) \($0.point.gtpVertex(on: request.board.size))"
            }.joined(separator: " ")
            try send(stones.isEmpty ? "set_position" : "set_position \(stones)", using: handle)
        }
        syncedPosition = SyncedPosition(base: base, moves: request.context.moveHistory, board: request.board)
    }

    private func setUpInitialPosition(for request: EngineRequest, using handle: OpaquePointer) throws {
        let blackSetup = request.context.setupBlackStones
        let whiteSetup = request.context.setupWhiteStones
        if !blackSetup.isEmpty, whiteSetup.isEmpty,
           request.context.handicap == blackSetup.count {
            let vertices = blackSetup.map { $0.gtpVertex(on: request.board.size) }.joined(separator: " ")
            try send("set_free_handicap \(vertices)", using: handle)
        } else if !blackSetup.isEmpty || !whiteSetup.isEmpty {
            let placements = blackSetup.map { "black \($0.gtpVertex(on: request.board.size))" }
                + whiteSetup.map { "white \($0.gtpVertex(on: request.board.size))" }
            try send("set_position \(placements.joined(separator: " "))", using: handle)
        }
    }

    private func setSearchLimits(_ config: EngineConfig, using handle: OpaquePointer) throws {
        let visits = min(max(config.simulations, 100), 50_000)
        let seconds = min(max(config.timeLimit ?? 4, 0.5), 30)
        let json: [String: Any] = [
            "maxVisits": visits,
            "maxTime": seconds,
            "allowResignation": false,
            "ponderingEnabled": false,
            // These parameters persist in the shared GTP engine, so set both
            // on every request. Analysis must not sample a game move and then
            // present that sample as the strongest candidate.
            "chosenMoveTemperature": config.deterministicMoveSelection ? 0.0 : 0.1,
            "chosenMoveTemperatureEarly": config.deterministicMoveSelection ? 0.0 : 0.5,
            "winLossUtilityFactor": 1.0,
            "staticScoreUtilityFactor": config.maximizeWinProbability ? 0.0 : 0.1,
            "dynamicScoreUtilityFactor": config.maximizeWinProbability ? 0.0 : 0.3
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        guard let payload = String(data: data, encoding: .utf8) else { throw KataGoError.invalidParameters }
        try send("kata-set-params \(payload)", using: handle)
    }

    /// Give the normal search extra visits at liberties of pressured groups.
    /// A vital move can have a very low neural prior, so an ordinary search
    /// may never try it. Focus explores legal moves without forcing a choice;
    /// the analysis ranking below compares the resulting evaluations.
    private static func tacticalFocusVertices(on board: Board, toPlay: StoneColor) -> [String] {
        var visitedStones = Set<Point>()
        var groups: [(priority: Int, size: Int, liberties: [Point])] = []
        for stone in board.stones {
            guard !visitedStones.contains(stone.point),
                  let group = board.group(at: stone.point) else { continue }
            visitedStones.formUnion(group.stones)
            let liberties = group.libertyCount
            guard (1...4).contains(liberties),
                  group.stoneCount > 1 || liberties <= 2 else { continue }
            let priority = min(group.stoneCount, 8) * (5 - liberties)
            groups.append((priority, group.stoneCount, group.liberties.sorted()))
        }

        groups.sort {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.size > $1.size
        }
        var focused = Set<Point>()
        var vertices: [String] = []
        for group in groups {
            for point in group.liberties where !focused.contains(point) {
                guard board.isLegal(color: toPlay, at: point) else { continue }
                focused.insert(point)
                vertices.append(point.gtpVertex(on: board.size))
                if vertices.count == 12 { return vertices }
            }
        }
        return vertices
    }

    private func send(_ command: String, using handle: OpaquePointer) throws {
        try enqueue(command, using: handle)
        let response = try readResponse(using: handle)
        guard response.first == "=" else { throw KataGoError.protocolFailure(response.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func enqueue(_ command: String, using handle: OpaquePointer) throws {
        let status = command.withCString { katago_gtp_send_command(handle, $0) }
        guard status == 0 else { throw KataGoError.commandFailed(command) }
    }

    private func readResponse(using handle: OpaquePointer) throws -> String {
        var buffer = [CChar](repeating: 0, count: 16_384)
        var responseLength = 0
        var status = buffer.withUnsafeMutableBufferPointer { storage in
            katago_gtp_read_response(handle, storage.baseAddress, storage.count, &responseLength)
        }
        if status == 1 {
            buffer = [CChar](repeating: 0, count: responseLength + 1)
            status = buffer.withUnsafeMutableBufferPointer { storage in
                katago_gtp_read_response(handle, storage.baseAddress, storage.count, &responseLength)
            }
        }
        guard status == 0 else { throw KataGoError.responseUnavailable }
        return String(cString: buffer)
    }

    private func parse(_ response: String, request: EngineRequest) throws -> SearchResult {
        let latestReport = response.split(whereSeparator: { $0.isNewline })
            .last(where: { $0.contains("info move") })
        let tokens = latestReport.map { $0.split(whereSeparator: \.isWhitespace).map(String.init) } ?? []
        var rankedCandidates: [(order: Int, inputIndex: Int, utility: Double?, candidate: MoveCandidate)] = []
        var rootWinRate: Double?
        var rootScoreLead: Double?
        var rootScoreMean: Double?
        var rootScoreSelfplay: Double?
        var rootVisits = 0
        var index = 0

        while index < tokens.count {
            if tokens[index] == "info", index + 2 < tokens.count, tokens[index + 1] == "move" {
                let vertex = tokens[index + 2]
                index += 3
                var visits = 0
                var winRate = 0.5
                var scoreLead: Double?
                var scoreMean: Double?
                var scoreSelfplay: Double?
                var order: Int?
                var utility: Double?
                while index + 1 < tokens.count,
                      !(tokens[index] == "info" && tokens[index + 1] == "move"),
                      tokens[index] != "rootInfo" {
                    let key = tokens[index]
                    let value = tokens[index + 1]
                    switch key {
                    case "visits": visits = Int(value) ?? visits
                    case "winrate": winRate = Double(value) ?? winRate
                    case "scoreLead": scoreLead = Double(value)
                    case "scoreMean": scoreMean = Double(value)
                    case "scoreSelfplay": scoreSelfplay = Double(value)
                    case "order": order = Int(value)
                    case "utility": utility = Double(value)
                    default: break
                    }
                    index += 1
                }
                let point: Point?
                if vertex.lowercased() == "pass" {
                    point = nil
                } else if let parsed = Point(gtpVertex: vertex, size: request.board.size) {
                    point = parsed
                } else {
                    throw KataGoError.protocolFailure("Invalid candidate vertex: \(vertex)")
                }
                let score = scoreLead ?? scoreMean ?? scoreSelfplay ?? 0
                let candidate = MoveCandidate(point: point, visits: visits,
                                              winRate: winRate,
                                              scoreMean: Self.blackPerspective(score, toPlay: request.colorToPlay))
                rankedCandidates.append((order ?? rankedCandidates.count,
                                         rankedCandidates.count, utility, candidate))
                continue
            }
            if tokens[index] == "rootInfo" {
                index += 1
                while index + 1 < tokens.count {
                    let key = tokens[index]
                    let value = tokens[index + 1]
                    switch key {
                    case "winrate": rootWinRate = Double(value)
                    case "scoreLead": rootScoreLead = Double(value)
                    case "scoreMean": rootScoreMean = Double(value)
                    case "scoreSelfplay": rootScoreSelfplay = Double(value)
                    case "visits": rootVisits = Int(value) ?? rootVisits
                    default: break
                    }
                    index += 1
                }
                break
            }
            index += 1
        }

        // `order` is KataGo's own ranking. The separate final `play` command
        // is a game-move choice and can differ when sampling is enabled.
        let engineOrder = rankedCandidates.sorted {
            $0.order == $1.order ? $0.inputIndex < $1.inputIndex : $0.order < $1.order
        }
        let displayOrder: [(order: Int, inputIndex: Int, utility: Double?, candidate: MoveCandidate)]
        if request.config.maximizeWinProbability {
            // Root `order` penalizes moves explored only through GTP focus:
            // they have zero edge visits even after hundreds of full searches.
            // Compare their win-only expected utility with ordinary candidates
            // once both have enough visits to avoid one-visit outliers.
            let minimumVisits = max(100, rootVisits / 20)
            let evaluated = engineOrder.filter {
                $0.candidate.visits >= minimumVisits && $0.utility?.isFinite == true
            }.sorted {
                if $0.utility != $1.utility { return ($0.utility ?? -.infinity) > ($1.utility ?? -.infinity) }
                if $0.candidate.visits != $1.candidate.visits { return $0.candidate.visits > $1.candidate.visits }
                return $0.order < $1.order
            }
            let evaluatedIndices = Set(evaluated.map { $0.inputIndex })
            displayOrder = evaluated + engineOrder.filter { !evaluatedIndices.contains($0.inputIndex) }
        } else {
            displayOrder = engineOrder
        }
        let candidates = displayOrder.map { $0.candidate }
        let nativeMove = try Self.finalMove(in: response, size: request.board.size)
        let bestMove = request.config.maximizeWinProbability && !candidates.isEmpty
            ? candidates[0].point : nativeMove
        let winRateForBlack = rootWinRate.map { request.colorToPlay == .black ? $0 : 1 - $0 }
            ?? candidates.first.map { request.colorToPlay == .black ? $0.winRate : 1 - $0.winRate }
            ?? 0.5
        let scoreForBlack = (rootScoreLead ?? rootScoreMean ?? rootScoreSelfplay)
            .map { Self.blackPerspective($0, toPlay: request.colorToPlay) }
            ?? candidates.first?.scoreMean ?? 0

        return SearchResult(bestMove: bestMove,
                            winRateBlack: winRateForBlack,
                            scoreMeanBlack: scoreForBlack,
                            simulations: rootVisits > 0 ? rootVisits : candidates.reduce(0) { $0 + $1.visits },
                            candidates: candidates)
    }

    private static func finalMove(in response: String, size: BoardSize) throws -> Point? {
        for line in response.split(whereSeparator: { $0.isNewline }).reversed() {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.first == "play" else { continue }
            guard parts.count == 2 else {
                throw KataGoError.protocolFailure(String(line))
            }
            let vertex = String(parts[1])
            if vertex.lowercased() == "cancelled" { throw KataGoError.noSearchResult }
            if vertex.lowercased() == "pass" { return nil }
            guard let point = Point(gtpVertex: vertex, size: size) else {
                throw KataGoError.protocolFailure("Invalid final vertex: \(vertex)")
            }
            return point
        }
        throw KataGoError.protocolFailure(response.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func blackPerspective(_ value: Double, toPlay: StoneColor) -> Double {
        toPlay == .black ? value : -value
    }

    private static func boardSignature(_ board: Board) -> String {
        board.stones.map { "\($0.color.rawValue):\($0.point.x):\($0.point.y)" }.joined(separator: ";")
    }

    private static func replayPosition(_ request: EngineRequest) -> ReplayedPosition {
        var board = Board(size: request.board.size, superko: request.context.ruleset == .chinese)
        var isLegal = true
        for point in request.context.setupBlackStones { board.place(color: .black, at: point) }
        for point in request.context.setupWhiteStones { board.place(color: .white, at: point) }
        for move in request.context.moveHistory {
            if let point = move.point {
                guard case .played = board.play(color: move.color, at: point) else {
                    isLegal = false
                    board.place(color: move.color, at: point)
                    continue
                }
            } else {
                board.pass()
            }
        }
        return ReplayedPosition(board: board, isLegal: isLegal)
    }
}

private struct ReplayedPosition {
    let board: Board
    let isLegal: Bool
}

private struct PositionBase: Equatable {
    let size: BoardSize
    let ruleset: Ruleset
    let komi: Double
    let handicap: Int
    let black: [Point]
    let white: [Point]

    init(request: EngineRequest) {
        size = request.board.size
        ruleset = request.context.ruleset
        komi = request.context.komi
        handicap = request.context.handicap
        black = request.context.setupBlackStones
        white = request.context.setupWhiteStones
    }
}

private struct SyncedPosition {
    let base: PositionBase
    var moves: [GameRecord.Move]
    let board: Board
}

private enum KataGoError: Error {
    case missingResources
    case startupFailed
    case invalidParameters
    case commandFailed(String)
    case responseUnavailable
    case protocolFailure(String)
    case noSearchResult
}

private final class GTPStopSignal: @unchecked Sendable {
    private let lock = NSLock()
    private let handle: OpaquePointer
    private var analysisStarted = false
    private var cancellationRequested = false
    private var finished = false

    init(handle: OpaquePointer) { self.handle = handle }

    func beginAnalysis(_ command: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !cancellationRequested, !finished else { throw CancellationError() }
        let status = command.withCString { katago_gtp_send_command(handle, $0) }
        guard status == 0 else { throw KataGoError.commandFailed(command) }
        analysisStarted = true
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        cancellationRequested = true
        guard analysisStarted else { return }
        analysisStarted = false
        _ = "".withCString { katago_gtp_send_command(handle, $0) }
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        finished = true
    }
}

private extension StoneColor {
    var gtpToken: String { self == .black ? "B" : "W" }
}

private extension Point {
    func gtpVertex(on size: BoardSize) -> String { "\(Self.humanLetter(forColumn: x))\(size.n - y)" }

    init?(gtpVertex: String, size: BoardSize) {
        if gtpVertex.lowercased() == "pass" { return nil }
        guard let point = Point.parse(human: gtpVertex, size: size) else { return nil }
        self = point
    }
}
