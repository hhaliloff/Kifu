// MARK: - Board

/// A Go board with full rules: captures, liberties, simple ko, optional
/// positional superko, suicide legality, passes and undo.
///
/// The board is a value type backed by a padded flat array (a one-point
/// border of sentinel cells makes neighbor checks branchless). Groups and
/// liberties are computed on demand with a stamp-marked flood fill; hot
/// paths reuse stored scratch buffers to avoid allocation.
public struct Board: Sendable {
    // Cell values.
    static let emptyCell: UInt8 = 0
    static let blackCell: UInt8 = 1
    static let whiteCell: UInt8 = 2
    static let borderCell: UInt8 = 3

    public let size: BoardSize
    /// Padded cells, stride = n + 2.
    var cells: [UInt8]
    /// Zobrist hash of the current position (stones only).
    public private(set) var hash: UInt64
    /// Simple-ko point that may not be replayed right now.
    public private(set) var koPoint: Point?
    /// Positional superko enforcement.
    public var superkoEnabled: Bool
    /// History of position hashes (for superko), including the initial one.
    /// Grow-only: undo does not shrink it, so a position that ever occurred
    /// remains illegal to recreate — the correct behavior for live games.
    public internal(set) var positionHistory: Set<UInt64>
    /// Undo log.
    var history: [UndoEntry]
    /// Stones captured *by* Black / by White so far.
    public private(set) var capturesByBlack: Int
    public private(set) var capturesByWhite: Int
    /// Consecutive passes at the end of the move list.
    public internal(set) var consecutivePasses: Int
    /// Number of moves played (passes not counted).
    public private(set) var moveCount: Int

    // Reusable scratch buffers (mutable state on a value type; COW-safe).
    var visitStamp: [Int32]
    var currentStamp: Int32
    var scratchStones: [Point]

    // MARK: Init

    public init(size: BoardSize, superko: Bool = false) {
        let stride = size.n + 2
        var cells = [UInt8](repeating: Self.borderCell, count: stride * stride)
        for y in 0..<size.n {
            for x in 0..<size.n {
                cells[(y + 1) * stride + (x + 1)] = Self.emptyCell
            }
        }
        self.size = size
        self.cells = cells
        self.superkoEnabled = superko
        self.hash = 0
        self.koPoint = nil
        self.positionHistory = [0]
        self.history = []
        self.capturesByBlack = 0
        self.capturesByWhite = 0
        self.consecutivePasses = 0
        self.moveCount = 0
        self.visitStamp = [Int32](repeating: 0, count: stride * stride)
        self.currentStamp = 0
        self.scratchStones = []
    }

    // MARK: Indexing

    @inline(__always)
    func index(_ p: Point) -> Int {
        let stride = size.n + 2
        return (p.y + 1) * stride + (p.x + 1)
    }

    @inline(__always)
    func point(forLinearIndex i: Int) -> Point {
        let stride = size.n + 2
        return Point(x: i % stride - 1, y: i / stride - 1)
    }

    /// Stone at a point (nil if empty or out of bounds).
    public func stone(at p: Point) -> StoneColor? {
        guard p.x >= 0, p.x < size.n, p.y >= 0, p.y < size.n else { return nil }
        switch cells[index(p)] {
        case Self.blackCell: return .black
        case Self.whiteCell: return .white
        default: return nil
        }
    }

    public var isEmpty: Bool {
        for y in 0..<size.n {
            for x in 0..<size.n where cells[index(Point(x: x, y: y))] != Self.emptyCell {
                return false
            }
        }
        return true
    }

    /// All occupied points with their colors.
    public var stones: [(point: Point, color: StoneColor)] {
        var result: [(Point, StoneColor)] = []
        for y in 0..<size.n {
            for x in 0..<size.n {
                let p = Point(x: x, y: y)
                if let c = stone(at: p) { result.append((p, c)) }
            }
        }
        return result
    }

    /// All empty intersections.
    public var emptyPoints: [Point] {
        var result: [Point] = []
        for y in 0..<size.n {
            for x in 0..<size.n where cells[index(Point(x: x, y: y))] == Self.emptyCell {
                result.append(Point(x: x, y: y))
            }
        }
        return result
    }

    // MARK: Flood fill primitives

