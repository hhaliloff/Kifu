import SwiftUI

enum KifuPalette {
    // Xuan paper, ink, cinnabar and muted mineral pigments.
    static let paper = Color(red: 0.929, green: 0.925, blue: 0.902)       // #edece6
    static let elevated = Color(red: 0.973, green: 0.969, blue: 0.949)    // #f8f7f2
    static let sunken = Color(red: 0.902, green: 0.894, blue: 0.863)      // #e6e4dc
    static let ink = Color(red: 0.106, green: 0.102, blue: 0.090)         // #1b1a17
    static let secondaryInk = Color(red: 0.306, green: 0.302, blue: 0.278)
    static let tertiaryInk = Color(red: 0.400, green: 0.396, blue: 0.373)
    static let line = Color(red: 0.863, green: 0.851, blue: 0.812)        // #dcd9cf

    static let seal = Color(red: 0.663, green: 0.220, blue: 0.141)        // #a93824
    static let sealPressed = Color(red: 0.537, green: 0.153, blue: 0.090)
    static let jade = Color(red: 0.329, green: 0.431, blue: 0.373)        // #546e5f
    static let jadePressed = Color(red: 0.231, green: 0.333, blue: 0.278)
    static let jadeWash = jade.opacity(0.12)
    static let gold = Color(red: 0.498, green: 0.357, blue: 0.145)
    static let azurite = Color(red: 0.247, green: 0.400, blue: 0.435)
    static let warn = Color(red: 0.596, green: 0.275, blue: 0.137)

    static let woodLight = Color(red: 0.933, green: 0.890, blue: 0.784)
    static let woodMid = Color(red: 0.910, green: 0.863, blue: 0.741)     // #e8ddc1
    static let woodDeep = Color(red: 0.859, green: 0.804, blue: 0.651)    // #dbcda6
    // Light surface aliases retained for existing ContentView call sites.
    static let walnut = Color(red: 0.973, green: 0.969, blue: 0.949)
    static let woodLacquer = Color(red: 0.929, green: 0.910, blue: 0.859)
    static let grid = Color(red: 0.231, green: 0.204, blue: 0.153)        // #3b3427
    static let blackStoneHighlight = Color(red: 0.353, green: 0.341, blue: 0.325)
    static let blackStoneMid = Color(red: 0.137, green: 0.129, blue: 0.125)
    static let blackStoneEdge = Color(red: 0.051, green: 0.047, blue: 0.043)
    static let whiteStoneHighlight = Color.white
    static let whiteStoneMid = Color(red: 0.957, green: 0.937, blue: 0.890)
    static let whiteStoneEdge = Color(red: 0.851, green: 0.824, blue: 0.745)
    static let shadowInk = Color(red: 0.153, green: 0.125, blue: 0.090)
}

