import SwiftUI
import GoCore

struct GobanView: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var pendingPoint: Point?
    let board: Board
    var coordinates = false
    var highlightLiberties = false
    var suggestedPoint: Point? = nil
    var lastMove: Point? = nil
    var markedDead: Set<Point> = []
    var scoreReview = false
    var interactive = false
    var onTap: ((Point) -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let inset = side * (coordinates ? 0.09 : 0.055)
            let gridSide = side - inset * 2
            let cell = gridSide / CGFloat(max(board.size.n - 1, 1))
            Canvas { context, size in
                let boardRect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
                let playingSurface = boardRect.insetBy(dx: 2, dy: 2)
                context.fill(Path(roundedRect: boardRect, cornerRadius: 12), with: .color(KifuPalette.woodDeep))
                context.fill(
                    Path(roundedRect: playingSurface, cornerRadius: 10),
                    with: .linearGradient(
                        Gradient(colors: [KifuPalette.woodLight, KifuPalette.woodMid, KifuPalette.woodDeep]),
                        startPoint: CGPoint(x: playingSurface.minX, y: playingSurface.minY),
                        endPoint: CGPoint(x: playingSurface.maxX, y: playingSurface.maxY)
                    )
                )
                context.stroke(Path(roundedRect: boardRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 12), with: .color(KifuPalette.grid.opacity(0.24)), lineWidth: 1)
                context.stroke(Path(roundedRect: playingSurface.insetBy(dx: 1, dy: 1), cornerRadius: 9), with: .color(KifuPalette.elevated.opacity(0.46)), lineWidth: 1)

                // Subtle fixed grain keeps the playing field quiet and fully vector based.
                var grain = Path()
                for index in 0..<9 {
                    let x = playingSurface.minX + playingSurface.width * CGFloat(index + 1) / 10
                    grain.move(to: CGPoint(x: x, y: playingSurface.minY + 7))
                    grain.addCurve(
                        to: CGPoint(x: x + CGFloat((index % 3) - 1) * 4, y: playingSurface.maxY - 7),
                        control1: CGPoint(x: x + 3, y: playingSurface.minY + playingSurface.height * 0.32),
                        control2: CGPoint(x: x - 3, y: playingSurface.minY + playingSurface.height * 0.68)
                    )
                }
                context.stroke(grain, with: .color(KifuPalette.grid.opacity(0.035)), lineWidth: 0.8)

                let origin = CGPoint(x: (size.width - gridSide) / 2, y: (size.height - gridSide) / 2)
                var innerGrid = Path()
                var outerGrid = Path()
                for index in 0..<board.size.n {
                    let offset = CGFloat(index) * cell
                    let line = index == 0 || index == board.size.n - 1 ? outerGrid : innerGrid
                    var updatedLine = line
                    updatedLine.move(to: CGPoint(x: origin.x, y: origin.y + offset))
                    updatedLine.addLine(to: CGPoint(x: origin.x + gridSide, y: origin.y + offset))
                    updatedLine.move(to: CGPoint(x: origin.x + offset, y: origin.y))
                    updatedLine.addLine(to: CGPoint(x: origin.x + offset, y: origin.y + gridSide))
                    if index == 0 || index == board.size.n - 1 {
                        outerGrid = updatedLine
                    } else {
                        innerGrid = updatedLine
                    }
                }
                let gridWidth: CGFloat = board.size.n == 19 ? 1 : (board.size.n == 13 ? 1.1 : 1.25)
                context.stroke(innerGrid, with: .color(KifuPalette.grid.opacity(0.72)), lineWidth: gridWidth)
                context.stroke(outerGrid, with: .color(KifuPalette.grid.opacity(0.82)), lineWidth: gridWidth + 0.2)

                for point in board.size.hoshi {
                    let center = CGPoint(x: origin.x + CGFloat(point.x) * cell, y: origin.y + CGFloat(point.y) * cell)
                    let radius = min(3, max(2, cell / 7))
                    context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(KifuPalette.grid.opacity(0.85)))
                }

                let blackStoneGradient = Gradient(stops: [
                    .init(color: KifuPalette.blackStoneHighlight, location: 0),
                    .init(color: KifuPalette.blackStoneMid, location: 0.55),
                    .init(color: KifuPalette.blackStoneEdge, location: 1)
                ])
                let whiteStoneGradient = Gradient(stops: [
                    .init(color: KifuPalette.whiteStoneHighlight, location: 0),
                    .init(color: KifuPalette.whiteStoneMid, location: 0.55),
                    .init(color: KifuPalette.whiteStoneEdge, location: 1)
                ])
                for item in board.stones {
                    let center = CGPoint(x: origin.x + CGFloat(item.point.x) * cell, y: origin.y + CGFloat(item.point.y) * cell)
                    let radius = cell * 0.47
                    let stoneRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    let shadowRect = stoneRect.offsetBy(dx: 0, dy: 1.5)
                    context.fill(Path(ellipseIn: shadowRect), with: .color(KifuPalette.shadowInk.opacity(0.28)))
                    let stonePath = Path(ellipseIn: stoneRect)
                    context.fill(stonePath, with: .radialGradient(
                        item.color == .black ? blackStoneGradient : whiteStoneGradient,
                        center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35),
                        startRadius: 0,
                        endRadius: radius * 1.65
                    ))
                    context.stroke(stonePath,
                                   with: .color(item.color == .black ? KifuPalette.blackStoneEdge : KifuPalette.grid.opacity(0.78)),
                                   lineWidth: item.color == .black ? 0.6 : 1.2)
                    if item.point == lastMove {
                        var seal = Path()
                        let mark = min(4.5, radius * 0.5)
                        seal.move(to: CGPoint(x: center.x, y: center.y - mark))
                        seal.addLine(to: CGPoint(x: center.x + mark, y: center.y))
                        seal.addLine(to: CGPoint(x: center.x, y: center.y + mark))
                        seal.addLine(to: CGPoint(x: center.x - mark, y: center.y))
                        seal.closeSubpath()
                        context.fill(seal, with: .color(KifuPalette.seal))
                        if item.color == .black {
                            context.stroke(seal, with: .color(KifuPalette.elevated), lineWidth: 0.8)
                        }
                    }
                    if markedDead.contains(item.point) {
                        var cross = Path()
                        let offset = radius * 0.45
                        cross.move(to: CGPoint(x: center.x - offset, y: center.y - offset))
                        cross.addLine(to: CGPoint(x: center.x + offset, y: center.y + offset))
                        cross.move(to: CGPoint(x: center.x + offset, y: center.y - offset))
                        cross.addLine(to: CGPoint(x: center.x - offset, y: center.y + offset))
                        context.stroke(cross, with: .color(item.color == .black ? KifuPalette.elevated : KifuPalette.seal), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }

                if let suggestedPoint {
                    let center = CGPoint(x: origin.x + CGFloat(suggestedPoint.x) * cell, y: origin.y + CGFloat(suggestedPoint.y) * cell)
                    let radius = cell * 0.39
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(KifuPalette.seal), lineWidth: max(1.5, min(2.5, cell * 0.08)))
                }

                if let pendingPoint, board.size == .nineteen {
                    let center = CGPoint(x: origin.x + CGFloat(pendingPoint.x) * cell,
                                         y: origin.y + CGFloat(pendingPoint.y) * cell)
                    let radius = cell * 0.58
                    let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                       width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(KifuPalette.seal), lineWidth: 2.3)
                }

                if highlightLiberties, let lastMove, let group = board.group(at: lastMove) {
                    for liberty in group.liberties {
                        let center = CGPoint(x: origin.x + CGFloat(liberty.x) * cell, y: origin.y + CGFloat(liberty.y) * cell)
                        let libertyMark = Path(ellipseIn: CGRect(x: center.x - cell * 0.14, y: center.y - cell * 0.14, width: cell * 0.28, height: cell * 0.28))
                        context.fill(libertyMark, with: .color(KifuPalette.jadePressed.opacity(0.55)))
                        context.stroke(libertyMark, with: .color(KifuPalette.grid.opacity(0.55)), lineWidth: 0.75)
                    }
                }

                if coordinates {
                    for index in 0..<board.size.n {
                        let x = origin.x + CGFloat(index) * cell
                        let y = origin.y + CGFloat(index) * cell
                        let label = Point.humanLetter(forColumn: index)
                        context.draw(Text(label).font(.system(size: 10, design: .serif)).foregroundStyle(KifuPalette.grid), at: CGPoint(x: x, y: origin.y - 11))
                        context.draw(Text(label).font(.system(size: 10, design: .serif)).foregroundStyle(KifuPalette.grid), at: CGPoint(x: x, y: origin.y + gridSide + 11))
                        let number = "\(board.size.n - index)"
                        context.draw(Text(number).font(.system(size: 10, design: .serif)).foregroundStyle(KifuPalette.grid), at: CGPoint(x: origin.x - 11, y: y))
                        context.draw(Text(number).font(.system(size: 10, design: .serif)).foregroundStyle(KifuPalette.grid), at: CGPoint(x: origin.x + gridSide + 11, y: y))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(interactive && !voiceOverEnabled ? SpatialTapGesture().onEnded { value in
                let origin = CGPoint(x: (proxy.size.width - gridSide) / 2, y: (proxy.size.height - gridSide) / 2)
                let x = Int(((value.location.x - origin.x) / cell).rounded())
                let y = Int(((value.location.y - origin.y) / cell).rounded())
                guard x >= 0, x < board.size.n, y >= 0, y < board.size.n else { return }
                let point = Point(x: x, y: y)
                if board.size == .nineteen && !scoreReview {
                    if pendingPoint == point {
                        pendingPoint = nil
                        onTap?(point)
                    } else {
                        pendingPoint = point
                    }
                } else {
                    onTap?(point)
                }
            } : nil)
            .overlay {
                if interactive && voiceOverEnabled {
                    let origin = CGPoint(x: (proxy.size.width - gridSide) / 2, y: (proxy.size.height - gridSide) / 2)
                    ZStack {
                        ForEach(0..<(board.size.n * board.size.n), id: \.self) { index in
                            let point = Point(x: index % board.size.n, y: index / board.size.n)
                            Button { onTap?(point) } label: {
                                Color.clear.frame(width: max(20, cell), height: max(20, cell))
                            }
                            .buttonStyle(.plain)
                            .position(x: origin.x + CGFloat(point.x) * cell,
                                      y: origin.y + CGFloat(point.y) * cell)
                            .accessibilityLabel(accessiblePointLabel(point))
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
        .onChange(of: board.hash) { _, _ in pendingPoint = nil }
        .accessibilityElement(children: interactive && voiceOverEnabled ? .contain : .ignore)
        .accessibilityLabel(KifuCopy.current.boardLabel(size: board.size.n))
        .accessibilityHint(scoreReview ? KifuCopy.current.text(.markDeadGroups) :
            board.size == .nineteen && interactive ? KifuCopy.current.text(.confirmPoint) :
                KifuCopy.current.boardHint(interactive: interactive))
    }

    private func accessiblePointLabel(_ point: Point) -> String {
        let coordinate = point.humanCoordinate(on: board.size)
        if let stone = board.stone(at: point) {
            if scoreReview {
                let state = KifuCopy.current.text(markedDead.contains(point) ? .deadGroupMarked : .deadGroupUnmarked)
                return "\(coordinate), \(KifuCopy.current.color(stone)), \(state)"
            }
            return "\(coordinate), \(KifuCopy.current.color(stone))"
        }
        return coordinate
    }
}
