import Foundation
import SwiftUI
import UniformTypeIdentifiers
import GoCore

enum AppTab: CaseIterable {
    case home, learn, tsumego, library, profile

    func title(for language: AppLanguage) -> String {
        switch self {
        case .home: return KifuCopy(language: language).text(.home)
        case .learn: return KifuCopy(language: language).text(.learn)
        case .tsumego: return KifuCopy(language: language).text(.tsumego)
        case .library: return KifuCopy(language: language).text(.library)
        case .profile: return KifuCopy(language: language).text(.profile)
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .learn: return "text.book.closed"
        case .tsumego: return "puzzlepiece.extension"
        case .library: return "books.vertical"
        case .profile: return "person.crop.circle"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case russian = "Русский"
    case english = "English"
    case korean = "한국어"
    case japanese = "日本語"
    case chinese = "中文"
    var id: String { rawValue }
}

struct SavedGame: Codable, Identifiable {
    var id: UUID
    var savedAt: Date
    var humanColor: StoneColor
    var record: GameRecord
}

@MainActor
final class KifuProfile: ObservableObject {
    @Published private(set) var savedGames: [SavedGame] = []
    @Published private(set) var archiveError: String?
    @Published var nickname: String {
        didSet {
            let isCustom = nickname != KifuCopy(language: language).text(.player)
            defaults.set(isCustom, forKey: "nicknameIsCustom")
            if isCustom { defaults.set(nickname, forKey: "nickname") }
            else { defaults.removeObject(forKey: "nickname") }
        }
    }
    @Published private(set) var games: Int { didSet { defaults.set(games, forKey: "completedBotGames") } }
    @Published private(set) var wins: Int { didSet { defaults.set(wins, forKey: "completedBotWins") } }
    @Published private(set) var draws: Int { didSet { defaults.set(draws, forKey: "completedBotDraws") } }
    @Published var puzzles: Int { didSet { defaults.set(puzzles, forKey: "puzzles") } }
    @Published var lessons: Int { didSet { defaults.set(lessons, forKey: "lessons") } }
    @Published private(set) var streak: Int { didSet { defaults.set(streak, forKey: "botGameStreak") } }
    @Published private(set) var launches: Int { didSet { defaults.set(launches, forKey: "launches") } }
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language")
            if !defaults.bool(forKey: "nicknameIsCustom") {
                nickname = KifuCopy(language: language).text(.player)
            }
        }
    }
    @Published private(set) var completedLessonIDs: Set<Int> {
        didSet { defaults.set(Array(completedLessonIDs).sorted(), forKey: "completedLessonIDs") }
    }
    private var lastSolvedPuzzleDate: Date? {
        didSet { defaults.set(lastSolvedPuzzleDate, forKey: "lastSolvedPuzzleDate") }
    }
    private var lastCompletedGameDate: Date? {
        didSet { defaults.set(lastCompletedGameDate, forKey: "lastCompletedBotGameDate") }
    }

    private let defaults = UserDefaults.standard