    /// Flood-fills the group at `start` (must hold a stone), collecting
    /// stone points and liberty points.
    static func collectGroupFull(cells: [UInt8],
                                 size: BoardSize,
                                 visitStamp: inout [Int32],
                                 currentStamp: inout Int32,
                                 from start: Point,
                                 stones: inout [Point],
                                 liberties: inout [Point]) {
        let stride = size.n + 2
        currentStamp &+= 1
        let stamp = currentStamp
        let startI = (start.y + 1) * stride + (start.x + 1)
        let myColor = cells[startI]
        stones.removeAll(keepingCapacity: true)
        liberties.removeAll(keepingCapacity: true)
        visitStamp[startI] = stamp
        var stack: [Point] = [start]
        while let p = stack.popLast() {
            stones.append(p)
            let i = (p.y + 1) * stride + (p.x + 1)
            for ni in [i - 1, i + 1, i - stride, i + stride] {
                let v = cells[ni]
                if v == Self.emptyCell {
                    if visitStamp[ni] != stamp {
                        visitStamp[ni] = stamp
                        liberties.append(Point(x: ni % stride - 1, y: ni / stride - 1))
                    }
                } else if v == myColor, visitStamp[ni] != stamp {
                    visitStamp[ni] = stamp
                    stack.append(Point(x: ni % stride - 1, y: ni / stride - 1))
                }
            }
        }
    }

    /// Flood-fills the group at `start`, collecting stone points into
    /// `stones` and returning the liberty count. Allocation-light.
    static func floodStones(cells: [UInt8],
                            size: BoardSize,
                            visitStamp: inout [Int32],
                            currentStamp: inout Int32,
                            from start: Point,
                            into stones: inout [Point]) -> Int {
        let stride = size.n + 2
        currentStamp &+= 1
        let stamp = currentStamp
        let startI = (start.y + 1) * stride + (start.x + 1)
        let myColor = cells[startI]
        stones.removeAll(keepingCapacity: true)
        var liberties = 0
        visitStamp[startI] = stamp
        var stack: [Point] = [start]
        while let p = stack.popLast() {
            stones.append(p)
            let i = (p.y + 1) * stride + (p.x + 1)
            for ni in [i - 1, i + 1, i - stride, i + stride] {
                let v = cells[ni]
                if v == Self.emptyCell {
                    if visitStamp[ni] != stamp {
                        visitStamp[ni] = stamp
                        liberties += 1
                    }
                } else if v == myColor, visitStamp[ni] != stamp {
                    visitStamp[ni] = stamp
                    stack.append(Point(x: ni % stride - 1, y: ni / stride - 1))
                }
            }
        }
        return liberties
    }

    /// Liberty count of the group at `start` (must hold a stone). No allocation.
    static func countLiberties(cells: [UInt8],
                               size: BoardSize,
                               visitStamp: inout [Int32],
                               currentStamp: inout Int32,
                               from start: Point) -> Int {
        let stride = size.n + 2
        currentStamp &+= 1
        let stamp = currentStamp
        let startI = (start.y + 1) * stride + (start.x + 1)
        let myColor = cells[startI]
        var liberties = 0
        visitStamp[startI] = stamp
        var stack: [Point] = [start]
        while let p = stack.popLast() {
            let i = (p.y + 1) * stride + (p.x + 1)
            for ni in [i - 1, i + 1, i - stride, i + stride] {
                let v = cells[ni]
                if v == Self.emptyCell {
                    if visitStamp[ni] != stamp {
                        visitStamp[ni] = stamp
                        liberties += 1
                    }
                } else if v == myColor, visitStamp[ni] != stamp {
                    visitStamp[ni] = stamp
                    stack.append(Point(x: ni % stride - 1, y: ni / stride - 1))
                }
            }
        }
        return liberties
    }

    // MARK: Groups (public API)

    /// The group (stones + liberties) at a point, or nil if empty.
    public func group(at p: Point) -> Group? {
        guard stone(at: p) != nil else { return nil }
        let cells = self.cells
        var visitStamp = self.visitStamp
        var currentStamp = self.currentStamp
        var stonePoints: [Point] = []
        var libertyPoints: [Point] = []
        Self.collectGroupFull(cells: cells, size: size,
                              visitStamp: &visitStamp, currentStamp: &currentStamp,
                              from: p, stones: &stonePoints, liberties: &libertyPoints)
        return Group(stones: stonePoints,
                     liberties: libertyPoints,
                     stoneCount: stonePoints.count,
                     libertyCount: libertyPoints.count)
    }

    /// Liberty count of the group at `p` (0 if empty).
    public func libertyCount(at p: Point) -> Int {
        guard stone(at: p) != nil else { return 0 }
        let cells = self.cells
        var visitStamp = self.visitStamp
        var currentStamp = self.currentStamp
        let count = Self.countLiberties(cells: cells, size: size,
                                        visitStamp: &visitStamp, currentStamp: &currentStamp,
                                        from: p)
        return count
    }

    // MARK: Legality & play

