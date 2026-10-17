// MARK: - MCTS engine (UCT + RAVE + policy priors)

import Foundation

/// Configuration for one search.
public struct EngineConfig: Sendable {
    public var simulations: Int
    public var komi: Double
    public var seed: UInt64
    /// 0 = always the most-visited move; > 0 occasionally plays the 2nd best
    /// (beginner levels).
    public var randomness: Double
    /// Ask adapters with move-selection sampling to choose the top-ranked
    /// searched move. Position analysis uses this; ordinary game play may
    /// retain the engine's default move-selection behavior.
    public var deterministicMoveSelection: Bool
    /// Spend part of the search on legal liberties of groups under pressure.
    /// The adapter can compare those results with the ordinary root search.
    public var tacticalFocus: Bool
    /// Rank by the chance to win rather than also rewarding extra score.
    public var maximizeWinProbability: Bool
    public var uctConstant: Double
    public var expandThreshold: Int
    public var raveEquivalence: Double
    /// Optional wall-clock budget for a search. `nil` runs all simulations.
    public var timeLimit: TimeInterval?

    public init(simulations: Int,
                komi: Double,
                seed: UInt64 = 0xFEEDFACE,
                randomness: Double = 0,
                deterministicMoveSelection: Bool = false,
                tacticalFocus: Bool = false,
                maximizeWinProbability: Bool = false,
                uctConstant: Double = 0.7,
                expandThreshold: Int = 4,
                raveEquivalence: Double = 60,
                timeLimit: TimeInterval? = nil) {
        self.simulations = simulations
        self.komi = komi
        self.seed = seed
        self.randomness = randomness
        self.deterministicMoveSelection = deterministicMoveSelection
        self.tacticalFocus = tacticalFocus
        self.maximizeWinProbability = maximizeWinProbability
        self.uctConstant = uctConstant
        self.expandThreshold = expandThreshold
        self.raveEquivalence = raveEquivalence
        self.timeLimit = timeLimit
    }

    /// Difficulty levels 1-5 mapped to simulation counts per board size.
    public static func level(_ level: Int, boardSize: BoardSize, komi: Double, seed: UInt64 = 0xFEEDFACE) -> EngineConfig {
        let base: Int
        switch level {
        case 1: base = 250
        case 2: base = 800
        case 3: base = 2200
        case 4: base = 6000
        case 5: base = 15000
        default: base = 2200
        }
        let sizeFactor: Double
        switch boardSize {
        case .nine: sizeFactor = 1.0
        case .thirteen: sizeFactor = 1.25
        case .nineteen: sizeFactor = 1.6
        }
        return EngineConfig(
            simulations: Int(Double(base) * sizeFactor),
            komi: komi,
            seed: seed,
            randomness: 0,
            timeLimit: [1.5, 2, 3, 4, 5][min(max(level, 1), 5) - 1]
        )
    }
}

/// One candidate move with its statistics.
public struct MoveCandidate: Sendable, Equatable {
    public let point: Point?
    public let visits: Int
    /// Win rate for the player who made the move.
    public let winRate: Double
    /// Mean score margin for Black (points, komi included).
    public let scoreMean: Double

    public init(point: Point?, visits: Int, winRate: Double, scoreMean: Double) {
        self.point = point
        self.visits = visits
        self.winRate = winRate
        self.scoreMean = scoreMean
    }
}

/// The result of an engine search.
public struct SearchResult: Sendable {
    /// The chosen move (nil = pass).
    public let bestMove: Point?
    /// Estimated win probability for Black after the move.
    public let winRateBlack: Double
    /// Estimated score margin for Black (points, komi included).
    public let scoreMeanBlack: Double
    public let simulations: Int
    /// Top candidates, ranked by visits, prior and immediate capture value.
    public let candidates: [MoveCandidate]

    public init(bestMove: Point?, winRateBlack: Double, scoreMeanBlack: Double,
                simulations: Int, candidates: [MoveCandidate]) {
        self.bestMove = bestMove
        self.winRateBlack = winRateBlack
        self.scoreMeanBlack = scoreMeanBlack
        self.simulations = simulations
        self.candidates = candidates
    }
}

// MARK: - Tree node

