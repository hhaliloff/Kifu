import Testing
@testable import GoCore

@Suite("SGF: parser")
struct SGFParserTests {

    @Test("Parses a minimal game")
    func minimalGame() throws {
        let text = "(;GM[1]FF[4]SZ[9];B[ee];W[ec];B[dc];W[])"
        let games = try SGFParser.parse(text)
        #expect(games.count == 1)
        let root = games[0].root
        #expect(root.firstValue("SZ") == "9")
        let w1 = root.children[0] // B[ee]
        let b2 = w1.children[0]   // W[ec]
        let w3 = b2.children[0]   // B[dc]
        let w4 = w3.children[0]   // W[]
        #expect(w1.firstValue("B") == "ee")
        #expect(w4.firstValue("W") == "")
    }

    @Test("Parses variations (multiple children)")
    func variations() throws {
        let text = "(;B[ee](;W[ec])(;W[ed]C[also good]))"
        let games = try SGFParser.parse(text)
        let root = try #require(games.first?.root)
        #expect(root.children.count == 2)
        #expect(root.children[0].firstValue("W") == "ec")
        #expect(root.children[1].firstValue("C") == "also good")
    }

    @Test("Parses multiple games per file")
    func multipleGames() throws {
        let text = "(;GM[1];B[aa])(;GM[1];W[bb])"
        let games = try SGFParser.parse(text)
        #expect(games.count == 2)
    }

    @Test("Escapes: brackets, backslashes, soft linebreaks")
    func escapes() throws {
        // SGF text: C[a\]b\<LF>next \\u005c line<CRLF>here]
        let text = "(;GM[1];B[aa]C[a\\]b\\\nnext \\\\u005c line\r\nhere])"
        let games = try SGFParser.parse(text)
        let node = try #require(games.first?.root.children.first)
        let comment = try #require(node.firstValue("C"))
        #expect(comment.contains("a]b"))
        #expect(comment.contains("bnext")) // soft break removed
        #expect(comment.contains("\\"))    // escaped backslash preserved
        #expect(comment.contains("here"))
    }

    @Test("Compressed point lists expand rectangles")
    func compressedPoints() throws {
        let text = "(;GM[1]FF[4]SZ[9]AB[aa:cc])"
        let games = try SGFParser.parse(text)
        let root = try #require(games.first?.root)
        let ab = try #require(root.values(for: "AB"))
        let expanded = ab.joined(separator: " ")
        let points = expanded.split(separator: " ").compactMap { SGFParser.sgfPoint(String($0)) }
        #expect(points.count == 9) // 3×3 rectangle
        #expect(points.contains(Point(x: 0, y: 0)))
        #expect(points.contains(Point(x: 2, y: 2)))
    }

    @Test("Unknown properties are preserved")
    func unknownPreserved() throws {
        let text = "(;GM[1]ZZ[custom]FF[4];B[aa])"
        let games = try SGFParser.parse(text)
        #expect(games.first?.root.firstValue("ZZ") == "custom")
        let roundTripped = SGFWriter.write(games: games)
        #expect(roundTripped.contains("ZZ[custom]"))
    }

    @Test("Empty input throws")
    func emptyThrows() {
        #expect(throws: SGFError.self) { try SGFParser.parse("") }
        #expect(throws: SGFError.self) { try SGFParser.parse("   ") }
    }

    @Test("Deeply nested variations are rejected safely")
    func nestingLimit() {
        let text = String(repeating: "(;B[aa]", count: 130) + String(repeating: ")", count: 130)
        #expect(throws: SGFError.self) { try SGFParser.parse(text) }
    }
}

@Suite("SGF: writer & round-trip")
struct SGFWriterTests {

    @Test("Writer escapes special characters")
    func writerEscapes() {
        #expect(SGFWriter.escape("a]b", isLongText: false) == "a\\]b")
        #expect(SGFWriter.escape("a\\b", isLongText: false) == "a\\\\b")
    }

    @Test("GameRecord → SGF → parse round-trip")
    func recordRoundTrip() throws {
        var record = GameRecord(
            boardSize: .nineteen,
            ruleset: .chinese,
            komi: 7.5,
            handicap: 3,
            handicapStones: Handicap.stones(for: .nineteen, count: 3),
            playerBlack: "黑方",
            playerWhite: "Kifu AI",
            blackRank: "5k",
            date: "2026-09-21",
            result: .whiteWinsByScore(2.5)
        )
        record.moves = [
            GameRecord.Move(color: .white, point: Point(x: 15, y: 15), comment: "corner first ] bracket"),
            GameRecord.Move(color: .black, point: Point(x: 3, y: 15)),
            GameRecord.Move(color: .white, point: nil, comment: "pass move"), // pass
            GameRecord.Move(color: .black, point: Point(x: 9, y: 9))
        ]
        let sgf = GameRecordSGF.sgfString(for: record)
        #expect(sgf.contains("GM[1]"))
        #expect(sgf.contains("FF[4]"))
        #expect(sgf.contains("CA[UTF-8]"))
        #expect(sgf.contains("SZ[19]"))
        #expect(sgf.contains("HA[3]"))
        #expect(sgf.contains("RE[W+2.5]"))

        let parsed = try GameRecordSGF.parse(sgf)
        #expect(parsed.boardSize == .nineteen)
        #expect(parsed.ruleset == .chinese)
        #expect(parsed.komi == 7.5)
        #expect(parsed.handicap == 3)
        #expect(parsed.handicapStones.count == 3)
        #expect(parsed.playerBlack == "黑方")
        #expect(parsed.result == .whiteWinsByScore(2.5))
        #expect(parsed.moves.count == 4)
        #expect(parsed.moves[0].point == Point(x: 15, y: 15))
        #expect(parsed.moves[2].point == nil) // pass
        #expect(parsed.moves[0].comment?.contains("] bracket") == true)
    }