    /// Checks whether `color` may legally play at `p` **without** mutating
    /// the board. Cost: one board copy — fine for UI, avoid in hot loops.
    public func isLegal(color: StoneColor, at p: Point) -> Bool {
        var copy = self
        if case .played = copy.play(color: color, at: p) { return true }
        return false
    }

    /// Attempts to play a stone. On illegal moves the board is left
    /// unchanged. Captures are resolved **before** the suicide check, so a
    /// capturing move is legal even if the stone would otherwise have no
    /// liberties (Japanese/Chinese rules).
    @discardableResult
    public mutating func play(color: StoneColor, at p: Point) -> MoveOutcome {
        guard p.x >= 0, p.x < size.n, p.y >= 0, p.y < size.n else { return .illegal(.outOfBounds) }
        let i = index(p)
        guard cells[i] == Self.emptyCell else { return .illegal(.occupied) }
        if p == koPoint { return .illegal(.koViolation) }

        let myCell: UInt8 = color == .black ? Self.blackCell : Self.whiteCell
        let enemyCell: UInt8 = color == .black ? Self.whiteCell : Self.blackCell
        let myHash = zobrist.hash(for: color, at: p)
        let stride = size.n + 2
        let hashBefore = hash

        // Tentatively place.
        cells[i] = myCell
        hash ^= myHash

        // Capture adjacent enemy groups with no liberties. Each group is
        // removed immediately, so the outer `cells[ni] == enemyCell` check
        // guarantees no group is processed twice.
        var captured: [Point] = []
        for ni in [i - 1, i + 1, i - stride, i + stride] {
            guard cells[ni] == enemyCell else { continue }
            let neighborPoint = Point(x: ni % stride - 1, y: ni / stride - 1)
            let libs = Self.floodStones(cells: cells, size: size,
                                        visitStamp: &visitStamp, currentStamp: &currentStamp,
                                        from: neighborPoint, into: &scratchStones)
            if libs == 0 {
                for sp in scratchStones {
                    cells[index(sp)] = Self.emptyCell
                    hash ^= zobrist.hash(for: color.opponent, at: sp)
                    captured.append(sp)
                }
            }
        }

        // Suicide check on our own group.
        if Self.countLiberties(cells: cells, size: size,
                               visitStamp: &visitStamp, currentStamp: &currentStamp,
                               from: p) == 0 {
            revert(moveAt: p, color: color, captured: captured, hashBefore: hashBefore)
            return .illegal(.suicide)
        }

        // Superko check.
        if superkoEnabled, positionHistory.contains(hash) {
            revert(moveAt: p, color: color, captured: captured, hashBefore: hashBefore)
            return .illegal(.superkoViolation)
        }

        // Commit: ko detection, bookkeeping, undo entry.
        let newKo: Point?
        if captured.count == 1 {
            let ownLibs = Self.countLiberties(cells: cells, size: size,
                                              visitStamp: &visitStamp, currentStamp: &currentStamp,
                                              from: p)
            var oneStone: [Point] = []
            _ = Self.floodStones(cells: cells, size: size,
                                 visitStamp: &visitStamp, currentStamp: &currentStamp,
                                 from: p, into: &oneStone)
            if ownLibs == 1 && oneStone.count == 1 {
                newKo = captured[0]
            } else {
                newKo = nil
            }
        } else {
            newKo = nil
        }

        let hashAfter = hash
        history.append(UndoEntry(
            point: p,
            color: color,
            captured: captured,
            koPointBefore: koPoint,
            hashBefore: hashBefore,
            hashAfter: hashAfter,
            capturesByBlackBefore: capturesByBlack,
            capturesByWhiteBefore: capturesByWhite,
            consecutivePassesBefore: consecutivePasses,
            moveCountBefore: moveCount
        ))

        if color == .black { capturesByBlack += captured.count } else { capturesByWhite += captured.count }
        koPoint = newKo
        consecutivePasses = 0
        moveCount += 1
        if superkoEnabled { positionHistory.insert(hashAfter) }
        return .played(capturedCount: captured.count)
    }

    /// Plays a pass.
    public mutating func pass() {
        history.append(UndoEntry(
            point: nil, color: .black, captured: [],
            koPointBefore: koPoint,
            hashBefore: hash,
            hashAfter: hash,
            capturesByBlackBefore: capturesByBlack,
            capturesByWhiteBefore: capturesByWhite,
            consecutivePassesBefore: consecutivePasses,
            moveCountBefore: moveCount
        ))
        koPoint = nil
        consecutivePasses += 1
    }

