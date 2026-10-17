// MARK: - Zobrist hashing

/// Deterministic Zobrist hash tables for board positions.
/// One table per board size, generated with a fixed seed so hashes are
/// stable across launches (important for superko and testing).
public struct ZobristTable: Sendable {
    /// Hash contributions: `black[idx]` / `white[idx]` where `idx = y * n + x`.
    public let black: [UInt64]
    public let white: [UInt64]
    public let n: Int

    public init(size: BoardSize, seed: UInt64 = 0x9E3779B97F4A7C15) {
        let count = size.n * size.n
        var rng = SplitMix64(seed: seed)
        var b: [UInt64] = []
        var w: [UInt64] = []
        b.reserveCapacity(count)
        w.reserveCapacity(count)
        for _ in 0..<count { b.append(rng.next()) }
        for _ in 0..<count { w.append(rng.next()) }
        self.black = b
        self.white = w
        self.n = size.n
    }

    @inline(__always)
    public func hash(for color: StoneColor, at point: Point) -> UInt64 {
        let idx = point.y * n + point.x
        switch color {
        case .black: return black[idx]
        case .white: return white[idx]
        }
    }
}

/// Fast deterministic PRNG used to seed Zobrist tables.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Xoshiro256** — a fast, seedable, deterministic random number generator.
/// Used by the playout engine and tests so games are reproducible.
public struct Xoshiro256: RandomNumberGenerator, Sendable {
    public typealias State = (UInt64, UInt64, UInt64, UInt64)
    public var state: State

    public init(seed: UInt64) {
        var sm = SplitMix64(seed: seed &+ 0x5DEECE66D)
        state = (sm.next(), sm.next(), sm.next(), sm.next())
    }

    public init(state: State) { self.state = state }

    public mutating func next() -> UInt64 {
        let result = rotl(state.1 &* 5, 7) &* 9
        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = rotl(state.3, 45)
        return result
    }

    @inline(__always)
    private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << k) | (x >> (64 &- k))
    }
}
