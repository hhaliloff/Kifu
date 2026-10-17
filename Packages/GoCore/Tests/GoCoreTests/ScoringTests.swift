import Testing
@testable import GoCore

@Suite("Scoring: area (Chinese)")
struct AreaScoringTests {

    @Test("Empty board: white wins by komi")
    func emptyBoard() {
        let board = Board(size: .nine)
        let score = ScoreCalculator.areaScore(board: board, komi: 7.5)
        #expect(score.result == .whiteWinsByScore(7.5))
        #expect(score.blackTerritory == 0)
        #expect(score.whiteTerritory == 0)
        #expect(score.dame.count == 81) // unclaimed region touches no color
    }

    @Test("Walled board: territory, dame and stone counting")
    func walledBoard() {
        var board = Board(size: .nine)
        // Black wall column x=1, white wall column x=3 (full height).
        for y in 0..<9 {
            board.place(color: .black, at: pt(1, y))
            board.place(color: .white, at: pt(3, y))
        }
        let score = ScoreCalculator.areaScore(board: board, komi: 7.5)
        // Column x=0: black territory (9). Column x=2: dame (9).
        // Columns x=4...8: white territory (45).
        #expect(score.blackTerritory == 9)
        #expect(score.whiteTerritory == 45)
        #expect(score.dame.count == 9)
        #expect(score.blackStones == 9)
        #expect(score.whiteStones == 9)
        #expect(score.blackTotal == 18)
        #expect(score.whiteTotal == 54 + 7.5)
        #expect(score.result == .whiteWinsByScore(43.5))
    }

}

@Suite("Scoring: territory (Japanese)")
struct TerritoryScoringTests {

    @Test("Dead stones removed: territory and prisoners")
    func deadStoneRemoval() {
        var board = Board(size: .nine)
        // Black wall column x=1, white wall column x=3 (full height).
        for y in 0..<9 {
            board.place(color: .black, at: pt(1, y))
            board.place(color: .white, at: pt(3, y))
        }
        // Lone white stone trapped inside the black area.
        board.place(color: .white, at: pt(0, 4))

        // Area scoring: the trapped stone keeps the region contested.
        let area = ScoreCalculator.areaScore(board: board, komi: 6.5)
        #expect(area.blackTerritory == 0) // region touches both colors
        #expect(area.dame.count == 8 + 9) // col 0 minus stone + col 2 between walls

        // Japanese scoring with the white stone marked dead:
        // black: territory 9 + prisoner 1 = 10; white: 45 + komi 6.5.
        let japanese = ScoreCalculator.territoryScore(
            board: board, komi: 6.5,
            deadBlack: [], deadWhite: [pt(0, 4)]
        )
        #expect(japanese.blackTerritory == 9) // entire column counts now
        #expect(japanese.blackCaptures == 1)  // dead stone = prisoner
        #expect(japanese.whiteTerritory == 45)
        #expect(japanese.result == .whiteWinsByScore(41.5))
    }

    @Test("detectDeadGroups marks an enclosed hopeless group")
    func detectDead() {
        var board = Board(size: .nine)
        for y in 0..<9 {
            board.place(color: .black, at: pt(1, y))
        }
        board.place(color: .white, at: pt(0, 4))
        // A safe black group outside any enclosure must not be marked.
        board.place(color: .white, at: pt(5, 5))
        let (deadBlack, deadWhite) = ScoreCalculator.detectDeadGroups(board: board)
        #expect(deadWhite.contains(pt(0, 4)))
        #expect(!deadWhite.contains(pt(5, 5)))
        #expect(deadBlack.isEmpty)
    }
}

@Suite("Scoring: results")
struct GameResultTests {
    @Test("SGF result strings round-trip")
    func resultStrings() {
        #expect(GameResult.blackWinsByScore(3.5).sgfValue == "B+3.5")
        #expect(GameResult.whiteWinsByScore(2).sgfValue == "W+2")
        #expect(GameResult.blackWinsByResign.sgfValue == "B+R")
        #expect(GameResult.whiteWinsByTime.sgfValue == "W+T")
        #expect(GameResult.draw.sgfValue == "0")
        #expect(GameResult.parse(sgfValue: "B+3.5") == .blackWinsByScore(3.5))
        #expect(GameResult.parse(sgfValue: "W+Resign") == .whiteWinsByResign)
        #expect(GameResult.parse(sgfValue: "W+R") == .whiteWinsByResign)
        #expect(GameResult.parse(sgfValue: "0") == .draw)
        #expect(GameResult.parse(sgfValue: "Void") == .void)
    }
}
