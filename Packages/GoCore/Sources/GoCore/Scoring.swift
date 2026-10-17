// MARK: - Scoring

/// Owner of a point/region for scoring and display.
public enum RegionOwner: Hashable, Codable, Sendable {
    case black
    case white
    case neutral // dame / seki points
}

/// The result of scoring a finished game.
public struct ScoreResult: Sendable, Equatable {
    public var blackStones: Int
    public var whiteStones: Int
    public var blackTerritory: Int
    public var whiteTerritory: Int
    public var blackCaptures: Int     // prisoners (Japanese)
    public var whiteCaptures: Int
    public var dame: [Point]
    public var komi: Double
    /// Black territory points (for UI marking).
    public var blackTerritoryPoints: [Point]
    /// White territory points (for UI marking).
    public var whiteTerritoryPoints: [Point]
    /// The ruleset that produced this result.
    public var ruleset: Ruleset

    public var blackTotal: Double {
        switch ruleset {
        case .chinese:
            return Double(blackStones + blackTerritory)
        case .japanese:
            return Double(blackTerritory + blackCaptures)
        }
    }

    public var whiteTotal: Double {
        switch ruleset {
        case .chinese:
            return Double(whiteStones + whiteTerritory) + komi
        case .japanese:
            return Double(whiteTerritory + whiteCaptures) + komi
        }
    }

    public var result: GameResult {
        let diff = blackTotal - whiteTotal
        if diff == 0 { return .draw }
        return diff > 0 ? .blackWinsByScore(diff) : .whiteWinsByScore(-diff)
    }
}

// MARK: - Score calculator

public enum ScoreCalculator {
    /// Chinese (area) scoring: stones + territory. Deterministic; seki
    /// points touching both colors are neutral, and stones inside seki
    /// count as area — no dead-stone judgment required.
    public static func areaScore(board: Board, komi: Double) -> ScoreResult {
        let regions = emptyRegions(board: board)
        var blackTerritory: [Point] = []
        var whiteTerritory: [Point] = []
        var dame: [Point] = []
        for region in regions {
            switch region.borderingColor {
            case .black: blackTerritory.append(contentsOf: region.points)
            case .white: whiteTerritory.append(contentsOf: region.points)
            case nil: dame.append(contentsOf: region.points)
            }
        }
        var blackStones = 0
        var whiteStones = 0
        for (p, c) in board.stones {
            _ = p
            if c == .black { blackStones += 1 } else { whiteStones += 1 }
        }
        return ScoreResult(
            blackStones: blackStones,
            whiteStones: whiteStones,
            blackTerritory: blackTerritory.count,
            whiteTerritory: whiteTerritory.count,
            blackCaptures: board.capturesByBlack,
            whiteCaptures: board.capturesByWhite,
            dame: dame,
            komi: komi,
            blackTerritoryPoints: blackTerritory,
            whiteTerritoryPoints: whiteTerritory,
            ruleset: .chinese
        )
    }

    /// Japanese (territory) scoring with **manually marked dead stones**:
    /// dead stones are removed and counted as prisoners for the opponent;
    /// territory is recomputed on the cleared board. Points inside seki
    /// (regions touching both colors) are neutral.
    public static func territoryScore(board: Board,
                                      komi: Double,
                                      deadBlack: Set<Point>,
                                      deadWhite: Set<Point>) -> ScoreResult {
        var work = board
        for p in deadBlack { work.clear(at: p) }
        for p in deadWhite { work.clear(at: p) }

        let regions = emptyRegions(board: work)
        var blackTerritory: [Point] = []
        var whiteTerritory: [Point] = []
        var dame: [Point] = []
        for region in regions {
            switch region.borderingColor {
            case .black: blackTerritory.append(contentsOf: region.points)
            case .white: whiteTerritory.append(contentsOf: region.points)
            case nil: dame.append(contentsOf: region.points)
            }
        }
        var blackStones = 0
        var whiteStones = 0
        for (p, c) in work.stones {
            _ = p
            if c == .black { blackStones += 1 } else { whiteStones += 1 }
        }
        return ScoreResult(
            blackStones: blackStones,
            whiteStones: whiteStones,
            blackTerritory: blackTerritory.count,
            whiteTerritory: whiteTerritory.count,
            blackCaptures: board.capturesByBlack + deadWhite.count,
            whiteCaptures: board.capturesByWhite + deadBlack.count,
            dame: dame,
            komi: komi,
            blackTerritoryPoints: blackTerritory,
            whiteTerritoryPoints: whiteTerritory,
            ruleset: .japanese
        )
    }

