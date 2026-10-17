import Testing
@testable import GoCore

@Suite("Debug MCTS")
struct DebugMCTSTests {
    @Test("root children stats")
    func rootStats() {
        var board = Board(size: .nine)
        for y in 0...2 {
            for x in 0...2 {
                board.place(color: .black, at: pt(x, y))
            }
        }
        for p in [pt(3, 0), pt(3, 2), pt(0, 3), pt(1, 3), pt(2, 3), pt(3, 3)] {
            board.place(color: .white, at: p)
        }
        for p in [pt(5, 5), pt(6, 5), pt(7, 5), pt(5, 6), pt(6, 6), pt(7, 6), pt(6, 7)] {
            board.place(color: .black, at: p)
        }
        let config = EngineConfig(simulations: 900, komi: 7.5, seed: 42)
        let engine = MCTSEngine(config: config)
        let result = engine.search(board: board, colorToPlay: .white, config: config)
        print("best=\(result.bestMove.map { "\($0)" } ?? "pass") wrBlack=\(result.winRateBlack)")
        for c in result.candidates {
            print("cand move=\(c.point.map { "\($0)" } ?? "pass") visits=\(c.visits) wr=\(c.winRate)")
        }
        // Also: what does a playout from after the capture say?
        var b2 = board
        _ = b2.play(color: .white, at: pt(3, 1))
        var policy = PlayoutPolicy(rng: Xoshiro256(seed: 1), komi: 7.5)
        var scratch = PlayoutScratch(size: .nine)
        var whiteWins = 0
        for _ in 0..<100 {
            var b = b2
            let o = policy.playout(board: &b, startColor: .black, scratch: &scratch)
            if o.winner == .white { whiteWins += 1 }
        }
        print("after-capture playouts: white wins \(whiteWins)/100")
        // And from the raw position (white didn't capture, black to move):
        var whiteWins2 = 0
        for _ in 0..<100 {
            var b = board
            let o = policy.playout(board: &b, startColor: .black, scratch: &scratch)
            if o.winner == .white { whiteWins2 += 1 }
        }
        print("no-capture playouts: white wins \(whiteWins2)/100")
    }
}