    private static var archiveURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("KifuGames.json")
    }

    init() {
        let savedLanguage = defaults.string(forKey: "language") ?? ""
        let selectedLanguage = AppLanguage(rawValue: savedLanguage) ?? Self.systemLanguage
        let savedNickname = defaults.string(forKey: "nickname")
        let localizedDefaults = Set(AppLanguage.allCases.map { KifuCopy(language: $0).text(.player) })
        let storedCustomization = defaults.object(forKey: "nicknameIsCustom") as? Bool
        let isCustomNickname = savedNickname != nil
            && (storedCustomization ?? !localizedDefaults.contains(savedNickname!))
        language = selectedLanguage
        nickname = isCustomNickname ? savedNickname! : KifuCopy(language: selectedLanguage).text(.player)
        games = defaults.integer(forKey: "completedBotGames")
        wins = defaults.integer(forKey: "completedBotWins")
        draws = defaults.integer(forKey: "completedBotDraws")
        puzzles = defaults.integer(forKey: "puzzles")
        lessons = defaults.integer(forKey: "lessons")
        streak = defaults.integer(forKey: "botGameStreak")
        launches = defaults.integer(forKey: "launches") + 1
        completedLessonIDs = Set(defaults.array(forKey: "completedLessonIDs") as? [Int] ?? [])
        lastSolvedPuzzleDate = defaults.object(forKey: "lastSolvedPuzzleDate") as? Date
        lastCompletedGameDate = defaults.object(forKey: "lastCompletedBotGameDate") as? Date
        defaults.set(selectedLanguage.rawValue, forKey: "language")
        defaults.set(launches, forKey: "launches")
        defaults.set(isCustomNickname, forKey: "nicknameIsCustom")
        if !isCustomNickname { defaults.removeObject(forKey: "nickname") }
        do {
            savedGames = try JSONDecoder().decode([SavedGame].self, from: Data(contentsOf: Self.archiveURL))
        } catch {
            if FileManager.default.fileExists(atPath: Self.archiveURL.path) {
                archiveError = error.localizedDescription
            } else if let oldSGF = defaults.string(forKey: "lastGameSGF"),
                      let record = try? GameRecordSGF.parse(oldSGF) {
                savedGames = [SavedGame(id: UUID(), savedAt: .now,
                                        humanColor: record.playerBlack == "Kifu AI" ? .white : .black,
                                        record: record)]
                persistGames()
            }
        }
        if archiveError == nil && !defaults.bool(forKey: "botGameStatsMigrated") {
            migrateCompletedGameStats()
            defaults.set(true, forKey: "botGameStatsMigrated")
        }
    }

    private static var systemLanguage: AppLanguage {
        let code = Locale.current.language.languageCode?.identifier ?? "ru"
        switch code {
        case "en": return .english
        case "ko": return .korean
        case "ja": return .japanese
        case "zh": return .chinese
        default: return .russian
        }
    }

    var losses: Int { max(0, games - wins - draws) }
    var winRate: Int { games == 0 ? 0 : Int((Double(wins) / Double(games) * 100).rounded()) }
    var currentStreak: Int {
        guard let lastCompletedGameDate else { return 0 }
        let calendar = Calendar.current
        let daysAgo = calendar.dateComponents([.day],
            from: calendar.startOfDay(for: lastCompletedGameDate),
            to: calendar.startOfDay(for: .now)).day ?? 0
        return (0...1).contains(daysAgo) ? streak : 0
    }

    func recordCompletedGame(won: Bool, draw: Bool = false, on date: Date = .now) {
        games += 1
        if won { wins += 1 }
        if draw { draws += 1 }
        let calendar = Calendar.current
        if let lastCompletedGameDate {
            if calendar.isDate(lastCompletedGameDate, inSameDayAs: date) { return }
            let gap = calendar.dateComponents([.day],
                from: calendar.startOfDay(for: lastCompletedGameDate),
                to: calendar.startOfDay(for: date)).day
            streak = gap == 1 ? streak + 1 : 1
        } else {
            streak = 1
        }
        lastCompletedGameDate = date
    }

    private func migrateCompletedGameStats() {
        let completed = savedGames.filter { game in
            guard game.record.playerBlack == "Kifu AI" || game.record.playerWhite == "Kifu AI" else { return false }
            guard let result = game.record.result else { return false }
            switch result {
            case .blackWinsByScore, .whiteWinsByScore, .draw: return true
            default: return false
            }
        }
        games = completed.count
        wins = completed.filter { game in
            guard let winnerIsBlack = game.record.result?.winnerIsBlack else { return false }
            return winnerIsBlack == (game.humanColor == .black)
        }.count
        draws = completed.filter { $0.record.result == .draw }.count
        lastCompletedGameDate = completed.map(\.savedAt).max()
        let calendar = Calendar.current
        let playedDays = Set(completed.map { calendar.startOfDay(for: $0.savedAt) })
        var day = calendar.startOfDay(for: .now)
        if !playedDays.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        streak = 0
        while playedDays.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
    }

    func saveGame(id: UUID, record: GameRecord, humanColor: StoneColor) {
        guard !record.moves.isEmpty || !record.handicapStones.isEmpty || !record.initialWhiteStones.isEmpty else { return }
        if let index = savedGames.firstIndex(where: { $0.id == id }) {
            savedGames[index].record = record
            savedGames[index].savedAt = .now
        } else {
            savedGames.insert(SavedGame(id: id, savedAt: .now, humanColor: humanColor, record: record), at: 0)
        }
        savedGames.sort { $0.savedAt > $1.savedAt }
        persistGames()
    }

    func importGames(_ records: [GameRecord]) {
        let imported = records.filter {
            !$0.moves.isEmpty || !$0.handicapStones.isEmpty || !$0.initialWhiteStones.isEmpty
        }.map {
            SavedGame(id: UUID(), savedAt: .now,
                      humanColor: $0.sideToPlay(after: $0.moves.count), record: $0)
        }
        guard !imported.isEmpty else { return }
        savedGames.insert(contentsOf: imported, at: 0)
        persistGames()
    }

    func deleteGame(id: UUID) {
        savedGames.removeAll { $0.id == id }
        persistGames()
    }

    private func persistGames() {
        do {
            let url = Self.archiveURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(savedGames).write(to: url, options: .atomic)
            archiveError = nil
        } catch {
            archiveError = error.localizedDescription
        }
    }
    var hasSolvedDailyPuzzle: Bool {
        lastSolvedPuzzleDate.map { Calendar.current.isDateInToday($0) } ?? false
    }

    @discardableResult
    func solvePuzzle(on date: Date = .now) -> Bool {
        let calendar = Calendar.current
        if let lastSolvedPuzzleDate, calendar.isDate(lastSolvedPuzzleDate, inSameDayAs: date) { return false }
        lastSolvedPuzzleDate = date
        puzzles += 1
        return true
    }

    func hasCompletedLesson(id: Int) -> Bool { completedLessonIDs.contains(id) }

    @discardableResult
    func finishLesson(id: Int) -> Bool {
        guard id >= 0, completedLessonIDs.insert(id).inserted else { return false }
        lessons += 1
        return true
    }

    /// Compatibility for callers that do not yet provide a lesson ID.
    func finishLesson() { _ = finishLesson(id: 0) }
}

