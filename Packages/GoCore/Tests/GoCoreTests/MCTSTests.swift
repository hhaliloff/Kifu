import Testing
@testable import GoCore

@Suite("MCTS engine")
struct MCTSEngineTests {

    @Test("Engine captures a big atari group when it decides the game")
    func findsDecisiveCapture() {
        // Black 3×3 corner group (9 stones) at (0,0)...(2,2), last liberty
        // (3,1), komi 0.5. If White captures, White wins; if the group
        // lives, Black wins. The capture is the decisive move.
        var board = Board(size: .nine)
        for y in 0...2 {
            for x in 0...2 {
                board.place(color: .black, at: pt(x, y))
            }
        }
        // White enclosure leaving (3,1) as the single liberty.
        for p in [pt(3, 0), pt(3, 2), pt(0, 3), pt(1, 3), pt(2, 3), pt(3, 3)] {
            board.place(color: .white, at: p)
        }
        // Sanity: black corner group has exactly one liberty.
        #expect(board.libertyCount(at: pt(1, 1)) == 1)

        let config = EngineConfig(simulations: 1200, komi: 0.5, seed: 42)
        let engine = MCTSEngine(config: config)
        let result = engine.search(board: board, colorToPlay: .white, config: config)
        #expect(result.bestMove == pt(3, 1))
    }

    @Test("Engine plays a legal move from an empty board")
    func openingMove() {
        let board = Board(size: .nine)
        let config = EngineConfig(simulations: 400, komi: 7.5, seed: 7)
        let engine = MCTSEngine(config: config)
        let result = engine.search(board: board, colorToPlay: .black, config: config)
        guard let move = result.bestMove else {
            Issue.record("engine passed on an empty board")
            return
        }
        #expect(board.isLegal(color: .black, at: move))
        #expect(result.simulations == 400)
    }

