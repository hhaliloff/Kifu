// MARK: - Game record (main line) + SGF conversion

import Foundation

/// A game record: metadata + a linear main line of moves. Variations are
/// represented by the richer `SGFGame` tree when needed (puzzles, analysis).
public struct GameRecord: Codable, Sendable, Equatable {
    public struct SetupEdit: Codable, Sendable, Equatable {
        public var afterMove: Int
        public var black: [Point]
        public var white: [Point]
        public var empty: [Point]
        public var nextToPlay: StoneColor?

        public init(afterMove: Int, black: [Point] = [], white: [Point] = [],
                    empty: [Point] = [], nextToPlay: StoneColor? = nil) {
            self.afterMove = afterMove
            self.black = black
            self.white = white
            self.empty = empty
            self.nextToPlay = nextToPlay
        }
    }

    public struct Move: Codable, Sendable, Hashable {
        public var color: StoneColor
        /// nil = pass.
        public var point: Point?
        public var comment: String?

        public init(color: StoneColor, point: Point?, comment: String? = nil) {
            self.color = color
            self.point = point
            self.comment = comment
        }
    }

    public var boardSize: BoardSize
    public var ruleset: Ruleset
    public var komi: Double
    /// Handicap count as recorded in `HA` (0 = even game).
    public var handicap: Int
    /// Setup black stones (`AB`).
    public var handicapStones: [Point]
    /// Setup white stones (`AW`).
    public var initialWhiteStones: [Point]
    /// Setup changes that occur between moves in imported SGF files.
    public var setupEdits: [SetupEdit]
    public var playerBlack: String?
    public var playerWhite: String?
    public var blackRank: String?
    public var whiteRank: String?
    /// ISO date string (`DT`).
    public var date: String?
    public var event: String?
    public var result: GameResult?
    /// Main line of moves.
    public var moves: [Move]
    public var applicationName: String?
    public var gameName: String?
    /// Explicit side to play at the root position (`PL`), useful for setup positions.
    public var nextToPlay: StoneColor?

    public init(boardSize: BoardSize,
                ruleset: Ruleset = .chinese,
                komi: Double = 7.5,
                handicap: Int = 0,
                handicapStones: [Point] = [],
                initialWhiteStones: [Point] = [],
                setupEdits: [SetupEdit] = [],
                playerBlack: String? = nil,
                playerWhite: String? = nil,
                blackRank: String? = nil,
                whiteRank: String? = nil,
                date: String? = nil,
                event: String? = nil,
                result: GameResult? = nil,
                moves: [Move] = [],
                applicationName: String? = nil,
                gameName: String? = nil,
                nextToPlay: StoneColor? = nil) {
        self.boardSize = boardSize
        self.ruleset = ruleset
        self.komi = komi
        self.handicap = handicap
        self.handicapStones = handicapStones
        self.initialWhiteStones = initialWhiteStones
        self.setupEdits = setupEdits
        self.playerBlack = playerBlack
        self.playerWhite = playerWhite
        self.blackRank = blackRank
        self.whiteRank = whiteRank
        self.date = date
        self.event = event
        self.result = result
        self.moves = moves
        self.applicationName = applicationName
        self.gameName = gameName
        self.nextToPlay = nextToPlay
    }
}

// MARK: - Record ↔ Board

extension GameRecord {
    public func prefix(_ moveCount: Int) -> GameRecord {
        var copy = self
        copy.moves = Array(moves.prefix(max(0, min(moveCount, moves.count))))
        copy.setupEdits = setupEdits.filter { $0.afterMove <= copy.moves.count }
        if copy.moves.count != moves.count { copy.result = nil }
        return copy
    }

    public func position(after moveCount: Int) -> Board {
        prefix(moveCount).replay().board
    }

    public func sideToPlay(after moveCount: Int) -> StoneColor {
        let count = max(0, min(moveCount, moves.count))
        if let override = setupEdits.last(where: { $0.afterMove == count && $0.nextToPlay != nil })?.nextToPlay {
            return override
        }
        let retained = moves.prefix(count)
        return retained.last?.color.opponent ?? nextToPlay
            ?? (handicap > 0 ? .white : .black)
    }

    public static func setupPosition(_ board: Board, toPlay: StoneColor,
                                     ruleset: Ruleset = .chinese, komi: Double? = nil) -> GameRecord {
        GameRecord(boardSize: board.size, ruleset: ruleset,
                   komi: komi ?? ruleset.defaultKomi,
                   handicapStones: board.stones.filter { $0.color == .black }.map(\.point).sorted(),
                   initialWhiteStones: board.stones.filter { $0.color == .white }.map(\.point).sorted(),
                   applicationName: "Kifu:1.0", nextToPlay: toPlay)
    }