struct GameSettings: Equatable {
    var boardSize: BoardSize = .nine
    var difficulty = 2
    var handicap = 0
    var humanColor: StoneColor = .black
    var ruleset: Ruleset = .japanese
    var hints = true

    static func continuing(_ record: GameRecord, humanColor: StoneColor) -> GameSettings {
        GameSettings(boardSize: record.boardSize, difficulty: 2,
                     handicap: record.handicap, humanColor: humanColor,
                     ruleset: record.ruleset, hints: true)
    }
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var board: Board
    @Published private(set) var moves: [GameRecord.Move] = []
    @Published private(set) var lastMove: Point?
    @Published private(set) var isThinking = false
    @Published private(set) var gameOver = false
    @Published private(set) var awaitingScoreConfirmation = false
    @Published private(set) var canRetryAI = false
    @Published private(set) var deadBlack: Set<Point> = []
    @Published private(set) var deadWhite: Set<Point> = []
    @Published private(set) var status: String
    @Published private(set) var aiSuggestion: Point?

    let settings: GameSettings
    let humanColor: StoneColor
    let aiColor: StoneColor
    var playerName = "Player"
    var onFinished: ((Bool) -> Void)?
    private let startingBoard: Board
    private let sourceRecord: GameRecord?
    private let initialMoveCount: Int
    private var toPlay: StoneColor
    private var searchTask: Task<Void, Never>?
    private var searchRevision = 0
    private var finalResult: GameResult?
    private let engineFactory: any GoEngineFactory
    var result: GameResult? { finalResult }
    private var didRecordResult = false