    @Test("Deterministic with the same seed")
    func deterministic() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(4, 4))
        let config = EngineConfig(simulations: 300, komi: 7.5, seed: 123)
        let e1 = MCTSEngine(config: config)
        let e2 = MCTSEngine(config: config)
        let r1 = e1.search(board: board, colorToPlay: .white, config: config)
        let r2 = e2.search(board: board, colorToPlay: .white, config: config)
        #expect(r1.bestMove == r2.bestMove)
    }

    @Test("Beats a random player on 9×9 (low-sims sanity)")
    func beatsRandom() {
        // Level 1 (250 sims) as both colors vs random; engine should win
        // at least 2 of 3. Debug-build-friendly budget.
        let engineWins = playVsRandom(engineSims: 250, seed: 99)
        #expect(engineWins >= 2)
    }

    /// Plays 3 games engine-vs-random on 9×9; returns engine wins.
    func playVsRandom(engineSims: Int, seed: UInt64) -> Int {
        var wins = 0
        for game in 0..<3 {
            var board = Board(size: .nine)
            let engineColor = game % 2 == 0 ? StoneColor.white : .black
            let config = EngineConfig(simulations: engineSims, komi: 7.5,
                                      seed: seed &+ UInt64(game), randomness: 0)
            let engine = MCTSEngine(config: config)
            var rng = Xoshiro256(seed: seed &+ 0xBEEF &+ UInt64(game))
            var toPlay = StoneColor.black
            var moves = 0
            while moves < 100 {
                if toPlay == engineColor {
                    let r = engine.search(board: board, colorToPlay: toPlay, config: config)
                    if let m = r.bestMove {
                        _ = board.play(color: toPlay, at: m)
                    } else {
                        board.pass()
                    }
                } else {
                    var played = false
                    for _ in 0..<60 {
                        let p = pt(Int(rng.next() % 9), Int(rng.next() % 9))
                        if case .played = board.play(color: toPlay, at: p) {
                            played = true
                            break
                        }
                    }
                    if !played { board.pass() }
                }
                if board.endedByTwoPasses { break }
                toPlay = toPlay.opponent
                moves += 1
            }
            let score = ScoreCalculator.areaScore(board: board, komi: 7.5)
            if engineColor == .black, score.blackTotal > score.whiteTotal { wins += 1 }
            if engineColor == .white, score.whiteTotal > score.blackTotal { wins += 1 }
        }
        return wins
    }

    @Test("Playout terminates on every position")
    func playoutTerminates() {
        var board = Board(size: .thirteen)
        board.place(color: .black, at: pt(6, 6))
        board.place(color: .white, at: pt(6, 7))
        var policy = PlayoutPolicy(rng: Xoshiro256(seed: 5), komi: 7.5)
        var scratch = PlayoutScratch(size: .thirteen)
        for _ in 0..<20 {
            var b = board
            let outcome = policy.playout(board: &b, startColor: .black, scratch: &scratch)
            #expect(outcome.winner == .black || outcome.winner == .white)
        }
    }

    @Test("Search cancellation returns before running simulations")
    func cancelledSearch() {
        let board = Board(size: .nineteen)
        let config = EngineConfig(simulations: 15_000, komi: 7.5)
        let result = MCTSEngine(config: config).search(
            board: board, colorToPlay: .black, config: config, shouldCancel: { true })
        #expect(result.simulations == 0)
        #expect(result.bestMove == nil)
    }

    @Test("Search retains pass state and offers a finishing pass")
    func passState() {
        var board = Board(size: .nine)
        board.pass()
        let config = EngineConfig(simulations: 1, komi: 7.5)
        let engine = MCTSEngine(config: config)
        _ = engine.search(board: board, colorToPlay: .white, config: config)
        #expect(engine.nodes[0].children.contains { engine.nodes[$0].move == nil })

        board.pass()
        let finished = engine.search(board: board, colorToPlay: .black, config: config)
        #expect(finished.bestMove == nil)
        #expect(finished.simulations == 1)
        #expect(engine.nodes[0].terminal)
    }

    @Test("True eyes are protected, false eyes remain candidates")
    func eyeClassification() {
        var board = Board(size: .nine)
        let center = pt(4, 4)
        for p in center.neighbors(on: .nine) { board.place(color: .black, at: p) }
        let policy = PlayoutPolicy(rng: Xoshiro256(seed: 1), komi: 7.5)
        #expect(policy.isTrueEye(board: board, at: center, color: .black))

        board.place(color: .white, at: pt(3, 3))
        board.place(color: .white, at: pt(5, 5))
        #expect(!policy.isTrueEye(board: board, at: center, color: .black))
        let config = EngineConfig(simulations: 1, komi: 7.5)
        let engine = MCTSEngine(config: config)
        #expect(engine.generateCandidates(board: board, color: .black, lastMove: center)
            .contains { $0.move == center })
    }

    @Test("Self-atari is rejected, but capturing is allowed")
    func selfAtariFilter() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(4, 3))
        for p in [pt(3, 3), pt(5, 3), pt(4, 2), pt(3, 4), pt(5, 4)] {
            board.place(color: .white, at: p)
        }
        let policy = PlayoutPolicy(rng: Xoshiro256(seed: 1), komi: 7.5)
        var scratch = PlayoutScratch(size: .nine)
        #expect(board.isLegal(color: .black, at: pt(4, 4)))
        #expect(!policy.isPlayable(board: board, at: pt(4, 4), color: .black, scratch: &scratch))

        var captureBoard = Board(size: .nine)
        captureBoard.place(color: .white, at: pt(4, 4))
        for p in [pt(3, 4), pt(5, 4), pt(4, 3)] { captureBoard.place(color: .black, at: p) }
        #expect(policy.isPlayable(board: captureBoard, at: pt(4, 5), color: .black, scratch: &scratch))
        _ = captureBoard.play(color: .black, at: pt(8, 8))
        var playoutPolicy = PlayoutPolicy(rng: Xoshiro256(seed: 8), komi: 7.5)
        #expect(playoutPolicy.pickMove(board: &captureBoard, color: .black,
                                       lastMove: nil, scratch: &scratch) == pt(4, 5))
    }

    @Test("Playout finds a sparse capture and passes once settled")
    func sparseCaptureAndPass() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 where pt(x, y) != pt(4, 4) && pt(x, y) != pt(4, 3) {
                board.place(color: .black, at: pt(x, y))
            }
        }
        board.place(color: .white, at: pt(4, 3))
        var policy = PlayoutPolicy(rng: Xoshiro256(seed: 11), komi: 7.5)
        var scratch = PlayoutScratch(size: .nine)
        #expect(policy.pickMove(board: &board, color: .black, lastMove: nil, scratch: &scratch) == pt(4, 4))

        board.place(color: .black, at: pt(4, 3))
        #expect(policy.pickMove(board: &board, color: .black, lastMove: nil, scratch: &scratch) == nil)
        let config = EngineConfig(simulations: 8, komi: 7.5, seed: 11)
        let result = MCTSEngine(config: config).search(board: board, colorToPlay: .black, config: config)
        #expect(result.bestMove == nil)
        #expect(result.simulations == 8)
    }

    @Test("A reused engine reproduces a zero-randomness search")
    func repeatableSearch() {
        var board = Board(size: .nine)
        board.place(color: .black, at: pt(4, 4))
        let config = EngineConfig(simulations: 40, komi: 7.5, seed: 123, randomness: 0)
        let engine = MCTSEngine(config: config)
        let first = engine.search(board: board, colorToPlay: .white, config: config)
        let second = engine.search(board: board, colorToPlay: .white, config: config)
        #expect(first.bestMove == second.bestMove)
        #expect(first.candidates == second.candidates)
        #expect(first.scoreMeanBlack == second.scoreMeanBlack)
    }

    @Test("Two-point enclosed eye is a finished position")
    func twoPointEyePass() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 where pt(x, y) != pt(4, 4) && pt(x, y) != pt(5, 4) {
                board.place(color: .black, at: pt(x, y))
            }
        }
        let config = EngineConfig(simulations: 4, komi: 7.5, seed: 2)
        let engine = MCTSEngine(config: config)
        #expect(engine.isClearlyFinished(board: board, shouldCancel: { false }))
        #expect(engine.search(board: board, colorToPlay: .black, config: config).bestMove == nil)
    }

    @Test("Enclosed territories of three through six points are settled")
    func smallEnclosedTerritories() {
        let config = EngineConfig(simulations: 4, komi: 0.5, seed: 2)
        let engine = MCTSEngine(config: config)
        for length in 3...6 {
            var board = Board(size: .nine)
            for y in 0..<9 {
                for x in 0..<9 where y != 4 || !(1...length).contains(x) {
                    board.place(color: .black, at: pt(x, y))
                }
            }
            #expect(engine.isClearlyFinished(board: board, shouldCancel: { false }))
            #expect(engine.search(board: board, colorToPlay: .black, config: config).bestMove == nil)
            if length == 6 {
                #expect(!engine.generateCandidates(board: board, color: .white, lastMove: nil).isEmpty)
                board.pass()
                #expect(engine.generateCandidates(board: board, color: .white, lastMove: nil).isEmpty)
                #expect(engine.search(board: board, colorToPlay: .white, config: config).bestMove == nil)
            }
        }
    }

    @Test("Larger territory remains available for play")
    func largeRegionIsNotSettled() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 where y != 4 || !(1...7).contains(x) {
                board.place(color: .black, at: pt(x, y))
            }
        }
        board.pass()
        let config = EngineConfig(simulations: 1, komi: 0.5)
        let engine = MCTSEngine(config: config)
        #expect(!engine.isClearlyFinished(board: board, shouldCancel: { false }))
        #expect(!engine.generateCandidates(board: board, color: .black, lastMove: nil).isEmpty)
    }

    @Test("A safe lead can answer a pass despite two dame points")
    func winningReplyToPass() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 {
                if x == 4 && (y == 3 || y == 5) { continue }
                if (x == 1 || x == 2) && y == 1 { continue }
                if x == 7 && (y == 1 || y == 2) { continue }
                board.place(color: x <= 4 ? .black : .white, at: pt(x, y))
            }
        }
        let config = EngineConfig(simulations: 8, komi: 0.5, seed: 7)
        let engine = MCTSEngine(config: config)
        #expect(!engine.isClearlyFinished(board: board, shouldCancel: { false }))
        #expect(!engine.generateCandidates(board: board, color: .black, lastMove: nil).isEmpty)
        board.pass()
        #expect(engine.generateCandidates(board: board, color: .black, lastMove: nil).isEmpty)
        #expect(!engine.generateCandidates(board: board, color: .white, lastMove: nil).isEmpty)
        #expect(engine.search(board: board, colorToPlay: .black, config: config).bestMove == nil)
    }

    @Test("Atari prevents a premature finishing pass")
    func atariBlocksSettlement() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 where y != 4 || !(3...5).contains(x) {
                board.place(color: .black, at: pt(x, y))
            }
        }
        board.place(color: .white, at: pt(8, 8))
        board.clear(at: pt(7, 8))
        board.pass()
        let config = EngineConfig(simulations: 1, komi: 0.5)
        let engine = MCTSEngine(config: config)
        #expect(!engine.isClearlyFinished(board: board, shouldCancel: { false }))
        #expect(engine.generateCandidates(board: board, color: .black, lastMove: nil)
            .contains { $0.move == pt(7, 8) })
    }

    @Test("A same-color border made of separate groups is not settled")
    func disconnectedBoundaryIsNotSettled() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            for x in 0..<9 { board.place(color: .white, at: pt(x, y)) }
        }
        for x in 3...5 {
            board.place(color: .black, at: pt(x, 3))
            board.place(color: .black, at: pt(x, 6))
        }
        for y in 4...5 {
            board.place(color: .black, at: pt(2, y))
            board.place(color: .black, at: pt(6, y))
            for x in 3...5 { board.clear(at: pt(x, y)) }
        }
        let engine = MCTSEngine(config: EngineConfig(simulations: 1, komi: 0.5))
        #expect(!engine.isClearlyFinished(board: board, shouldCancel: { false }))
    }

    @Test("19×19 search checks cancellation during work")
    func interruptionOnLargeBoard() {
        let board = Board(size: .nineteen)
        let config = EngineConfig(simulations: 15_000, komi: 7.5)
        var checks = 0
        let result = MCTSEngine(config: config).search(
            board: board, colorToPlay: .black, config: config,
            shouldCancel: { checks += 1; return checks > 100 })
        #expect(result.simulations < config.simulations)
        #expect(checks > 100)
        if result.simulations == 0 { #expect(result.bestMove == nil) }
    }
}
