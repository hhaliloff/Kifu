// GoCore — a self-contained Go (weiqi/baduk) engine.
// Pure Swift, zero dependencies, deterministic. Offline-first.

// MARK: - Stone color

/// The color of a stone or a side to play.
public enum StoneColor: Int, Codable, Sendable, CaseIterable {
    case black = 1
    case white = 2

    /// The opposite color.
    public var opponent: StoneColor {
        self == .black ? .white : .black
    }
}

// MARK: - Point

/// An intersection on the board. Coordinates are 0-based, origin at the
/// **top-left** corner: `x` is the column (left → right), `y` is the row
/// (top → bottom). This matches SGF coordinates.
public struct Point: Hashable, Codable, Sendable, Comparable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public static func < (lhs: Point, rhs: Point) -> Bool {
        lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
    }

    /// Nearest neighbors (up to 4), valid only within the board.
    public func neighbors(on size: BoardSize) -> [Point] {
        var result: [Point] = []
        result.reserveCapacity(4)
        if x > 0 { result.append(Point(x: x - 1, y: y)) }
        if x < size.n - 1 { result.append(Point(x: x + 1, y: y)) }
        if y > 0 { result.append(Point(x: x, y: y - 1)) }
        if y < size.n - 1 { result.append(Point(x: x, y: y + 1)) }
        return result
    }

    /// Human-readable notation, e.g. "Q16". Letters A–T skipping "I",
    /// numbers counted bottom-up. Used for UI text and VoiceOver.
    public func humanCoordinate(on size: BoardSize) -> String {
        let letter = Self.humanLetter(forColumn: x)
        let number = size.n - y
        return "\(letter)\(number)"
    }

    public static func humanLetter(forColumn column: Int) -> String {
        // A..H, J..T (skip I)
        let letters = "ABCDEFGHJKLMNOPQRST"
        let index = letters.index(letters.startIndex, offsetBy: column)
        return String(letters[index])
    }

    public static func humanColumn(forLetter letter: Character) -> Int? {
        let letters = Array("ABCDEFGHJKLMNOPQRST")
        guard let idx = letters.firstIndex(of: letter) else { return nil }
        return idx
    }

    /// Parses human notation like "Q16" for the given board size.
    public static func parse(human: String, size: BoardSize) -> Point? {
        guard human.count >= 2 else { return nil }
        var chars = Array(human.uppercased())
        guard let letter = chars.removeFirst() as Character?,
              let column = humanColumn(forLetter: letter),
              let number = Int(String(chars)) else { return nil }
        let y = size.n - number
        guard column < size.n, y >= 0, y < size.n else { return nil }
        return Point(x: column, y: y)
    }
}

extension Point: CustomStringConvertible {
    public var description: String { "\(Character(UnicodeScalar(UInt8(97 + x))))\(y)" }
}

// MARK: - Board size

/// Supported board sizes.
public enum BoardSize: Int, Codable, Sendable, CaseIterable, Comparable {
    case nine = 9
    case thirteen = 13
    case nineteen = 19

    public var n: Int { rawValue }

    public static func < (lhs: BoardSize, rhs: BoardSize) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Star points (hoshi), 0-based top-left origin.
    public var hoshi: [Point] {
        switch self {
        case .nine:
            return [Point(x: 2, y: 2), Point(x: 6, y: 2),
                    Point(x: 2, y: 6), Point(x: 6, y: 6), Point(x: 4, y: 4)]
        case .thirteen:
            return [Point(x: 3, y: 3), Point(x: 9, y: 3),
                    Point(x: 3, y: 9), Point(x: 9, y: 9), Point(x: 6, y: 6)]
        case .nineteen:
            var points: [Point] = []
            for y in [3, 9, 15] {
                for x in [3, 9, 15] {
                    points.append(Point(x: x, y: y))
                }
            }
            return points
        }
    }
}

// MARK: - Ruleset

/// Rule sets supported by the engine.
public enum Ruleset: String, Codable, Sendable, CaseIterable {
    /// Chinese rules: area scoring, suicide illegal, default komi 7.5.
    case chinese
    /// Japanese rules: territory scoring with prisoners, suicide illegal, default komi 6.5.
    case japanese

    public var defaultKomi: Double {
        switch self {
        case .chinese: return 7.5
        case .japanese: return 6.5
        }
    }

    /// SGF `RU` property value (conventional names).
    public var sgfName: String {
        switch self {
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        }
    }

    public static func from(sgfName: String) -> Ruleset? {
        switch sgfName.lowercased() {
        case "chinese": return .chinese
        case "japanese": return .japanese
        default: return nil
        }
    }
}

// MARK: - Game result

/// The outcome of a finished game.
public enum GameResult: Hashable, Codable, Sendable {
    case blackWinsByScore(Double)
    case whiteWinsByScore(Double)
    case blackWinsByResign
    case whiteWinsByResign
    case blackWinsByTime
    case whiteWinsByTime
    case draw
    case void

    /// SGF `RE` property value.
    public var sgfValue: String {
        switch self {
        case .blackWinsByScore(let m): return "B+\(Self.formatMargin(m))"
        case .whiteWinsByScore(let m): return "W+\(Self.formatMargin(m))"
        case .blackWinsByResign: return "B+R"
        case .whiteWinsByResign: return "W+R"
        case .blackWinsByTime: return "B+T"
        case .whiteWinsByTime: return "W+T"
        case .draw: return "0"
        case .void: return "Void"
        }
    }

    static func formatMargin(_ m: Double) -> String {
        if m == m.rounded() { return String(Int(m)) }
        return String(m)
    }

    public static func parse(sgfValue: String) -> GameResult? {
        let v = sgfValue.trimmingCharacters(in: .whitespaces)
        if v == "0" { return .draw }
        if v == "Void" || v == "?" { return .void }
        guard v.count >= 2 else { return nil }
        let colorPart = String(v.prefix(1)).uppercased()
        let rest = v.dropFirst().drop(while: { $0 == "+" })
        switch rest.first.map({ $0.uppercased() }) {
        case "R": return colorPart == "B" ? .blackWinsByResign : .whiteWinsByResign
        case "T": return colorPart == "B" ? .blackWinsByTime : .whiteWinsByTime
        default:
            guard let margin = Double(rest) else { return nil }
            return colorPart == "B" ? .blackWinsByScore(margin) : .whiteWinsByScore(margin)
        }
    }

    /// Whether black is the winner (nil for draw/void).
    public var winnerIsBlack: Bool? {
        switch self {
        case .blackWinsByScore, .blackWinsByResign, .blackWinsByTime: return true
        case .whiteWinsByScore, .whiteWinsByResign, .whiteWinsByTime: return false
        case .draw, .void: return nil
        }
    }
}

// MARK: - Move outcome

/// The result of attempting to play a move on a `Board`.
public enum MoveOutcome: Hashable, Sendable {
    case played(capturedCount: Int)
    case illegal(IllegalMoveReason)
}

/// Why a move was rejected.
public enum IllegalMoveReason: Hashable, Sendable {
    case occupied
    case koViolation
    case suicide
    case superkoViolation
    case outOfBounds
}