    /// The complete game so far, including setup stones and a final result if available.
    var gameRecord: GameRecord {
        var record = sourceRecord ?? GameRecord(
            boardSize: settings.boardSize, ruleset: settings.ruleset,
            komi: settings.ruleset.defaultKomi, handicap: settings.handicap,
            handicapStones: Handicap.stones(for: settings.boardSize, count: settings.handicap))
        record.playerBlack = humanColor == .black ? playerName : "Kifu AI"
        record.playerWhite = humanColor == .white ? playerName : "Kifu AI"
        record.result = finalResult
        record.moves = moves
        record.applicationName = "Kifu:1.0"
        return record
    }

    var exportedSGF: String { GameRecordSGF.sgfString(for: gameRecord) }
    var markedDead: Set<Point> { deadBlack.union(deadWhite) }
    var aiPassedLastTurn: Bool { moves.last?.color == aiColor && moves.last?.point == nil && !gameOver }

    var provisionalScore: ScoreResult {
        if settings.ruleset == .japanese {
            return ScoreCalculator.territoryScore(board: board, komi: gameRecord.komi,
                                                  deadBlack: deadBlack, deadWhite: deadWhite)
        }
        var liveBoard = board
        for point in markedDead { liveBoard.clear(at: point) }
        return ScoreCalculator.areaScore(board: liveBoard, komi: gameRecord.komi)
    }

    /// Position before the latest human move or pass, for replay and review.
    var latestReviewPosition: Board {
        guard let index = moves.indices.reversed().first(where: { $0 >= initialMoveCount && moves[$0].color == humanColor }) else { return board }
        return replay(moves.prefix(index))
    }

    init(settings: GameSettings, initialRecord: GameRecord? = nil,
         engineFactory: any GoEngineFactory = KataGoEngineFactory()) {
        self.settings = settings
        self.engineFactory = engineFactory
        self.humanColor = settings.humanColor
        self.aiColor = settings.humanColor.opponent
        self.sourceRecord = initialRecord
        self.initialMoveCount = initialRecord?.moves.count ?? 0
        self.moves = initialRecord?.moves ?? []
        var initialBoard = Board(size: settings.boardSize, superko: settings.ruleset == .chinese)
        for point in initialRecord?.handicapStones ?? Handicap.stones(for: settings.boardSize, count: settings.handicap) {
            initialBoard.place(color: .black, at: point)
        }
        for point in initialRecord?.initialWhiteStones ?? [] { initialBoard.place(color: .white, at: point) }
        self.startingBoard = initialBoard
        let current = initialRecord?.replay().board ?? initialBoard
        self.board = current
        self.lastMove = initialRecord?.moves.last?.point
        self.toPlay = initialRecord?.sideToPlay(after: initialRecord?.moves.count ?? 0)
            ?? initialBoard.colorToPlay(handicapStones: settings.handicap)
        self.status = self.toPlay == humanColor
            ? KifuCopy.current.text(.yourTurn) : KifuCopy.current.text(.aiThinking)
    }

    func begin() {
        guard !gameOver, !awaitingScoreConfirmation, !isThinking else { return }
        if toPlay == aiColor { makeAIMove() }
    }

    func play(_ point: Point) {
        guard !isThinking, !gameOver, !awaitingScoreConfirmation else { return }
        guard toPlay == humanColor else { return }
        guard case .played = board.play(color: humanColor, at: point) else {
            status = illegalMessage(for: board, at: point)
            return
        }
        lastMove = point
        aiSuggestion = nil
        moves.append(GameRecord.Move(color: humanColor, point: point))
        toPlay = aiColor
        status = KifuCopy.current.text(.aiThinking)
        if board.endedByTwoPasses { beginScoring(); return }
        makeAIMove()
    }