    /// Builds a board by applying setup stones and replaying the main line.
    /// Illegal moves in imported records are applied with raw placement
    /// (SGF spec: viewers must be lenient); they are reported in the result.
    public func replay() -> (board: Board, illegalMoveIndices: [Int]) {
        var board = Board(size: boardSize, superko: ruleset == .chinese)
        for p in handicapStones { board.place(color: .black, at: p) }
        for p in initialWhiteStones { board.place(color: .white, at: p) }
        func apply(_ edit: SetupEdit) {
            for p in edit.empty { board.clear(at: p) }
            for p in edit.black { board.place(color: .black, at: p) }
            for p in edit.white { board.place(color: .white, at: p) }
        }
        for edit in setupEdits where edit.afterMove == 0 { apply(edit) }
        var illegal: [Int] = []
        for (idx, move) in moves.enumerated() {
            if let p = move.point {
                if case .played = board.play(color: move.color, at: p) {
                    // ok
                } else {
                    illegal.append(idx)
                    board.place(color: move.color, at: p)
                }
            } else {
                board.pass()
            }
            for edit in setupEdits where edit.afterMove == idx + 1 { apply(edit) }
        }
        return (board, illegal)
    }
}

// MARK: - Record ↔ SGF

public enum GameRecordSGF {
    /// Serializes the record as a minimal valid SGF FF[4] file.
    public static func sgfString(for record: GameRecord) -> String {
        let root = SGFNode()
        root.set("GM", ["1"])
        root.set("FF", ["4"])
        root.set("CA", ["UTF-8"])
        root.set("AP", [record.applicationName ?? "Kifu:1.0"])
        root.set("SZ", ["\(record.boardSize.n)"])
        root.set("KM", [formatKomi(record.komi)])
        root.set("RU", [record.ruleset.sgfName])
        if let toPlay = record.nextToPlay {
            root.set("PL", [toPlay == .black ? "B" : "W"])
        }
        if record.handicap >= 2 {
            root.set("HA", ["\(record.handicap)"])
        }
        if !record.handicapStones.isEmpty {
            root.set("AB", record.handicapStones.map { SGFParser.sgfString($0) })
        }
        if !record.initialWhiteStones.isEmpty {
            root.set("AW", record.initialWhiteStones.map { SGFParser.sgfString($0) })
        }
        if let pb = record.playerBlack { root.set("PB", [pb]) }
        if let pw = record.playerWhite { root.set("PW", [pw]) }
        if let br = record.blackRank { root.set("BR", [br]) }
        if let wr = record.whiteRank { root.set("WR", [wr]) }
        if let dt = record.date { root.set("DT", [dt]) }
        if let ev = record.event { root.set("EV", [ev]) }
        if let gn = record.gameName { root.set("GN", [gn]) }
        if let result = record.result { root.set("RE", [result.sgfValue]) }

        var currentNode = root
        for index in 0...record.moves.count {
            for edit in record.setupEdits where edit.afterMove == index {
                let node = SGFNode()
                if !edit.black.isEmpty { node.set("AB", edit.black.map { SGFParser.sgfString($0) }) }
                if !edit.white.isEmpty { node.set("AW", edit.white.map { SGFParser.sgfString($0) }) }
                if !edit.empty.isEmpty { node.set("AE", edit.empty.map { SGFParser.sgfString($0) }) }
                if let next = edit.nextToPlay { node.set("PL", [next == .black ? "B" : "W"]) }
                currentNode.children.append(node)
                currentNode = node
            }
            guard index < record.moves.count else { break }
            let move = record.moves[index]
            let node = SGFNode()
            let value = move.point.map { SGFParser.sgfString($0) } ?? ""
            switch move.color {
            case .black: node.set("B", [value])
            case .white: node.set("W", [value])
            }
            if let c = move.comment, !c.isEmpty { node.set("C", [c]) }
            currentNode.children.append(node)
            currentNode = node
        }
        return SGFWriter.write(game: SGFGame(root: root))
    }

    /// Parses SGF text and converts the **first** game to a record (main line).
    public static func parse(_ text: String) throws -> GameRecord {
        guard let record = try parseAll(text).first else { throw SGFError.emptyInput }
        return record
    }

    /// Parses every game and variation in an SGF collection as separate lines.
    public static func parseAll(_ text: String) throws -> [GameRecord] {
        let games = try SGFParser.parse(text)
        guard !games.isEmpty else { throw SGFError.emptyInput }
        var records: [GameRecord] = []
        for game in games {
            if let rawSize = game.root.firstValue("SZ"),
               (Int(rawSize).flatMap(BoardSize.init(rawValue:))) == nil {
                throw SGFError.unsupportedBoardSize
            }
            let firstIndex = records.count
            func visit(_ node: SGFNode, path: [SGFNode]) throws {
                guard records.count < 2_000 else { throw SGFError.tooManyNodes }
                let nextPath = path + [node]
                if node.children.isEmpty {
                    records.append(record(from: game, nodes: nextPath))
                } else {
                    for child in node.children { try visit(child, path: nextPath) }
                }
            }
            try visit(game.root, path: [])
            if records.count - firstIndex > 1 {
                for index in firstIndex..<records.count {
                    let original = records[index].gameName ?? "SGF"
                    records[index].gameName = "\(original) · \(index - firstIndex + 1)"
                }
            }
        }
        return records
    }

