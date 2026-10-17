// MARK: - Playout policy (heuristic-biased random play)

/// Random playout policy with classic MoGo-style biases:
/// capture, atari-escape, locality, eye-fill and self-atari filters.
/// Used by MCTS simulations.
struct PlayoutPolicy {
    var rng: Xoshiro256
    var komi: Double

    init(rng: Xoshiro256, komi: Double) {
        self.rng = rng
        self.komi = komi
    }

    /// Plays one full random game from the current position. The board is
    /// modified in place. Returns the winner (by area score with komi) and
    /// the first move played by each color (for RAVE/AMAF updates).
    mutating func playout(board: inout Board, startColor: StoneColor, scratch: inout PlayoutScratch,
                          shouldCancel: () -> Bool = { false }) -> PlayoutOutcome {
        var color = startColor
        var lastMove: Point? = nil
        var passes = board.consecutivePasses
        let n = board.size.n
        let maxMoves = 2 * n * n
        var movesMade = 0
        var firstBlack: Point? = nil
        var firstWhite: Point? = nil

        while passes < 2 && movesMade < maxMoves && !shouldCancel() {
            if let move = pickMove(board: &board, color: color, lastMove: lastMove,
                                   scratch: &scratch, shouldCancel: shouldCancel) {
                if case .played = board.play(color: color, at: move) {
                    lastMove = move
                    passes = 0
                    if color == .black, firstBlack == nil { firstBlack = move }
                    if color == .white, firstWhite == nil { firstWhite = move }
                }
            } else {
                board.pass()
                passes += 1
                lastMove = nil
            }
            movesMade += 1
            color = color.opponent
        }

        let margin = Self.areaMargin(board: board, komi: komi)
        return PlayoutOutcome(winner: margin >= 0 ? .black : .white,
                              scoreMargin: margin,
                              firstBlack: firstBlack,
                              firstWhite: firstWhite)
    }

    /// Chooses a move for the playout, or nil to pass.
    mutating func pickMove(board: inout Board, color: StoneColor, lastMove: Point?,
                           scratch: inout PlayoutScratch, shouldCancel: () -> Bool = { false }) -> Point? {
        let n = board.size.n

        // 1. Capture: enemy group adjacent to the last move in atari.
        if let last = lastMove {
            if let capture = urgentCapture(board: board, color: color, around: last),
               isPlayable(board: board, at: capture, color: color, scratch: &scratch) {
                return capture
            }
            // 2. Save: own group adjacent to last move in atari.
            if let save = urgentSave(board: board, color: color, around: last),
               isPlayable(board: board, at: save, color: color, scratch: &scratch) {
                return save
            }
        } else if board.moveCount > 0,
                  let tactic = globalAtariMove(board: board, color: color,
                                               scratch: &scratch, shouldCancel: shouldCancel) {
            return tactic
        }

        // 3. Random candidate near the last move, or uniform.
        for _ in 0..<12 {
            let candidate: Point
            if let last = lastMove, rng.next01() < 0.85 {
                let dx = Int(rng.next() % 5) - 2
                let dy = Int(rng.next() % 5) - 2
                let x = last.x + dx, y = last.y + dy
                if x < 0 || x >= n || y < 0 || y >= n { continue }
                candidate = Point(x: x, y: y)
            } else {
                candidate = Point(x: Int(rng.next() % UInt64(n)), y: Int(rng.next() % UInt64(n)))
            }
            guard board.stone(at: candidate) == nil else { continue }
            if candidate == board.koPoint { continue }
            if isTrueEye(board: board, at: candidate, color: color) { continue }
            // One scratch simulation verifies legality + not-bad-self-atari.
            if !isPlayable(board: board, at: candidate, color: color, scratch: &scratch) { continue }
            return candidate
        }

        // Random probes frequently miss the few remaining useful points.
        // Walk the whole board once before deciding to pass, starting at a
        // seeded offset so playouts still explore different continuations.
        let start = Int(rng.next() % UInt64(n * n))
        for offset in 0..<(n * n) {
            if offset % 32 == 0 && shouldCancel() { return nil }
            let index = (start + offset) % (n * n)
            let candidate = Point(x: index % n, y: index / n)
            guard board.stone(at: candidate) == nil, candidate != board.koPoint else { continue }
            if isTrueEye(board: board, at: candidate, color: color) { continue }
            if isPlayable(board: board, at: candidate, color: color, scratch: &scratch) { return candidate }
        }
        return nil
    }

    // MARK: Urgent tactics around the last move