    func pass() {
        guard !isThinking, !gameOver, !awaitingScoreConfirmation else { return }
        guard toPlay == humanColor else { return }
        board.pass()
        lastMove = nil
        aiSuggestion = nil
        moves.append(GameRecord.Move(color: humanColor, point: nil))
        toPlay = aiColor
        if board.endedByTwoPasses { beginScoring(); return }
        status = KifuCopy.current.text(.aiThinking)
        makeAIMove()
    }

    func askHint() {
        guard !isThinking, !gameOver, !awaitingScoreConfirmation else { return }
        guard toPlay == humanColor else { return }
        aiSuggestion = nil
        startSearch(color: humanColor, isHint: true)
    }

    func resign() {
        guard !gameOver else { return }
        cancelSearch()
        canRetryAI = false
        awaitingScoreConfirmation = false
        gameOver = true
        finalResult = humanColor == .black ? .whiteWinsByResign : .blackWinsByResign
        status = KifuCopy.current.text(.gameFinished)
        if !didRecordResult { didRecordResult = true; onFinished?(false) }
    }

    /// Stop an in-flight hint or AI search. `begin()` resumes an AI turn later.
    func cancelSearch() {
        searchRevision &+= 1
        searchTask?.cancel()
        searchTask = nil
        isThinking = false
        if !gameOver && !awaitingScoreConfirmation {
            status = KifuCopy.current.text(toPlay == humanColor
                ? .yourTurn : .aiThinking)
        }
    }

    /// Compatibility name for view lifecycle cleanup.
    func cancelPendingWork() { cancelSearch() }

    /// Rewind to before the most recent human turn, including any AI reply.
    @discardableResult
    func undo() -> Bool {
        guard let index = moves.indices.reversed().first(where: { $0 >= initialMoveCount && moves[$0].color == humanColor }) else { return false }
        cancelSearch()
        moves.removeSubrange(index...)
        board = replay(moves[...])
        lastMove = moves.last?.point
        aiSuggestion = nil
        gameOver = false
        canRetryAI = false
        awaitingScoreConfirmation = false
        deadBlack = []
        deadWhite = []
        finalResult = nil
        toPlay = humanColor
        status = KifuCopy.current.text(.yourTurn)
        return true
    }

    /// Retry the latest reviewed human turn.
    @discardableResult
    func retryPosition() -> Bool { undo() }

    func retryAI() {
        guard canRetryAI, !isThinking, !gameOver, !awaitingScoreConfirmation,
              toPlay == aiColor else { return }
        makeAIMove()
    }

    private func makeAIMove() {
        guard !gameOver, !awaitingScoreConfirmation, !isThinking else { return }
        guard toPlay == aiColor else { return }
        startSearch(color: aiColor, isHint: false)
    }

    private func startSearch(color: StoneColor, isHint: Bool) {
        searchRevision &+= 1
        let revision = searchRevision
        canRetryAI = false
        isThinking = true
        var config = EngineConfig.level(isHint ? max(4, settings.difficulty) : settings.difficulty,
                                        boardSize: settings.boardSize, komi: gameRecord.komi)
        if isHint { config.randomness = 0 }
        let context = EngineGameContext(ruleset: settings.ruleset,
                                        komi: gameRecord.komi,
                                        handicap: settings.handicap,
                                        setupBlackStones: sourceRecord?.handicapStones ?? Handicap.stones(for: settings.boardSize, count: settings.handicap),
                                        setupWhiteStones: sourceRecord?.initialWhiteStones ?? [],
                                        moveHistory: moves)
        let request = EngineRequest(board: board, colorToPlay: color, context: context, config: config)
        let engine = engineFactory.makeEngine()
        searchTask = Task { [weak self] in
            do {
                let result = try await engine.search(request: request)
                guard let self, self.searchRevision == revision, !self.gameOver else { return }
                self.searchTask = nil
                self.isThinking = false
                if isHint {
                    self.aiSuggestion = result.bestMove
                    self.status = KifuCopy.current.text(result.simulations == 0 ? .searchInterrupted :
                        result.bestMove == nil ? .hintPass : .yourTurn)
                    return
                }
                guard result.simulations > 0 else {
                    self.status = KifuCopy.current.text(.searchInterrupted)
                    self.canRetryAI = true
                    return
                }
                self.applyAIMove(result.bestMove, color: color)
            } catch is CancellationError {
                // cancelSearch() updates the visible state and invalidates this
                // request before the worker finishes unwinding.
            } catch {
                guard let self, self.searchRevision == revision, !self.gameOver else { return }
                self.searchTask = nil
                self.isThinking = false
                if isHint {
                    self.status = KifuCopy.current.text(.searchInterrupted)
                } else {
                    self.status = KifuCopy.current.text(.searchInterrupted)
                    self.canRetryAI = true
                }
            }
        }
    }

