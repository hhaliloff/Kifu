import Foundation

/// Game metadata an engine may need in addition to the current board.
/// Keeping the complete setup and move history here lets engines that replay
/// positions (such as external analysis services) receive the original game.
public struct EngineGameContext: Sendable, Equatable {
    public let ruleset: Ruleset
    public let komi: Double
    public let handicap: Int
    public let setupBlackStones: [Point]
    public let setupWhiteStones: [Point]
    public let moveHistory: [GameRecord.Move]

    public init(ruleset: Ruleset = .chinese,
                komi: Double? = nil,
                handicap: Int = 0,
                setupBlackStones: [Point] = [],
                setupWhiteStones: [Point] = [],
                moveHistory: [GameRecord.Move] = []) {
        self.ruleset = ruleset
        self.komi = komi ?? ruleset.defaultKomi
        self.handicap = handicap
        self.setupBlackStones = setupBlackStones
        self.setupWhiteStones = setupWhiteStones
        self.moveHistory = moveHistory
    }

    public init(record: GameRecord, moveHistory: [GameRecord.Move]? = nil) {
        self.init(ruleset: record.ruleset,
                  komi: record.komi,
                  handicap: record.handicap,
                  setupBlackStones: record.handicapStones,
                  setupWhiteStones: record.initialWhiteStones,
                  moveHistory: moveHistory ?? record.moves)
    }
}

/// A complete position and search configuration for an engine request.
public struct EngineRequest: Sendable {
    public let board: Board
    public let colorToPlay: StoneColor
    public let context: EngineGameContext
    public let config: EngineConfig

    public init(board: Board,
                colorToPlay: StoneColor,
                context: EngineGameContext,
                config: EngineConfig) {
        self.board = board
        self.colorToPlay = colorToPlay
        self.context = context
        self.config = config
    }
}

/// Search interface consumed by the app. Implementations must honor task
/// cancellation and keep CPU-heavy work off the caller's executor.
public protocol GoEngine: Sendable {
    func search(request: EngineRequest) async throws -> SearchResult
}

/// Creates an engine for a search. A factory keeps app call sites independent
/// of the concrete engine and allows a future adapter to be substituted.
public protocol GoEngineFactory: Sendable {
    func makeEngine() -> any GoEngine
}

/// Factory for the bundled pure-Swift MCTS engine.
public struct MCTSEngineFactory: GoEngineFactory {
    public init() {}

    public func makeEngine() -> any GoEngine {
        MCTSEngineAdapter()
    }
}

private struct MCTSEngineAdapter: GoEngine {
    func search(request: EngineRequest) async throws -> SearchResult {
        let cancellation = SearchCancellationFlag()
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            var config = request.config
            // The game context is authoritative for rules and komi. The
            // bundled search currently uses area scoring, but must still use
            // the same komi as future engine implementations.
            config.komi = request.context.komi
            let engine = MCTSEngine(config: config)
            let result = engine.search(board: request.board,
                                       colorToPlay: request.colorToPlay,
                                       config: config,
                                       shouldCancel: {
                                           cancellation.isCancelled || Task<Never, Never>.isCancelled
                                       })
            try Task.checkCancellation()
            return result
        }

        return try await withTaskCancellationHandler {
            let result = try await worker.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            cancellation.cancel()
            worker.cancel()
        }
    }
}

private final class SearchCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
    }
}
