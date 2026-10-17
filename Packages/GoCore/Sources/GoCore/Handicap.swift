// MARK: - Handicap stones

/// Fixed handicap stone placements. Coordinates are 1-based (col, row)
/// from the top-left, matching common tables; converted to 0-based `Point`.
public enum Handicap {
    /// Maximum fixed handicap per board size (free placement beyond).
    public static func maxStones(for size: BoardSize) -> Int {
        switch size {
        case .nine: return 5
        case .thirteen, .nineteen: return 9
        }
    }

    /// Fixed handicap stone positions (0-based, top-left origin) for the
    /// given board size and handicap count (2...max). Returns [] for 0/1.
    public static func stones(for size: BoardSize, count: Int) -> [Point] {
        guard count >= 2 else { return [] }
        let n = size.n
        // 1-based key points per board size.
        let cornerHigh = size == .nine ? 7 : size == .thirteen ? 10 : 16
        let cornerLow = size == .nine ? 3 : 4
        let middle = n / 2 + 1 // 5 for 9, 7 for 13, 10 for 19

        func p(_ col: Int, _ row: Int) -> Point { Point(x: col - 1, y: row - 1) }

        // Standard order: 3-3 corners first, then sides, center last.
        var stones: [Point] = []
        switch count {
        case 2:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh)]
        case 3:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh), p(cornerHigh, cornerHigh)]
        case 4:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow)]
        case 5:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow), p(middle, middle)]
        case 6:
            // Four corners + left/right sides, no center.
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow),
                      p(cornerLow, middle), p(cornerHigh, middle)]
        case 7:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow),
                      p(cornerLow, middle), p(cornerHigh, middle), p(middle, middle)]
        case 8:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow),
                      p(cornerLow, middle), p(cornerHigh, middle),
                      p(middle, cornerLow), p(middle, cornerHigh)]
        case 9:
            stones = [p(cornerHigh, cornerLow), p(cornerLow, cornerHigh),
                      p(cornerHigh, cornerHigh), p(cornerLow, cornerLow),
                      p(cornerLow, middle), p(cornerHigh, middle),
                      p(middle, cornerLow), p(middle, cornerHigh), p(middle, middle)]
        default:
            stones = []
        }
        let cap = maxStones(for: size)
        return Array(stones.prefix(cap))
    }
}
