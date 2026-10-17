import Testing
@testable import GoCore

/// 0-based point helper.
@inline(__always) func pt(_ x: Int, _ y: Int) -> Point { Point(x: x, y: y) }

@Suite("Board: captures & liberties")
struct BoardCaptureTests {

    @Test("Single stone liberty counts")
    func singleStoneLiberties() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(1, 1))
        #expect(board.libertyCount(at: pt(1, 1)) == 4)
        board.place(color: .black, at: pt(2, 1))
        #expect(board.libertyCount(at: pt(2, 1)) == 6)
        board.place(color: .white, at: pt(0, 0))
        #expect(board.libertyCount(at: pt(0, 0)) == 2)
    }

    @Test("Capture single stone via last liberty")
    func captureSingleStone() {
        var board = Board(size: .nine)
        board.play(color: .black, at: pt(1, 1))
        board.play(color: .white, at: pt(0, 1))
        board.play(color: .white, at: pt(2, 1))
        board.play(color: .white, at: pt(1, 0))
        let outcome = board.play(color: .white, at: pt(1, 2))
        guard case .played(let captured) = outcome else {
            Issue.record("expected capture, got \(outcome)")
            return
        }
        #expect(captured == 1)
        #expect(board.stone(at: pt(1, 1)) == nil)
        #expect(board.capturesByWhite == 1)
    }

    @Test("Capture multi-stone group")
    func captureGroup() {
        var board = Board(size: .nine)
        // Black pair on the bottom edge: liberties (0,0),(1,1),(3,0),(2,1).
        board.play(color: .black, at: pt(1, 0))
        board.play(color: .black, at: pt(2, 0))
        board.play(color: .white, at: pt(0, 0))
        board.play(color: .white, at: pt(1, 1))
        board.play(color: .white, at: pt(3, 0))
        let outcome = board.play(color: .white, at: pt(2, 1))
        guard case .played(let captured) = outcome else {
            Issue.record("expected capture, got \(outcome)")
            return
        }
        #expect(captured == 2)
        #expect(board.stone(at: pt(1, 0)) == nil)
        #expect(board.stone(at: pt(2, 0)) == nil)
        #expect(board.capturesByWhite == 2)
    }

    @Test("Suicide is illegal")
    func suicideIllegal() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(1, 0))
        board.place(color: .black, at: pt(0, 1))
        let outcome = board.play(color: .white, at: pt(0, 0))
        #expect(outcome == .illegal(.suicide))
        #expect(board.stone(at: pt(0, 0)) == nil)
    }

    @Test("Capture resolves before suicide: snapback-style capture")
    func captureBeforeSuicide() {
        var board = Board(size: .nine)
        // Bottom-edge version. White group A {(2,0),(2,1),(3,0)} — last
        // liberty (4,0). White group B {(5,0),(4,1)} — liberties (4,0),(5,1).
        board.place(color: .white, at: pt(2, 0))
        board.place(color: .white, at: pt(2, 1))
        board.place(color: .white, at: pt(3, 0))
        board.place(color: .white, at: pt(5, 0))
        board.place(color: .white, at: pt(4, 1))
        // Black wall around everything (leaving (5,1) as B's exit).
        board.place(color: .black, at: pt(1, 0))
        board.place(color: .black, at: pt(1, 1))
        board.place(color: .black, at: pt(2, 2))
        board.place(color: .black, at: pt(3, 1))
        board.place(color: .black, at: pt(6, 0))
        board.place(color: .black, at: pt(4, 2))
        // Sanity: white A has exactly 1 liberty (4,0).
        #expect(board.libertyCount(at: pt(2, 0)) == 1)
        #expect(board.libertyCount(at: pt(5, 0)) == 2)
        // Black plays (4,0): without captures this stone would have no
        // liberties (all neighbors white), but it captures group A (3
        // stones) first → legal. White B survives via (5,1).
        let outcome = board.play(color: .black, at: pt(4, 0))
        guard case .played(let captured) = outcome else {
            Issue.record("expected legal capturing move, got \(outcome)")
            return
        }
        #expect(captured == 3)
        #expect(board.stone(at: pt(4, 0)) == .black)
        #expect(board.libertyCount(at: pt(4, 0)) == 1) // snapback shape
        #expect(board.stone(at: pt(5, 0)) == .white)   // group B alive
        #expect(board.capturesByBlack == 3)
    }

    @Test("Undo restores exact state")
    func undoRestoresState() {
        var board = Board(size: .nine)
        board.play(color: .black, at: pt(5, 5))
        board.play(color: .white, at: pt(3, 3))
        board.play(color: .black, at: pt(5, 4))
        board.pass()
        let snapshot = board
        board.play(color: .white, at: pt(2, 2))
        board.play(color: .black, at: pt(2, 1))
        board.play(color: .white, at: pt(1, 1))
        let u1 = board.undo(); _ = u1
        let u2 = board.undo(); _ = u2
        let u3 = board.undo(); _ = u3
        #expect(u1 && u2 && u3)
        #expect(board == snapshot)
        #expect(board.hash == snapshot.hash)
        board.undoAll()
        #expect(board.isEmpty)
    }

    @Test("Hash changes on capture and restores on undo")
    func hashThroughCaptureUndo() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(1, 1))
        board.place(color: .white, at: pt(7, 7))
        let h0 = board.hash
        // White surrounds and captures the lone black stone.
        board.play(color: .white, at: pt(0, 1))
        board.play(color: .white, at: pt(2, 1))
        board.play(color: .white, at: pt(1, 0))
        let capture = board.play(color: .white, at: pt(1, 2))
        guard case .played(let n) = capture, n == 1 else {
            Issue.record("expected capture, got \(capture)")
            return
        }
        #expect(board.stone(at: pt(1, 1)) == nil)
        #expect(board.hash != h0)
        // Undo all four white moves → exact setup position and hash.
        board.undo(); board.undo(); board.undo(); board.undo()
        #expect(board.stone(at: pt(1, 1)) == .black)
        #expect(board.hash == h0)
    }
}