struct MCTSNode {
    /// Move (by `mover`) that led to this node; nil only for the root.
    var move: Point?
    /// The color that played `move`.
    var mover: StoneColor
    /// Side to play from this position.
    var colorToPlay: StoneColor
    /// Wins for `mover`.
    var wins: Double = 0
    /// Score-margin sum (from BLACK's perspective; komi included).
    var scoreSum: Double = 0
    var visits: Int = 0
    /// AMAF/RAVE statistics (for `mover`).
    var raveWins: Double = 0
    var raveScoreSum: Double = 0
    var raveVisits: Int = 0
    /// Policy prior for the move (0...1).
    var prior: Double = 0.3
    var parent: Int = -1
    var children: [Int] = []
    var expanded: Bool = false
    /// Terminal (no moves available) — result comes from direct scoring.
    var terminal: Bool = false
}

// MARK: - Engine

/// A single-threaded MCTS Go engine. One instance per game; call `search`
/// from a background context (each call may take up to a few seconds at
/// high levels on large boards).
public final class MCTSEngine: @unchecked Sendable {
    var nodes: [MCTSNode] = []
    var policy: PlayoutPolicy
    var scratch: PlayoutScratch

    public init(config: EngineConfig) {
        self.policy = PlayoutPolicy(rng: Xoshiro256(seed: config.seed), komi: config.komi)
        self.scratch = PlayoutScratch(size: .nine)
        self.config = config
    }

    var config: EngineConfig

    /// Runs a search and picks the move to play.
    public func search(board: Board, colorToPlay: StoneColor, config: EngineConfig,
                       shouldCancel: @escaping () -> Bool = { Task<Never, Never>.isCancelled }) -> SearchResult {
        self.config = config
        policy.rng = Xoshiro256(seed: config.seed)
        policy.komi = config.komi
        scratch = PlayoutScratch(size: board.size)
        nodes.removeAll(keepingCapacity: true)

        // Root.
        nodes.append(MCTSNode(move: nil, mover: colorToPlay.opponent, colorToPlay: colorToPlay))
        let rootIndex = 0

        var blackWins: Double = 0
        var completedSimulations = 0
        let deadline = config.timeLimit.map { ProcessInfo.processInfo.systemUptime + max(0, $0) }
        let shouldStop = {
            shouldCancel() || (deadline.map { ProcessInfo.processInfo.systemUptime >= $0 } ?? false)
        }

        for _ in 0..<max(0, config.simulations) {
            if shouldStop() { break }
            var b = board

            // Selection + expansion.
            var nodeIndex = rootIndex
            var path: [Int] = [rootIndex]
            expandIfNeeded: while true {
                let node = nodes[nodeIndex]
                if node.terminal {
                    break expandIfNeeded
                }
                if !node.expanded {
                    if node.visits >= config.expandThreshold || nodeIndex == rootIndex {
                        if !expand(nodeIndex: nodeIndex, board: b, shouldCancel: shouldStop) {
                            break expandIfNeeded // terminal
                        }
                    }
                    if !nodes[nodeIndex].expanded { break expandIfNeeded } // leaf: simulate
                }
                // Select a child.
                guard let child = selectChild(nodeIndex: nodeIndex) else {
                    break expandIfNeeded
                }
                // Apply the child's move.
                if let m = nodes[child].move {
                    if case .played = b.play(color: nodes[child].mover, at: m) {
                        // ok
                    } else {
                        // Illegal (shouldn't happen — candidates pre-checked).
                        nodes[child].terminal = true
                        break expandIfNeeded
                    }
                } else {
                    b.pass()
                }
                nodeIndex = child
                path.append(child)
            }

            // Simulation.
            let leafColor = nodes[nodeIndex].colorToPlay
            let outcome = policy.playout(board: &b, startColor: leafColor, scratch: &scratch,
                                         shouldCancel: shouldStop)
            if shouldStop() { break }
            if outcome.winner == .black { blackWins += 1 }

            // Backpropagation (with RAVE).
            backpropagate(path: path, outcome: outcome, rootIndex: rootIndex)
            completedSimulations += 1
        }

        // Pick the move.
        let root = nodes[rootIndex]
        if completedSimulations == 0 {
            return SearchResult(bestMove: nil, winRateBlack: 0.5, scoreMeanBlack: 0,
                                simulations: 0, candidates: [])
        }
        guard !root.children.isEmpty else {
            return SearchResult(bestMove: nil, winRateBlack: blackWins / Double(max(1, completedSimulations)),
                                scoreMeanBlack: root.visits > 0 ? root.scoreSum / Double(root.visits) : 0,
                                simulations: completedSimulations, candidates: [])
        }
        let priorWeight = sqrt(Double(completedSimulations))
        // Large captures are under-valued by random rollouts: the opponent
        // often fails to save an endangered group even after we play away.
        // Keep an immediate, bounded tactical bonus in the final ranking.
        var captureBonus: [Int: Double] = [:]
        for childIndex in root.children {
            guard let move = nodes[childIndex].move else { continue }
            var next = board
            if case .played(let count) = next.play(color: colorToPlay, at: move),
               count >= 2, next.libertyCount(at: move) > 1 {
                captureBonus[childIndex] = Double(count) * min(16, priorWeight / 2)
            }
        }
        var ordered = root.children.sorted {
            let left = Double(nodes[$0].visits) + nodes[$0].prior * priorWeight + (captureBonus[$0] ?? 0)
            let right = Double(nodes[$1].visits) + nodes[$1].prior * priorWeight + (captureBonus[$1] ?? 0)
            return left == right ? $0 < $1 : left > right
        }
        // Beginner randomness: sometimes take the 2nd/3rd best.
        if config.randomness > 0, ordered.count > 2, policy.rng.next01() < config.randomness {
            let alt = policy.rng.next01() < 0.5 ? 1 : 2
            ordered.swapAt(0, min(alt, ordered.count - 1))
        }
        let best = ordered.first!
        let bestNode = nodes[best]

        let candidates = ordered.prefix(5).map { idx in
            let c = nodes[idx]
            return MoveCandidate(
                point: c.move,
                visits: c.visits,
                winRate: c.visits > 0 ? c.wins / Double(c.visits) : 0,
                scoreMean: c.visits > 0 ? c.scoreSum / Double(c.visits) : 0
            )
        }

        // Black win rate after the best move.
        let wrForMover = bestNode.visits > 0 ? bestNode.wins / Double(bestNode.visits) : 0.5
        let wrBlack = bestNode.mover == .black ? wrForMover : 1 - wrForMover

        return SearchResult(bestMove: bestNode.move,
                            winRateBlack: wrBlack,
                            scoreMeanBlack: bestNode.visits > 0 ? bestNode.scoreSum / Double(bestNode.visits) : 0,
                            simulations: completedSimulations,
                            candidates: candidates)
    }