    @Test("FF[3] 'tt' is treated as pass")
    func legacyPass() throws {
        let text = "(;GM[1]FF[3]SZ[19];B[pd];W[tt];B[dd])"
        let record = try GameRecordSGF.parse(text)
        #expect(record.moves.count == 3)
        #expect(record.moves[1].point == nil)
        #expect(record.moves[2].point == Point(x: 3, y: 3))
    }

    @Test("Mid-game setup edits remain at the correct move and survive export")
    func midGameSetup() throws {
        let text = "(;GM[1]FF[4]SZ[9]PL[W];B[ee];AW[ab];W[ec];AE[ee])"
        let record = try GameRecordSGF.parse(text)
        #expect(record.moves.count == 2)
        #expect(record.position(after: 1).stone(at: Point(x: 0, y: 1)) == .white)
        #expect(record.position(after: 1).stone(at: Point(x: 4, y: 4)) == .black)
        #expect(record.position(after: 2).stone(at: Point(x: 4, y: 4)) == nil)
        #expect(record.sideToPlay(after: 0) == .white)
        let partial = record.prefix(1)
        #expect(partial.moves.count == 1)
        #expect(partial.setupEdits.count == 1)
        let parsedAgain = try GameRecordSGF.parse(GameRecordSGF.sgfString(for: record))
        #expect(parsedAgain.position(after: 2) == record.position(after: 2))
    }

    @Test("SGF collections expose every game and variation")
    func collectionVariations() throws {
        let records = try GameRecordSGF.parseAll(
            "(;GM[1]SZ[9];B[ee](;W[dd])(;W[ff]))(;GM[1]SZ[9];B[aa])")
        #expect(records.count == 3)
        #expect(records[0].moves[1].point == Point(x: 3, y: 3))
        #expect(records[1].moves[1].point == Point(x: 5, y: 5))
        #expect(records[2].moves.count == 1)
    }

    @Test("Explicit side to play after a move survives export")
    func playerToPlayEdit() throws {
        let record = try GameRecordSGF.parse("(;GM[1]SZ[9];B[aa];PL[B])")
        #expect(record.sideToPlay(after: 1) == .black)
        let exported = GameRecordSGF.sgfString(for: record)
        #expect(try GameRecordSGF.parse(exported).sideToPlay(after: 1) == .black)
    }

    @Test("Unsupported board size is rejected")
    func unsupportedSize() {
        #expect(throws: SGFError.self) { try GameRecordSGF.parse("(;GM[1]SZ[7];B[dd])") }
    }

    @Test("Comment wrapping with soft breaks")
    func longCommentWrapping() {
        let longText = String(repeating: "word ", count: 40).trimmingCharacters(in: .whitespaces)
        let escaped = SGFWriter.escape(longText, isLongText: true)
        #expect(escaped.contains("\\\n"))
        // Round-trip: parse the wrapped comment.
        let sgf = "(;GM[1];B[aa]C[\(escaped)])"
        let games = try? SGFParser.parse(sgf)
        let comment = games?.first?.root.children.first?.firstValue("C")
        #expect(comment == longText)
        #expect(comment?.contains("\\") == false)
    }
}

@Suite("GameRecord: replay")
struct ReplayTests {

    @Test("Replay applies handicap then moves")
    func replayHandicap() {
        let record = GameRecord(
            boardSize: .nineteen,
            handicap: 2,
            handicapStones: Handicap.stones(for: .nineteen, count: 2),
            moves: [
                GameRecord.Move(color: .white, point: Point(x: 2, y: 2)),
                GameRecord.Move(color: .black, point: Point(x: 15, y: 15))
            ]
        )
        let (board, illegal) = record.replay()
        #expect(illegal.isEmpty)
        #expect(board.stone(at: Point(x: 15, y: 3)) == .black) // handicap
        #expect(board.stone(at: Point(x: 2, y: 2)) == .white)
        #expect(board.moveCount == 2)
    }

    @Test("Illegal moves are reported and forced with place()")
    func replayIllegal() {
        // White recaptures a ko point immediately → illegal.
        let sgf = "(;GM[1]FF[4]SZ[9];B[cc];W[cc])"
        let record = try? GameRecordSGF.parse(sgf)
        let (_, illegal) = record!.replay()
        #expect(illegal.count == 1)
    }
}