    /// Once per continuation, catch atari elsewhere on the board. Groups
    /// are visited only once; ordinary playout moves use the local checks.
    func globalAtariMove(board: Board, color: StoneColor, scratch: inout PlayoutScratch,
                         shouldCancel: () -> Bool) -> Point? {
        var visited = Set<Point>()
        var capture: (point: Point, size: Int)? = nil
        var save: (point: Point, size: Int)? = nil
        for (point, stone) in board.stones {
            if shouldCancel() { return nil }
            guard !visited.contains(point), let group = board.group(at: point) else { continue }
            visited.formUnion(group.stones)
            guard group.libertyCount == 1 else { continue }
            let liberty = group.liberties[0]
            guard isPlayable(board: board, at: liberty, color: color, scratch: &scratch) else { continue }
            if stone == color.opponent {
                if capture == nil || group.stoneCount > capture!.size {
                    capture = (liberty, group.stoneCount)
                }
            } else if save == nil || group.stoneCount > save!.size {
                save = (liberty, group.stoneCount)
            }
        }
        return capture?.point ?? save?.point
    }

    /// Finds a capture of an enemy group in atari adjacent to `around`.
    func urgentCapture(board: Board, color: StoneColor, around: Point) -> Point? {
        var best: (point: Point, size: Int)? = nil
        for np in around.neighbors(on: board.size) {
            guard board.stone(at: np) == color.opponent else { continue }
            if let group = board.group(at: np), group.libertyCount == 1 {
                let lib = group.liberties[0]
                if lib == board.koPoint { continue }
                if isTrueEye(board: board, at: lib, color: color) { continue }
                if best == nil || group.stoneCount > best!.size {
                    best = (lib, group.stoneCount)
                }
            }
        }
        return best?.point
    }

    /// Finds an escape (or counter-capture) for an own group in atari
    /// adjacent to `around`.
    func urgentSave(board: Board, color: StoneColor, around: Point) -> Point? {
        var best: (point: Point, libertiesAfter: Int)? = nil
        for np in around.neighbors(on: board.size) {
            guard board.stone(at: np) == color else { continue }
            if let group = board.group(at: np), group.libertyCount == 1 {
                let lib = group.liberties[0]
                if lib == board.koPoint { continue }
                var libs = 0
                for lp in lib.neighbors(on: board.size) {
                    if board.stone(at: lp) == nil { libs += 1 }
                    else if board.stone(at: lp) == color.opponent,
                            board.libertyCount(at: lp) == 1 { libs += 2 } // capture
                }
                if libs == 0 { continue } // suicide extension
                if best == nil || libs > best!.libertiesAfter {
                    best = (lib, libs)
                }
            }
        }
        if let b = best, b.libertiesAfter >= 2 { return b.point }
        return nil
    }

    // MARK: Static filters

    /// A true eye for `color`: all orthogonal neighbors are own stones or
    /// border, and enemy diagonals are limited.
    func isTrueEye(board: Board, at p: Point, color: StoneColor) -> Bool {
        for np in p.neighbors(on: board.size) {
            guard board.stone(at: np) == color else { return false }
        }
        var enemyDiagonals = 0
        for dx in [-1, 1] {
            for dy in [-1, 1] {
                let x = p.x + dx, y = p.y + dy
                guard x >= 0, x < board.size.n, y >= 0, y < board.size.n else { continue }
                if let c = board.stone(at: Point(x: x, y: y)), c != color { enemyDiagonals += 1 }
            }
        }
        let onEdge = p.x == 0 || p.y == 0 || p.x == board.size.n - 1 || p.y == board.size.n - 1
        if onEdge { return enemyDiagonals == 0 }
        return enemyDiagonals <= 1
    }

    /// Plays at `p` on a scratch board when tactical safety needs checking.
    func isPlayable(board: Board, at p: Point, color: StoneColor, scratch: inout PlayoutScratch) -> Bool {
        guard board.stone(at: p) == nil, p != board.koPoint else { return false }
        var emptyNeighbors = 0
        for np in p.neighbors(on: board.size) where board.stone(at: np) == nil {
            emptyNeighbors += 1
        }
        // Two distinct empty neighbors guarantee at least two liberties;
        // only superko then needs a full legality check.
        if emptyNeighbors >= 2 && !board.superkoEnabled { return true }
        scratch.board = board
        guard case .played(let capturedCount) = scratch.board.play(color: color, at: p) else { return false }
        return capturedCount > 0 || scratch.board.libertyCount(at: p) > 1
    }

    // MARK: Scoring

    static func areaWinner(board: Board, komi: Double) -> StoneColor {
        let score = ScoreCalculator.areaScore(board: board, komi: komi)
        return score.blackTotal >= score.whiteTotal ? .black : .white
    }

    static func areaMargin(board: Board, komi: Double) -> Double {
        let score = ScoreCalculator.areaScore(board: board, komi: komi)
        return score.blackTotal - score.whiteTotal
    }
}

/// Reusable scratch space for playouts.
struct PlayoutScratch {
    var board: Board

    init(size: BoardSize) {
        self.board = Board(size: size)
    }
}

/// Result of a random playout, with first-move tracking for RAVE.
struct PlayoutOutcome {
    var winner: StoneColor
    /// Final area-score margin (Black − White, komi included).
    /// Positive = good for Black.
    var scoreMargin: Double
    var firstBlack: Point?
    var firstWhite: Point?
}

extension Xoshiro256 {
    mutating func next01() -> Double {
        Double(next() >> 11) * (1.0 / Double(1 << 53))
    }
}