    /// Heuristic auto-detection of dead groups for pre-marking in the UI.
    ///
    /// A group is a dead candidate when:
    /// 1. it and all its adjacent empty regions are fully enclosed by the
    ///    opponent (every contact point outside the enclosed area is an
    ///    opponent stone), and
    /// 2. the adjacent empty regions are small (≤ 2× group size, ≤ 12 pts),
    ///    and
    /// 3. it has fewer than two "eye-like" regions bordered only by the
    ///    group's color.
    ///
    /// This is a heuristic for pre-marking; the user can toggle any group
    /// in the scoring UI. Conservative cases resolve by resuming play.
    public static func detectDeadGroups(board: Board) -> (deadBlack: Set<Point>, deadWhite: Set<Point>) {
        var result: (deadBlack: Set<Point>, deadWhite: Set<Point>) = ([], [])
        let regions = emptyRegions(board: board)
        var regionIndexOf = [Point: Int]()
        for (idx, region) in regions.enumerated() {
            for p in region.points { regionIndexOf[p] = idx }
        }

        // Eye-like region: bordered only by one color.
        func eyeRegions(for color: StoneColor) -> Set<Int> {
            var eyes = Set<Int>()
            for (idx, region) in regions.enumerated() where region.borderingColor == color {
                eyes.insert(idx)
            }
            return eyes
        }

        var visited: Set<Point> = []
        for (p, color) in board.stones {
            guard !visited.contains(p) else { continue }
            guard let group = board.group(at: p) else { continue }
            for sp in group.stones { visited.insert(sp) }

            // Collect adjacent empty regions.
            var adjacentRegionIdx = Set<Int>()
            for sp in group.stones {
                for np in sp.neighbors(on: board.size) {
                    if board.stone(at: np) == nil, let ri = regionIndexOf[np] {
                        adjacentRegionIdx.insert(ri)
                    }
                }
            }

            // Enclosure: walk from the group through adjacent empty regions;
            // if we can reach an empty point adjacent to a same-color stone
            // outside this enclosed pocket, it's not enclosed.
            var enclosedByOpponent = true
            var pocketPoints = Set(group.stones)
            var regionPoints = Set<Point>()
            for ri in adjacentRegionIdx { regionPoints.formUnion(regions[ri].points) }
            pocketPoints.formUnion(regionPoints)

            outer: for pp in pocketPoints {
                for np in pp.neighbors(on: board.size) {
                    if pocketPoints.contains(np) { continue }
                    if let stoneColor = board.stone(at: np) {
                        if stoneColor == color {
                            // Contact with a friendly stone outside the pocket —
                            // group connects outward: not enclosed.
                            enclosedByOpponent = false
                            break outer
                        }
                    }
                    // Empty points outside the pocket shouldn't exist for a
                    // proper pocket (all adjacent regions included).
                }
            }

            // Small pocket condition.
            let smallPocket = regionPoints.count <= max(12, 2 * group.stoneCount)

            // Eye-like regions bordered only by this color among adjacent ones.
            let eyeCount = adjacentRegionIdx.filter { regions[$0].borderingColor == color }.count
            _ = eyeRegions(for: color)

            if enclosedByOpponent && smallPocket && eyeCount < 2 {
                if color == .black {
                    result.deadBlack.formUnion(group.stones)
                } else {
                    result.deadWhite.formUnion(group.stones)
                }
            }
        }
        return result
    }

    // MARK: Empty regions

    struct EmptyRegion {
        var points: [Point]
        /// The single color bordering the region, or nil if bordered by
        /// both colors (dame/seki) or nothing (empty board).
        var borderingColor: StoneColor?
    }

    /// Flood-fills all empty regions of the board.
    static func emptyRegions(board: Board) -> [EmptyRegion] {
        var regions: [EmptyRegion] = []
        var regionIndexOf = [Point: Int]()
        var visited = Set<Point>()
        for y in 0..<board.size.n {
            for x in 0..<board.size.n {
                let start = Point(x: x, y: y)
                guard board.stone(at: start) == nil, !visited.contains(start) else { continue }
                var points: [Point] = []
                var bordering: Set<StoneColor> = []
                var stack: [Point] = [start]
                visited.insert(start)
                while let p = stack.popLast() {
                    points.append(p)
                    for np in p.neighbors(on: board.size) {
                        if let c = board.stone(at: np) {
                            bordering.insert(c)
                        } else if !visited.contains(np) {
                            visited.insert(np)
                            stack.append(np)
                        }
                    }
                }
                let idx = regions.count
                for p in points { regionIndexOf[p] = idx }
                regions.append(EmptyRegion(
                    points: points,
                    borderingColor: bordering.count == 1 ? bordering.first : nil
                ))
            }
        }
        return regions
    }
}
