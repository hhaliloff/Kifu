import Testing
@testable import GoCore

@Suite("Coordinates")
struct CoordinateTests {

    @Test("Human coordinate notation skips I")
    func humanNotation() {
        // Column 7 = H, column 8 = J (I skipped).
        #expect(Point(x: 7, y: 0).humanCoordinate(on: .nineteen) == "H19")
        #expect(Point(x: 8, y: 0).humanCoordinate(on: .nineteen) == "J19")
        #expect(Point(x: 0, y: 18).humanCoordinate(on: .nineteen) == "A1")
    }

    @Test("Q16 on 19×19 maps to SGF 'pd'")
    func q16ToPd() {
        // Classic 4-4 point Q16: column 15, row 3 (0-based).
        let point = Point(x: 15, y: 3)
        #expect(point.humanCoordinate(on: .nineteen) == "Q16")
        #expect(SGFParser.sgfString(point) == "pd")
        #expect(SGFParser.sgfPoint("pd") == point)
    }

    @Test("Human parsing round-trips")
    func humanParsingRoundTrip() {
        for size in BoardSize.allCases {
            for p in [Point(x: 0, y: 0), Point(x: size.n - 1, y: size.n - 1), Point(x: size.n / 2, y: size.n / 2)] {
                let human = p.humanCoordinate(on: size)
                #expect(Point.parse(human: human, size: size) == p)
            }
        }
    }

    @Test("SGF string/point round-trip for all 19×19 intersections")
    func sgfRoundTrip() {
        for y in 0..<19 {
            for x in 0..<19 {
                let p = Point(x: x, y: y)
                #expect(SGFParser.sgfPoint(SGFParser.sgfString(p)) == p)
            }
        }
    }
}

@Suite("Handicap")
struct HandicapTests {

    @Test("19×19 handicap placements")
    func nineteenHandicap() {
        let h2 = Handicap.stones(for: .nineteen, count: 2)
        #expect(h2.count == 2)
        #expect(h2.contains(pt(15, 3)))
        #expect(h2.contains(pt(3, 15)))

        let h4 = Handicap.stones(for: .nineteen, count: 4)
        #expect(h4.count == 4)
        #expect(h4.contains(pt(15, 15)))
        #expect(h4.contains(pt(3, 3)))

        let h5 = Handicap.stones(for: .nineteen, count: 5)
        #expect(h5.contains(Point(x: 9, y: 9))) // tengen

        let h9 = Handicap.stones(for: .nineteen, count: 9)
        #expect(h9.count == 9)
        // All 9 hoshi points.
        #expect(Set(h9) == Set(BoardSize.nineteen.hoshi))
    }

    @Test("13×13 handicap uses 4/10 corners")
    func thirteenHandicap() {
        let h2 = Handicap.stones(for: .thirteen, count: 2)
        #expect(h2.contains(pt(9, 3)))
        #expect(h2.contains(pt(3, 9)))
        let h5 = Handicap.stones(for: .thirteen, count: 5)
        #expect(h5.contains(Point(x: 6, y: 6)))
    }

    @Test("9×9 handicap capped at 5")
    func nineHandicap() {
        let h2 = Handicap.stones(for: .nine, count: 2)
        #expect(h2.contains(pt(6, 2)))
        #expect(h2.contains(pt(2, 6)))
        let h5 = Handicap.stones(for: .nine, count: 5)
        #expect(h5.count == 5)
        #expect(h5.contains(Point(x: 4, y: 4)))
        // Beyond max returns the max fixed set.
        #expect(Handicap.stones(for: .nine, count: 9).count == 5)
        // 0/1 = even game, no fixed stones.
        #expect(Handicap.stones(for: .nineteen, count: 0).isEmpty)
        #expect(Handicap.stones(for: .nineteen, count: 1).isEmpty)
    }
}