    private func applyAIMove(_ chosenMove: Point?, color: StoneColor) {
        canRetryAI = false
        if let point = chosenMove {
            guard case .played = board.play(color: color, at: point) else {
                status = KifuCopy.current.text(.searchInterrupted)
                canRetryAI = true
                return
            }
            lastMove = point
            moves.append(GameRecord.Move(color: color, point: point))
        } else {
            board.pass()
            lastMove = nil
            moves.append(GameRecord.Move(color: color, point: nil))
        }
        toPlay = humanColor
        status = KifuCopy.current.text(.yourTurn)
        if board.endedByTwoPasses { beginScoring() }
    }

    private func replay(_ retainedMoves: ArraySlice<GameRecord.Move>) -> Board {
        if var record = sourceRecord {
            record.moves = Array(retainedMoves)
            record.setupEdits.removeAll { $0.afterMove > record.moves.count }
            return record.replay().board
        }
        var position = startingBoard
        for move in retainedMoves {
            if let point = move.point {
                _ = position.play(color: move.color, at: point)
            } else {
                position.pass()
            }
        }
        return position
    }

    func toggleDeadGroup(at point: Point) {
        guard awaitingScoreConfirmation, let color = board.stone(at: point), let group = board.group(at: point) else { return }
        let points = Set(group.stones)
        if color == .black {
            if points.isSubset(of: deadBlack) { deadBlack.subtract(points) } else { deadBlack.formUnion(points) }
        } else {
            if points.isSubset(of: deadWhite) { deadWhite.subtract(points) } else { deadWhite.formUnion(points) }
        }
    }

    func resumePlay() {
        guard awaitingScoreConfirmation else { return }
        awaitingScoreConfirmation = false
        deadBlack = []
        deadWhite = []
        if moves.count >= 2, moves.suffix(2).allSatisfy({ $0.point == nil }) {
            moves.removeLast(2)
            board = replay(moves[...])
        }
        lastMove = moves.last?.point
        toPlay = moves.last?.color.opponent ?? sourceRecord?.nextToPlay
            ?? (settings.handicap > 0 ? .white : .black)
        status = KifuCopy.current.text(toPlay == humanColor ? .yourTurn : .aiThinking)
        begin()
    }

    func confirmScore() {
        guard awaitingScoreConfirmation else { return }
        cancelSearch()
        let score = provisionalScore
        awaitingScoreConfirmation = false
        gameOver = true
        canRetryAI = false
        status = KifuCopy.current.text(.gameFinished)
        finalResult = score.result
        if !didRecordResult {
            didRecordResult = true
            onFinished?(score.result.winnerIsBlack == (humanColor == .black))
        }
    }

    private func beginScoring() {
        cancelSearch()
        let detected = ScoreCalculator.detectDeadGroups(board: board)
        deadBlack = detected.deadBlack
        deadWhite = detected.deadWhite
        awaitingScoreConfirmation = true
        status = KifuCopy.current.text(.scoreReview)
        if settings.ruleset == .chinese, deadBlack.isEmpty, deadWhite.isEmpty {
            confirmScore()
        }
    }