    // MARK: Expansion

    /// Generates candidate moves for a node and creates child nodes.
    /// Returns false if no moves are available (terminal).
    @discardableResult
    func expand(nodeIndex: Int, board: Board, shouldCancel: () -> Bool = { false }) -> Bool {
        if board.endedByTwoPasses {
            nodes[nodeIndex].terminal = true
            return false
        }
        let color = nodes[nodeIndex].colorToPlay
        let candidates = generateCandidates(board: board, color: color,
                                            lastMove: nodes[nodeIndex].move, shouldCancel: shouldCancel)
        for (move, prior) in candidates {
            let child = MCTSNode(move: move, mover: color, colorToPlay: color.opponent, prior: prior, parent: nodeIndex)
            nodes[nodeIndex].children.append(nodes.count)
            nodes.append(child)
        }
        // A pass is always legal, and is especially relevant after a pass.
        if board.consecutivePasses > 0 || candidates.isEmpty {
            let child = MCTSNode(move: nil, mover: color, colorToPlay: color.opponent,
                                 prior: candidates.isEmpty ? 1 : 0.05, parent: nodeIndex)
            nodes[nodeIndex].children.append(nodes.count)
            nodes.append(child)
        }
        nodes[nodeIndex].expanded = true
        return true
    }

    /// Deterministic candidate generation with priors.
    func generateCandidates(board: Board, color: StoneColor, lastMove: Point?,
                            shouldCancel: () -> Bool = { false }) -> [(move: Point, prior: Double)] {
        let n = board.size.n
        if let neutralPoints = endgameNeutralPoints(board: board, shouldCancel: shouldCancel) {
            // With no dame left, a second pass ends an already enclosed game.
            // Score-based invasion remains available only before the first pass.
            if neutralPoints == 0 && board.consecutivePasses > 0 { return [] }
            if neutralPoints == 0 || board.consecutivePasses > 0 {
                let score = ScoreCalculator.areaScore(board: board, komi: config.komi)
                let margin = score.blackTotal - score.whiteTotal
                let lead = color == .black ? margin : -margin
                // A trailing side may still try an invasion. After a pass,
                // conceding every dame point must not reverse the lead.
                if neutralPoints == 0 && lead > 0 { return [] }
                if board.consecutivePasses > 0,
                   lead > Double(neutralPoints) + 0.5 { return [] }
            }
        }
        var seen = Set<Point>()
        var visitedGroups = Set<Point>()
        var result: [(Point, Double)] = []
        let cap = n < 13 ? 24 : 32

        // 1. Captures: inspect each enemy group once.
        for y in 0..<n {
            if shouldCancel() { return result }
            for x in 0..<n {
                let p = Point(x: x, y: y)
                guard board.stone(at: p) == color.opponent,
                      !visitedGroups.contains(p), let g = board.group(at: p) else { continue }
                visitedGroups.formUnion(g.stones)
                if g.libertyCount == 1 {
                    let lib = g.liberties[0]
                    if !seen.contains(lib), policy.isPlayable(board: board, at: lib,
                                                               color: color, scratch: &scratch) {
                        seen.insert(lib)
                        result.append((lib, min(1.0, 0.85 + 0.03 * Double(g.stoneCount))))
                        if result.count >= cap { return result }
                    }
                }
            }
        }

        // 2. Saves: only extensions that really escape atari.
        visitedGroups.removeAll(keepingCapacity: true)
        for y in 0..<n {
            if shouldCancel() { return result }
            for x in 0..<n {
                let p = Point(x: x, y: y)
                guard board.stone(at: p) == color,
                      !visitedGroups.contains(p), let g = board.group(at: p) else { continue }
                visitedGroups.formUnion(g.stones)
                if g.libertyCount == 1 {
                    let lib = g.liberties[0]
                    if !seen.contains(lib), policy.isPlayable(board: board, at: lib,
                                                               color: color, scratch: &scratch) {
                        seen.insert(lib)
                        result.append((lib, min(0.95, 0.7 + 0.03 * Double(g.stoneCount))))
                        if result.count >= cap { return result }
                    }
                }
            }
        }

        // 3. Neighborhood of the last move(s) and open areas.
        var candidatesPool: [Point] = []
        if let last = lastMove {
            for dy in -2...2 {
                for dx in -2...2 {
                    let x = last.x + dx, y = last.y + dy
                    if x >= 0, x < n, y >= 0, y < n { candidatesPool.append(Point(x: x, y: y)) }
                }
            }
        }
        // Star points + 3rd line for opening moves.
        for h in board.size.hoshi { candidatesPool.append(h) }
        for y in [2, n - 3] {
            for x in 2..<(n - 2) { candidatesPool.append(Point(x: x, y: y)) }
        }

        for p in candidatesPool {
            guard result.count < cap else { break }
            guard board.stone(at: p) == nil, p != board.koPoint, !seen.contains(p) else { continue }
            guard !policy.isTrueEye(board: board, at: p, color: color) else { continue }
            guard policy.isPlayable(board: board, at: p, color: color, scratch: &scratch) else { continue }
            seen.insert(p)
            let proximity = lastMove.map { manhattan($0, p) <= 2 ? 0.6 : 0.4 } ?? 0.5
            result.append((p, proximity))
        }

        // 4. Random legal fills (exploration).
        var rng = Xoshiro256(seed: config.seed &+ UInt64(truncatingIfNeeded: nodes.count))
        var tries = 0
        while result.count < cap && tries < 60 {
            tries += 1
            let p = Point(x: Int(rng.next() % UInt64(n)), y: Int(rng.next() % UInt64(n)))
            guard board.stone(at: p) == nil, p != board.koPoint, !seen.contains(p) else { continue }
            guard !policy.isTrueEye(board: board, at: p, color: color) else { continue }
            guard policy.isPlayable(board: board, at: p, color: color, scratch: &scratch) else { continue }
            seen.insert(p)
            result.append((p, 0.25))
        }

        // Near the end, random samples may all hit occupied points. Keep a
        // deterministic full-board fallback so an actual move is not missed.
        if result.isEmpty {
            for y in 0..<n {
                if shouldCancel() { break }
                for x in 0..<n {
                    let p = Point(x: x, y: y)
                    guard board.stone(at: p) == nil, p != board.koPoint,
                          !policy.isTrueEye(board: board, at: p, color: color),
                          policy.isPlayable(board: board, at: p, color: color, scratch: &scratch) else { continue }
                    result.append((p, 0.25))
                    if result.count >= cap { return result }
                }
            }
        }
        return result
    }