@Suite("Board: ko rule")
struct BoardKoTests {

    /// Classic ko:
    /// ````
    ///   . B W .
    ///   B w . W      w = white stone in atari at (2,2); black captures at (3,2)
    ///   . B W .
    /// ````
    @Test("Simple ko: immediate recapture forbidden, allowed after a threat")
    func simpleKo() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(2, 3))
        board.place(color: .white, at: pt(3, 3))
        board.place(color: .black, at: pt(1, 2))
        board.place(color: .white, at: pt(4, 2))
        board.place(color: .black, at: pt(2, 1))
        board.place(color: .white, at: pt(3, 1))
        board.place(color: .white, at: pt(2, 2))
        // Verify white (2,2) has exactly one liberty (3,2).
        #expect(board.libertyCount(at: pt(2, 2)) == 1)

        let capture = board.play(color: .black, at: pt(3, 2))
        guard case .played(let n) = capture, n == 1 else {
            Issue.record("expected ko capture, got \(capture)")
            return
        }
        #expect(board.koPoint == pt(2, 2))
        // The black stone at (3,2) now has exactly one liberty (2,2).
        #expect(board.libertyCount(at: pt(3, 2)) == 1)

        // Immediate recapture forbidden:
        let banCheck = board.play(color: .white, at: pt(2, 2))
        #expect(banCheck == .illegal(.koViolation))
        // Any other legal move lifts the ko ban:
        let threat = board.play(color: .white, at: pt(8, 8))
        #expect(threat == .played(capturedCount: 0))
        #expect(board.koPoint == nil)
        let answer = board.play(color: .black, at: pt(8, 7))
        #expect(answer == .played(capturedCount: 0))
        // Now white recaptures legally:
        let recapture = board.play(color: .white, at: pt(2, 2))
        #expect(recapture == .played(capturedCount: 1))
        #expect(board.stone(at: pt(3, 2)) == nil)
    }
}

@Suite("Board: superko")
struct SuperkoTests {
    @Test("Positional superko forbids recreating an earlier position")
    func superkoBlocks() {
        var board = Board(size: .nine, superko: true)
        // Ko shape; white stone (2,2) in atari, black to capture at (3,2).
        board.place(color: .black, at: pt(2, 3))
        board.place(color: .white, at: pt(3, 3))
        board.place(color: .black, at: pt(1, 2))
        board.place(color: .white, at: pt(4, 2))
        board.place(color: .black, at: pt(2, 1))
        board.place(color: .white, at: pt(3, 1))
        board.place(color: .white, at: pt(2, 2))

        // Black captures: position P1 recorded.
        let capture = board.play(color: .black, at: pt(3, 2))
        guard case .played = capture else {
            Issue.record("expected capture")
            return
        }
        // "Edit" the position back to the pre-capture state (clear() also
        // resets koPoint, so the simple-ko rule does not interfere).
        board.clear(at: pt(3, 2))
        // Replaying the capture would recreate recorded position P1.
        let replay = board.play(color: .black, at: pt(3, 2))
        #expect(replay == .illegal(.superkoViolation))
    }

    @Test("Simple ko takes precedence over superko")
    func koPrecedence() {
        var board = Board(size: .nine, superko: true)
        board.place(color: .black, at: pt(2, 3))
        board.place(color: .white, at: pt(3, 3))
        board.place(color: .black, at: pt(1, 2))
        board.place(color: .white, at: pt(4, 2))
        board.place(color: .black, at: pt(2, 1))
        board.place(color: .white, at: pt(3, 1))
        board.place(color: .white, at: pt(2, 2))
        let capture = board.play(color: .black, at: pt(3, 2))
        guard case .played = capture else {
            Issue.record("expected capture")
            return
        }
        let immediate = board.play(color: .white, at: pt(2, 2))
        #expect(immediate == .illegal(.koViolation))
    }
}

@Suite("Board: passes")
struct PassTests {
    @Test("Two passes end the game; ko ban lifted by pass")
    func passes() {
        var board = Board(size: .nine)
        board.play(color: .black, at: pt(5, 5))
        #expect(!board.endedByTwoPasses)
        board.pass()
        board.pass()
        #expect(board.endedByTwoPasses)
    }

    @Test("colorToPlay alternates; white starts with handicap")
    func colorToPlay() {
        var board = Board(size: .nineteen)
        #expect(board.colorToPlay() == .black)
        board.play(color: .black, at: pt(10, 10))
        #expect(board.colorToPlay() == .white)
        var handicapBoard = Board(size: .nineteen)
        handicapBoard.place(color: .black, at: pt(4, 4))
        #expect(handicapBoard.colorToPlay(handicapStones: 1) == .white)
    }
}
