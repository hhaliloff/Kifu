import Testing
@testable import GoCore

@Suite("Debug MCTS 2")
struct DebugMCTS2Tests {
    @Test("root stats new pos")
    func rootStats2() {
        var board = Board(size: .nine)
        for y in 0...2 { for x in 0...2 { board.place(color: .black, at: pt(x, y)) } }
        for p in [pt(3, 0), pt(3, 2), pt(0, 3), pt(1, 3), pt(2, 3), pt(3, 3)] {
            board.place(color: .white, at: p)
        }
        let config = EngineConfig(simulations: 1200, komi: 0.5, seed: 42)
        let engine = MCTSEngine(config: config)
        let result = engine.search(board: board, colorToPlay: .white, config: config)
        print("best=\(result.bestMove.map { "\($0)" } ?? "pass") wrBlack=\(result.winRateBlack)")
        for c in result.candidates {
            print("cand move=\(c.point.map { "\($0)" } ?? "pass") visits=\(c.visits) wr=\(c.winRate)")
        }
        var b2 = board
        _ = b2.play(color: .white, at: pt(3, 1))
        var policy = PlayoutPolicy(rng: Xoshiro256(seed: 1), komi: 0.5)
        var scratch = PlayoutScratch(size: .nine)
        var w1 = 0
        for _ in 0..<200 { var b = b2; if policy.playout(board: &b, startColor: .black, scratch: &scratch).winner == .white { w1 += 1 } }
        var w2 = 0
        for _ in 0..<200 { var b = board; if policy.playout(board: &b, startColor: .black, scratch: &scratch).winner == .white { w2 += 1 } }
        print("after-capture: white \(w1)/200; no-capture: white \(w2)/200")
    }
}