    /// A position is settled when every vacancy belongs to a small region
    /// enclosed by one connected group, with no group currently in atari.
    func isClearlyFinished(board: Board, shouldCancel: () -> Bool) -> Bool {
        endgameNeutralPoints(board: board, shouldCancel: shouldCancel) == 0
    }

    /// Flood-fill empty components. A small neutral region may be conceded
    /// after an opponent pass when the current score lead covers its points.
    /// Nil means this position still needs play or the scan was cancelled.
    func endgameNeutralPoints(board: Board, shouldCancel: () -> Bool) -> Int? {
        let maxRegionSize = 6
        var visitedEmpty = Set<Point>()
        var neutralPoints = 0
        for y in 0..<board.size.n {
            if shouldCancel() { return nil }
            for x in 0..<board.size.n {
                let start = Point(x: x, y: y)
                guard board.stone(at: start) == nil, visitedEmpty.insert(start).inserted else { continue }
                var stack = [start]
                var regionSize = 0
                var borderingColors = Set<StoneColor>()
                var borderingStones = Set<Point>()
                while let point = stack.popLast() {
                    if shouldCancel() { return nil }
                    regionSize += 1
                    if regionSize > maxRegionSize { return nil }
                    for neighbor in point.neighbors(on: board.size) {
                        if let stone = board.stone(at: neighbor) {
                            borderingColors.insert(stone)
                            borderingStones.insert(neighbor)
                        } else if visitedEmpty.insert(neighbor).inserted {
                            stack.append(neighbor)
                        }
                    }
                }
                if borderingColors.count == 1 {
                    guard let boundary = borderingStones.first,
                          let group = board.group(at: boundary),
                          borderingStones.isSubset(of: Set(group.stones)) else { return nil }
                } else if borderingColors.count == 2, regionSize <= 2 {
                    neutralPoints += regionSize
                    if neutralPoints > 2 { return nil }
                } else {
                    return nil
                }
            }
        }

        var visitedStones = Set<Point>()
        for (point, _) in board.stones {
            if shouldCancel() { return nil }
            guard !visitedStones.contains(point), let group = board.group(at: point) else { continue }
            if group.libertyCount == 1 { return nil }
            visitedStones.formUnion(group.stones)
        }
        return neutralPoints
    }