    /// Undoes the last move or pass. Returns false if there is nothing to undo.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = history.popLast() else { return false }
        if let p = last.point {
            cells[index(p)] = Self.emptyCell
            hash ^= zobrist.hash(for: last.color, at: p)
            for cp in last.captured {
                cells[index(cp)] = last.color == .black ? Self.whiteCell : Self.blackCell
                hash ^= zobrist.hash(for: last.color.opponent, at: cp)
            }
            moveCount = last.moveCountBefore
        }
        koPoint = last.koPointBefore
        capturesByBlack = last.capturesByBlackBefore
        capturesByWhite = last.capturesByWhiteBefore
        consecutivePasses = last.consecutivePassesBefore
        return true
    }

    /// Reverts the board to its initial (setup) state.
    public mutating func undoAll() {
        while undo() {}
    }

    /// Number of entries in the undo log (moves + passes).
    public var historyCount: Int { history.count }

    /// Whether the game has ended by two consecutive passes.
    public var endedByTwoPasses: Bool { consecutivePasses >= 2 }

    /// The color to play next. With `handicapStones >= 1` (White starts).
    public func colorToPlay(handicapStones: Int = 0) -> StoneColor {
        let entries = history.count
        let whiteStarts = handicapStones >= 1
        if whiteStarts {
            return entries % 2 == 0 ? .white : .black
        } else {
            return entries % 2 == 0 ? .black : .white
        }
    }

    // MARK: Setup (puzzle / analysis positions)

    /// Places a stone without capture/ko logic. Intended for puzzle setup
    /// and analysis editing; may create positions that are not reachable
    /// in legal play (e.g. groups without liberties). The resulting position
    /// is recorded for superko, so setup positions count as "occurred".
    public mutating func place(color: StoneColor, at p: Point) {
        guard p.x >= 0, p.x < size.n, p.y >= 0, p.y < size.n else { return }
        let i = index(p)
        if let old = stone(at: p) {
            hash ^= zobrist.hash(for: old, at: p)
        }
        cells[i] = color == .black ? Self.blackCell : Self.whiteCell
        hash ^= zobrist.hash(for: color, at: p)
        koPoint = nil
        positionHistory.insert(hash)
    }

    /// Removes any stone at `p` (setup editing).
    public mutating func clear(at p: Point) {
        guard p.x >= 0, p.x < size.n, p.y >= 0, p.y < size.n else { return }
        let i = index(p)
        if let old = stone(at: p) {
            hash ^= zobrist.hash(for: old, at: p)
            cells[i] = Self.emptyCell
        }
        koPoint = nil
        positionHistory.insert(hash)
    }

    /// Removes all stones and history (fresh position of the same size).
    public mutating func reset() {
        let superko = superkoEnabled
        self = Board(size: size, superko: superko)
    }

    // MARK: Private helpers

    private mutating func revert(moveAt p: Point, color: StoneColor, captured: [Point], hashBefore: UInt64) {
        for cp in captured {
            cells[index(cp)] = color == .black ? Self.whiteCell : Self.blackCell
        }
        cells[index(p)] = Self.emptyCell
        hash = hashBefore
    }

    struct UndoEntry: Sendable {
        var point: Point?       // nil = pass
        var color: StoneColor
        var captured: [Point]
        var koPointBefore: Point?
        var hashBefore: UInt64
        var hashAfter: UInt64
        var capturesByBlackBefore: Int
        var capturesByWhiteBefore: Int
        var consecutivePassesBefore: Int
        var moveCountBefore: Int
    }

    var zobrist: ZobristTable { Zobrist.table(for: size) }
}

// MARK: - Equatable (game-relevant state only)

extension Board: Equatable {
    public static func == (lhs: Board, rhs: Board) -> Bool {
        lhs.size == rhs.size
            && lhs.cells == rhs.cells
            && lhs.koPoint == rhs.koPoint
            && lhs.capturesByBlack == rhs.capturesByBlack
            && lhs.capturesByWhite == rhs.capturesByWhite
            && lhs.moveCount == rhs.moveCount
            && lhs.consecutivePasses == rhs.consecutivePasses
    }
}

// MARK: - Group

/// A connected group of same-colored stones with its liberties.
public struct Group: Sendable, Equatable {
    public let stones: [Point]
    public let liberties: [Point]
    public let stoneCount: Int
    public let libertyCount: Int
}

// MARK: - Zobrist cache

enum Zobrist {
    static func table(for size: BoardSize) -> ZobristTable {
        switch size {
        case .nine: return nine
        case .thirteen: return thirteen
        case .nineteen: return nineteen
        }
    }

    private static let nine = ZobristTable(size: .nine, seed: 0x1111)
    private static let thirteen = ZobristTable(size: .thirteen, seed: 0x2222)
    private static let nineteen = ZobristTable(size: .nineteen, seed: 0x3333)
}