struct PaperBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [KifuPalette.elevated, KifuPalette.paper, KifuPalette.paper], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            Canvas { context, size in
                var rng = SeededRandom(seed: 2048)
                for _ in 0..<420 {
                    let point = CGPoint(x: rng.next(in: 0...size.width), y: rng.next(in: 0...size.height))
                    let length = rng.next(in: 0.3...1.2)
                    context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.45, height: length)), with: .color(KifuPalette.ink.opacity(0.045)))
                }
            }
            .ignoresSafeArea()
            Canvas { context, size in
                let landscapeHeight = min(190, size.height * 0.26)
                var distant = Path()
                distant.move(to: CGPoint(x: 0, y: landscapeHeight * 0.75))
                distant.addQuadCurve(to: CGPoint(x: size.width * 0.26, y: landscapeHeight * 0.43), control: CGPoint(x: size.width * 0.13, y: landscapeHeight * 0.81))
                distant.addQuadCurve(to: CGPoint(x: size.width * 0.54, y: landscapeHeight * 0.80), control: CGPoint(x: size.width * 0.40, y: landscapeHeight * 0.63))
                distant.addQuadCurve(to: CGPoint(x: size.width, y: landscapeHeight * 0.50), control: CGPoint(x: size.width * 0.74, y: landscapeHeight * 0.91))
                distant.addLine(to: CGPoint(x: size.width, y: landscapeHeight))
                distant.addLine(to: CGPoint(x: 0, y: landscapeHeight))
                distant.closeSubpath()
                context.fill(distant, with: .linearGradient(Gradient(colors: [KifuPalette.jade.opacity(0.075), .clear]), startPoint: CGPoint(x: 0, y: landscapeHeight * 0.40), endPoint: CGPoint(x: 0, y: landscapeHeight)))

                var near = Path()
                near.move(to: CGPoint(x: 0, y: landscapeHeight * 0.88))
                near.addQuadCurve(to: CGPoint(x: size.width * 0.61, y: landscapeHeight * 0.64), control: CGPoint(x: size.width * 0.33, y: landscapeHeight * 0.99))
                near.addQuadCurve(to: CGPoint(x: size.width, y: landscapeHeight * 0.90), control: CGPoint(x: size.width * 0.82, y: landscapeHeight * 0.79))
                context.stroke(near, with: .color(KifuPalette.ink.opacity(0.075)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

                let trunkX = size.width * 0.91
                var trunk = Path()
                trunk.move(to: CGPoint(x: trunkX + 9, y: landscapeHeight))
                trunk.addCurve(to: CGPoint(x: trunkX - 3, y: landscapeHeight * 0.16), control1: CGPoint(x: trunkX - 2, y: landscapeHeight * 0.66), control2: CGPoint(x: trunkX + 13, y: landscapeHeight * 0.39))
                context.stroke(trunk, with: .color(KifuPalette.ink.opacity(0.15)), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
                for index in 0..<5 {
                    let y = landscapeHeight * (0.23 + CGFloat(index) * 0.115)
                    let reach: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                    var branch = Path()
                    branch.move(to: CGPoint(x: trunkX, y: y + 15))
                    branch.addQuadCurve(to: CGPoint(x: trunkX + reach * 44, y: y), control: CGPoint(x: trunkX + reach * 24, y: y + 4))
                    context.stroke(branch, with: .color(KifuPalette.ink.opacity(0.13)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                    for needle in 0..<6 {
                        let x = trunkX + reach * CGFloat(16 + needle * 5)
                        let tipY = y + CGFloat(8 - needle)
                        var needles = Path()
                        needles.move(to: CGPoint(x: x, y: tipY))
                        needles.addLine(to: CGPoint(x: x + reach * 5, y: tipY - 8))
                        needles.move(to: CGPoint(x: x, y: tipY))
                        needles.addLine(to: CGPoint(x: x - reach * 3, y: tipY - 7))
                        context.stroke(needles, with: .color(KifuPalette.jade.opacity(0.15)), lineWidth: 0.9)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LacquerPanel { content }
    }
}

struct LacquerPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                LinearGradient(
                    colors: [KifuPalette.elevated, KifuPalette.elevated, KifuPalette.paper],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KifuPalette.line, lineWidth: 1))
            .shadow(color: KifuPalette.shadowInk.opacity(0.055), radius: 9, y: 3)
    }
}

struct OrnamentDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, KifuPalette.line], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            Rectangle()
                .fill(KifuPalette.seal)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(LinearGradient(colors: [KifuPalette.line, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

struct SealButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            buttonLabel
                .font(.headline)
                .foregroundStyle(KifuPalette.elevated)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, 24)
                .background(LinearGradient(colors: [KifuPalette.seal, KifuPalette.sealPressed], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KifuPalette.sealPressed.opacity(0.45), lineWidth: 1))
                .shadow(color: KifuPalette.seal.opacity(0.16), radius: 7, y: 3)
        }
        .buttonStyle(SealButtonStyle())
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

struct OutlineButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            buttonLabel
                .font(.headline)
                .foregroundStyle(KifuPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 24)
                .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KifuPalette.ink.opacity(0.72), lineWidth: 1))
        }
        .buttonStyle(OutlineButtonStyle())
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

struct BrushProgressBar: View {
    let value: Double

    private var clampedValue: Double { min(1, max(0, value)) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(KifuPalette.sunken)
                Capsule()
                    .fill(LinearGradient(colors: [KifuPalette.jade, KifuPalette.jadePressed], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * clampedValue)
            }
        }
        .frame(height: 7)
        .accessibilityValue("\(Int(clampedValue * 100)) percent")
    }
}

struct SealBadge: View {
    let text: String
    var color: Color = KifuPalette.seal
    var body: some View {
        Text(text)
            .font(.system(.title3, design: .serif, weight: .semibold))
            .foregroundStyle(KifuPalette.ink)
            .frame(width: 48, height: 48)
            .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color, lineWidth: 1.5))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).inset(by: 3).stroke(color.opacity(0.42), lineWidth: 0.8))
    }
}

private struct SealButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        state = state &* 2862933555777941757 &+ 3037000493
        let value = CGFloat(state % 10_000) / 10_000
        return range.lowerBound + (range.upperBound - range.lowerBound) * value
    }
}