    func manhattan(_ a: Point, _ b: Point) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    // MARK: Selection

    /// UCT + RAVE child selection.
    func selectChild(nodeIndex: Int) -> Int? {
        let parent = nodes[nodeIndex]
        guard !parent.children.isEmpty else { return nil }
        let totalVisits = Double(parent.visits)
        var best: (index: Int, score: Double)? = nil

        for childIndex in parent.children {
            let child = nodes[childIndex]
            let q: Double
            if child.visits == 0 {
                q = child.prior
            } else {
                let value = child.wins / Double(child.visits)
                if child.raveVisits > 0 {
                    let raveValue = child.raveWins / Double(child.raveVisits)
                    let rv = Double(child.raveVisits)
                    let v = Double(child.visits)
                    let denom = rv + v + 4.0 * config.raveEquivalence * rv * v
                    let beta = rv / denom
                    q = (1.0 - beta) * value + beta * raveValue
                } else {
                    q = value
                }
            }
            let exploration = config.uctConstant * sqrt(log(totalVisits + 1) / Double(child.visits + 1))
            let score = q + exploration
            if best == nil || score > best!.score {
                best = (childIndex, score)
            }
        }
        return best?.index
    }

    // MARK: Backpropagation

    func backpropagate(path: [Int], outcome: PlayoutOutcome, rootIndex: Int) {
        // Regular backprop.
        for idx in path {
            let mover = nodes[idx].mover
            nodes[idx].visits += 1
            if outcome.winner == mover { nodes[idx].wins += 1 }
            nodes[idx].scoreSum += outcome.scoreMargin
        }
        // RAVE: for each node, update children whose move was the first
        // played by that child's mover in the playout.
        for idx in path {
            let colorToPlay = nodes[idx].colorToPlay
            let first = colorToPlay == .black ? outcome.firstBlack : outcome.firstWhite
            guard let first = first else { continue }
            for childIndex in nodes[idx].children where nodes[childIndex].move == first {
                nodes[childIndex].raveVisits += 1
                if outcome.winner == nodes[childIndex].mover {
                    nodes[childIndex].raveWins += 1
                }
                nodes[childIndex].raveScoreSum += outcome.scoreMargin
            }
        }
    }
}