    /// Converts an SGF game tree to a record (main line only).
    public static func record(from game: SGFGame) -> GameRecord {
        var nodes: [SGFNode] = []
        var node: SGFNode? = game.root
        while let current = node {
            nodes.append(current)
            node = current.children.first
        }
        return record(from: game, nodes: nodes)
    }

    private static func record(from game: SGFGame, nodes: [SGFNode]) -> GameRecord {
        let root = game.root
        let sizeNum = Int(root.firstValue("SZ") ?? "19") ?? 19
        let size = BoardSize(rawValue: min(19, max(2, sizeNum))) ?? .nineteen

        var handicapStones: [Point] = []
        var whiteStones: [Point] = []
        if let ab = root.values(for: "AB") {
            handicapStones.append(contentsOf: expandPoints(ab))
        }
        if let aw = root.values(for: "AW") {
            whiteStones.append(contentsOf: expandPoints(aw))
        }
        let rootEmpty = expandPoints(root.values(for: "AE") ?? [])
        handicapStones.removeAll { rootEmpty.contains($0) }
        whiteStones.removeAll { rootEmpty.contains($0) }
        let handicap = Int(root.firstValue("HA") ?? "") ?? (handicapStones.isEmpty ? 0 : handicapStones.count)

        var moves: [GameRecord.Move] = []
        var setupEdits: [GameRecord.SetupEdit] = []
        // Setup nodes stay at their location within the selected line.
        func movePoint(_ raw: String) -> Point? {
            if raw.isEmpty { return nil }
            // FF[3] pass convention: "tt" (≤19×19).
            if raw.lowercased() == "tt" { return nil }
            return SGFParser.sgfPoint(raw)
        }
        for n in nodes {
            if n !== root {
                let edit = GameRecord.SetupEdit(
                    afterMove: moves.count,
                    black: expandPoints(n.values(for: "AB") ?? []),
                    white: expandPoints(n.values(for: "AW") ?? []),
                    empty: expandPoints(n.values(for: "AE") ?? []),
                    nextToPlay: n.firstValue("PL").flatMap { $0.uppercased() == "W" ? .white : $0.uppercased() == "B" ? .black : nil })
                if !edit.black.isEmpty || !edit.white.isEmpty || !edit.empty.isEmpty || edit.nextToPlay != nil {
                    setupEdits.append(edit)
                }
            }
            if let b = n.values(for: "B"), let first = b.first {
                moves.append(GameRecord.Move(
                    color: .black,
                    point: movePoint(first),
                    comment: n.firstValue("C")
                ))
            } else if let w = n.values(for: "W"), let first = w.first {
                moves.append(GameRecord.Move(
                    color: .white,
                    point: movePoint(first),
                    comment: n.firstValue("C")
                ))
            }
        }

        let ruleset = Ruleset.from(sgfName: root.firstValue("RU") ?? "") ?? .chinese
        if ruleset == .chinese, handicap >= 2 {
            // Handicap games traditionally use area scoring anyway; keep as parsed.
        }

        let komi = Double(root.firstValue("KM") ?? "") ?? ruleset.defaultKomi
        let result = root.firstValue("RE").flatMap { GameResult.parse(sgfValue: $0) }

        return GameRecord(
            boardSize: size,
            ruleset: ruleset,
            komi: komi,
            handicap: handicap,
            handicapStones: handicapStones,
            initialWhiteStones: whiteStones,
            setupEdits: setupEdits,
            playerBlack: root.firstValue("PB"),
            playerWhite: root.firstValue("PW"),
            blackRank: root.firstValue("BR"),
            whiteRank: root.firstValue("WR"),
            date: root.firstValue("DT"),
            event: root.firstValue("EV"),
            result: result,
            moves: moves,
            applicationName: root.firstValue("AP"),
            gameName: root.firstValue("GN"),
            nextToPlay: root.firstValue("PL").flatMap { $0.uppercased() == "W" ? .white : $0.uppercased() == "B" ? .black : nil }
        )
    }

    /// Expands point values (each value may contain space-separated points,
    /// already expanded from rectangles by the parser).
    static func expandPoints(_ values: [String]) -> [Point] {
        var points: [Point] = []
        for value in values {
            for token in value.split(separator: " ") {
                if let p = SGFParser.sgfPoint(String(token)) {
                    points.append(p)
                }
            }
        }
        return points
    }

    static func formatKomi(_ komi: Double) -> String {
        if komi == komi.rounded() { return String(Int(komi)) }
        return String(komi)
    }
}