    private func illegalMessage(for board: Board, at point: Point) -> String {
        if board.stone(at: point) != nil { return KifuCopy.current.text(.illegalOccupied) }
        if board.koPoint == point { return KifuCopy.current.text(.illegalKo) }
        return KifuCopy.current.text(.illegalMove)
    }
}

struct Lesson: Identifiable {
    let id: Int
    let chapter: String
    let title: String
    let description: String
    let icon: String
    let progress: Double
}

let lessons: [Lesson] = [
    Lesson(id: 1, chapter: "Глава 1", title: "Камни и доска", description: "Поставь первый камень и почувствуй ритм го.", icon: "circle.grid.3x3", progress: 1),
    Lesson(id: 2, chapter: "Глава 2", title: "Либерти", description: "У каждого камня есть дыхание — его соседние пустые пункты.", icon: "wind", progress: 0.7),
    Lesson(id: 3, chapter: "Глава 3", title: "Захват и ко", description: "Окружай группы и не возвращай позицию мгновенно.", icon: "target", progress: 0.2),
    Lesson(id: 4, chapter: "Глава 4", title: "Территория", description: "Учись видеть пространство, которое контролируют группы.", icon: "map", progress: 0),
    Lesson(id: 5, chapter: "Глава 5", title: "Жизнь и смерть", description: "Две глаза — спокойствие для твоей группы.", icon: "eye", progress: 0),
    Lesson(id: 6, chapter: "Глава 6", title: "Группы камней", description: "Соедини камни, чтобы они делили либерти.", icon: "circle.hexagongrid", progress: 0),
    Lesson(id: 7, chapter: "Глава 7", title: "Базовая тактика", description: "Замечай атари и выбирай ход захвата.", icon: "scope", progress: 0)
]

struct Puzzle {
    let index: Int
    let title: String
    let topic: String
    let board: Board
    let solution: Point
    let explanation: String

    static let count = 3

    static func daily(on date: Date = .now) -> Puzzle {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return at(index: day)
    }

    static func next(after puzzle: Puzzle) -> Puzzle { at(index: puzzle.index + 1) }

    static func at(index: Int) -> Puzzle {
        let normalized = ((index % count) + count) % count
        var board = Board(size: .nine)
        switch normalized {
        case 0:
            board.place(color: .white, at: Point(x: 1, y: 1))
            for p in [Point(x: 0, y: 1), Point(x: 2, y: 1), Point(x: 1, y: 0)] {
                board.place(color: .black, at: p)
            }
            return Puzzle(index: normalized, title: "Последнее дыхание", topic: "Захват камня", board: board,
                          solution: Point(x: 1, y: 2), explanation: "Поставь камень на последнюю свободу белых.")
        case 1:
            for p in [Point(x: 4, y: 4), Point(x: 4, y: 5)] { board.place(color: .white, at: p) }
            for p in [Point(x: 3, y: 4), Point(x: 5, y: 4), Point(x: 4, y: 3),
                      Point(x: 3, y: 5), Point(x: 5, y: 5)] { board.place(color: .black, at: p) }
            return Puzzle(index: normalized, title: "Два камня", topic: "Захват группы", board: board,
                          solution: Point(x: 4, y: 6), explanation: "У двух белых камней осталась одна свобода.")
        default:
            for p in [Point(x: 0, y: 0), Point(x: 1, y: 0)] { board.place(color: .white, at: p) }
            for p in [Point(x: 2, y: 0), Point(x: 0, y: 1)] { board.place(color: .black, at: p) }
            return Puzzle(index: normalized, title: "Угол под угрозой", topic: "Захват группы", board: board,
                          solution: Point(x: 1, y: 1), explanation: "Закрой последнюю свободу белых в углу.")
        }
    }
}

struct SGFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sgf, .plainText, .data] }
    static var writableContentTypes: [UTType] { [.sgf, .plainText, .data] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

extension UTType {
    static var sgf: UTType { UTType(filenameExtension: "sgf", conformingTo: .plainText) ?? .plainText }
}
