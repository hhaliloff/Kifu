import SwiftUI

@main
struct KifuApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var profile = KifuProfile()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(profile)
                if showSplash {
                    KifuSplashView()
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 400))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    showSplash = false
                }
            }
        }
    }
}



private struct KifuSplashView: View {
    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 26) {
                Spacer()
                VStack(spacing: 12) {
                    Text("Kifu")
                        .font(.system(size: 58, weight: .bold, design: .serif))
                        .foregroundStyle(KifuPalette.ink)
                    Text(KifuCopy.current.splashCaption)
                        .font(.headline)
                        .tracking(2)
                        .foregroundStyle(KifuPalette.jade)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .background(KifuPalette.elevated.opacity(0.62), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(KifuPalette.gold.opacity(0.5), lineWidth: 1))
                Text("“\(KifuCopy.current.splashQuote)”")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KifuPalette.ink)
                    .padding(.horizontal, 38)
                Spacer()
                OrnamentDivider().padding(.horizontal, 54)
                Text("Kifu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KifuPalette.secondaryInk)
                    .padding(.bottom, 18)
            }
            .padding(.top, 50)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kifu")
    }
}
