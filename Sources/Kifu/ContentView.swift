import SwiftUI
import UniformTypeIdentifiers
import GoCore

private extension AppLanguage {
    var localeIdentifier: String {
        switch self {
        case .russian: return "ru"
        case .english: return "en"
        case .korean: return "ko"
        case .japanese: return "ja"
        case .chinese: return "zh-Hans"
        }
    }
}

struct ContentView: View {
    private struct AnalysisSession: Identifiable {
        let id = UUID()
        let board: Board
        let record: GameRecord?
    }

    @EnvironmentObject private var profile: KifuProfile
    @State private var tab: AppTab = .home
    @State private var showSetup = false
    @State private var showGame = false
    @State private var settings = GameSettings()
    @State private var analysisSession: AnalysisSession?
    @State private var initialGameRecord: GameRecord?
    @State private var gameSessionID = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            PaperBackground()
            Group {
                switch tab {
                case .home: HomeView(onPlay: { showSetup = true }, onLearn: { tab = .learn }, onPuzzle: { tab = .tsumego }, onAnalysis: {
                    analysisSession = AnalysisSession(board: Board(size: .nine), record: nil)
                })
                case .learn: LearnView()
                case .tsumego: TsumegoView()
                case .library: LibraryView(onCreatePosition: {
                    analysisSession = AnalysisSession(board: Board(size: .nine), record: nil)
                }, onAnalyze: { record in
                    analysisSession = AnalysisSession(board: record.replay().board, record: record)
                }, onPlay: { record, color in beginGame(from: record, humanColor: color) })
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaPadding(.bottom, 104)
            .id(profile.language)
            BottomBar(tab: $tab)
        }
        .sheet(isPresented: $showSetup) {
            GameSetupView(settings: settings) { selected in
                settings = selected
                initialGameRecord = nil
                gameSessionID = UUID()
                showSetup = false
                showGame = true
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showGame) {
            GameScreen(settings: settings, initialRecord: initialGameRecord).id(gameSessionID)
        }
        .sheet(item: $analysisSession) { session in
            AnalysisView(board: session.board, record: session.record,
                         onPlay: { record, color in beginGame(from: record, humanColor: color) })
                .id(session.id)
        }
        .environment(\.locale, Locale(identifier: profile.language.localeIdentifier))
        .preferredColorScheme(.light)
    }

    private func beginGame(from record: GameRecord, humanColor: StoneColor) {
        var playable = record
        playable.result = nil
        if playable.moves.suffix(2).count == 2,
           playable.moves.suffix(2).allSatisfy({ $0.point == nil }) {
            playable.moves.removeLast(2)
        }
        settings = .continuing(playable, humanColor: humanColor)
        initialGameRecord = playable
        gameSessionID = UUID()
        analysisSession = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showGame = true }
    }
}

struct BottomBar: View {
    @EnvironmentObject private var profile: KifuProfile
    @Binding var tab: AppTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { withAnimation(.easeInOut(duration: 0.2)) { tab = item } } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: .regular))
                            .frame(height: 24)
                        Text(item.title(for: profile.language))
                            .font(.caption2.weight(tab == item ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Capsule().fill(tab == item ? KifuPalette.seal : .clear).frame(width: 22, height: 2)
                    }
                    .foregroundStyle(tab == item ? KifuPalette.ink : KifuPalette.secondaryInk)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title(for: profile.language))
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8).padding(.top, 8)
        .background(KifuPalette.elevated)
        .overlay(alignment: .top) {
            Rectangle().fill(KifuPalette.ink.opacity(0.16)).frame(height: 1)
        }
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var action: (() -> Void)? = nil
    var actionIcon = "gearshape"
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("InkLandscape")
                .resizable()
                .scaledToFill()
                .frame(height: 120)
                .clipped()
                .opacity(0.38)
                .mask(LinearGradient(colors: [.clear, .white, .white], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(KifuPalette.seal).frame(width: 8, height: 8)
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.semibold)).tracking(1.5)
                            .foregroundStyle(KifuPalette.seal)
                    }
                    Text(title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                }
                Spacer()
                if let action {
                    Button(action: action) {
                        Image(systemName: actionIcon).font(.headline)
                            .foregroundStyle(KifuPalette.ink)
                            .frame(width: 44, height: 44)
                            .background(KifuPalette.elevated, in: Circle())
                            .overlay(Circle().stroke(KifuPalette.seal.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(KifuCopy.current.text(.language))
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct HomeView: View {
    @EnvironmentObject private var profile: KifuProfile
    let onPlay: () -> Void
    let onLearn: () -> Void
    let onPuzzle: () -> Void
    let onAnalysis: () -> Void
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(KifuCopy.current.greeting(profile.nickname)).font(.title3.weight(.semibold)).foregroundStyle(KifuPalette.ink)
                    }
                    Spacer()
                    HStack(spacing: 6) { Image(systemName: "flame"); Text("\(profile.currentStreak)") }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(KifuPalette.gold)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(KifuPalette.elevated, in: Capsule())
                        .overlay(Capsule().stroke(KifuPalette.gold.opacity(0.4)))
                }.padding(.horizontal, 20).padding(.top, 14)

                HomeHero(onPlay: onPlay, games: profile.games, lessons: profile.lessons)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(KifuCopy.current.text(.continuePath))
                    HStack(spacing: 12) { QuickAction(icon: "text.book.closed", title: KifuCopy.current.text(.lesson), subtitle: KifuCopy.current.text(.liberties), tint: KifuPalette.jade, action: onLearn); QuickAction(icon: "square.grid.3x3", title: KifuCopy.current.text(.dailyPuzzle), subtitle: KifuCopy.current.text(.capture), tint: KifuPalette.azurite, action: onPuzzle) }.padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(KifuCopy.current.text(.tools), subtitle: KifuCopy.current.text(.understandPosition))
                    Button(action: onAnalysis) {
                        HStack(spacing: 14) {
                            Image(systemName: "scope").font(.title3).foregroundStyle(KifuPalette.gold)
                                .frame(width: 46, height: 46).background(KifuPalette.sunken, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(KifuCopy.current.text(.analyzePosition)).font(.headline).foregroundStyle(KifuPalette.ink)
                                Text(KifuCopy.current.text(.analysisPrompt)).font(.caption).foregroundStyle(KifuPalette.secondaryInk).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.right").foregroundStyle(KifuPalette.gold)
                        }
                        .padding(16)
                        .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KifuPalette.gold.opacity(0.32)))
                    }
                    .buttonStyle(.plain).padding(.horizontal, 20)
                }
                Spacer(minLength: 16)
            }
        }
    }
    private func sectionTitle(_ title: String, subtitle: String? = nil) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(title).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
            Spacer(minLength: 4)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(KifuPalette.secondaryInk).lineLimit(1)
            }
        }.padding(.horizontal, 20)
    }
}

private struct HomeHero: View {
    let onPlay: () -> Void
    let games: Int
    let lessons: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("InkLandscape")
                .resizable()
                .scaledToFill()
                .frame(height: 112)
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KifuCopy.current.language == .russian ? "ГО" : KifuCopy.current.language == .english ? "GO" : KifuCopy.current.language == .korean ? "바둑" : KifuCopy.current.language == .japanese ? "囲碁" : "围棋")
                        .font(.system(size: 58, weight: .light, design: .serif))
                        .foregroundStyle(KifuPalette.ink)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                HeroGoban().frame(width: 110, height: 110)
            }
            OrnamentDivider()
            HStack(spacing: 16) {
                Label("\(games) \(KifuCopy.current.text(.games))", systemImage: "circle.grid.3x3")
                Label("\(lessons) \(KifuCopy.current.text(.lessons))", systemImage: "book.closed")
            }
            .font(.caption.weight(.medium)).foregroundStyle(KifuPalette.secondaryInk)
            SealButton(title: KifuCopy.current.text(.playAI), systemImage: "play.fill", action: onPlay)
        }
        .padding(16)
        .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KifuPalette.ink.opacity(0.15), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KifuPalette.seal.opacity(0.18), lineWidth: 1).padding(4))
        .shadow(color: KifuPalette.shadowInk.opacity(0.1), radius: 12, y: 6)
    }
}

private struct HeroGoban: View {
    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 10
            let step = (size.width - inset * 2) / 4
            var grid = Path()
            for index in 0...4 {
                let coordinate = inset + CGFloat(index) * step
                grid.move(to: CGPoint(x: inset, y: coordinate))
                grid.addLine(to: CGPoint(x: size.width - inset, y: coordinate))
                grid.move(to: CGPoint(x: coordinate, y: inset))
                grid.addLine(to: CGPoint(x: coordinate, y: size.height - inset))
            }
            context.stroke(grid, with: .color(KifuPalette.grid.opacity(0.72)), lineWidth: 1)
            for (x, y, black) in [(1, 1, true), (2, 1, false), (1, 2, true), (3, 2, false), (2, 3, true)] {
                let rect = CGRect(x: inset + CGFloat(x) * step - 8, y: inset + CGFloat(y) * step - 8, width: 16, height: 16)
                context.fill(Path(ellipseIn: rect), with: .color(black ? KifuPalette.blackStoneMid : KifuPalette.whiteStoneMid))
                context.stroke(Path(ellipseIn: rect), with: .color(KifuPalette.gold.opacity(0.45)), lineWidth: 0.7)
            }
        }
        .padding(6)
        .background(KifuPalette.woodLight, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KifuPalette.gold.opacity(0.65)))
        .accessibilityHidden(true)
    }
}

struct QuickAction: View {
    let icon: String; let title: String; let subtitle: String; let tint: Color; let action: () -> Void
    var body: some View { Button(action: action) { VStack(alignment: .leading, spacing: 9) { Image(systemName: icon).font(.title3).foregroundStyle(tint); Text(title).font(.headline).foregroundStyle(KifuPalette.ink); Text(subtitle).font(.caption).foregroundStyle(KifuPalette.secondaryInk); Spacer() }.frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading).padding(14).background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16).stroke(KifuPalette.ink.opacity(0.1), lineWidth: 1)) }.buttonStyle(.plain) }
}

struct GameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State var settings: GameSettings
    let onStart: (GameSettings) -> Void
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(KifuCopy.current.text(.brandSubtitle))
                        .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                    PaperCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(KifuCopy.current.text(.board)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.gold)
                            settingDivider
                            Picker(KifuCopy.current.text(.size), selection: $settings.boardSize) {
                                ForEach(BoardSize.allCases, id: \.self) { Text("\($0.n) × \($0.n)").tag($0) }
                            }
                            Picker(KifuCopy.current.text(.rules), selection: $settings.ruleset) {
                                Text(KifuCopy.current.text(.chineseRules)).tag(Ruleset.chinese)
                                Text(KifuCopy.current.text(.japaneseRules)).tag(Ruleset.japanese)
                            }
                            Picker(KifuCopy.current.text(.color), selection: $settings.humanColor) {
                                Text(KifuCopy.current.text(.black)).tag(StoneColor.black)
                                Text(KifuCopy.current.text(.white)).tag(StoneColor.white)
                            }
                            Stepper("\(KifuCopy.current.text(.handicap)): \(settings.handicap)", value: $settings.handicap, in: 0...Handicap.maxStones(for: settings.boardSize))
                        }
                        .tint(KifuPalette.gold).foregroundStyle(KifuPalette.ink)
                    }
                    PaperCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(KifuCopy.current.text(.aiStrength)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.gold)
                            settingDivider
                            Picker(KifuCopy.current.text(.level), selection: $settings.difficulty) {
                                ForEach(1...5, id: \.self) { Text(KifuCopy.current.difficulty($0)).tag($0) }
                            }
                            Toggle(KifuCopy.current.text(.beginnerHelp), isOn: $settings.hints).tint(KifuPalette.jade)
                        }
                        .foregroundStyle(KifuPalette.ink)
                    }
                    SealButton(title: KifuCopy.current.text(.startGame), systemImage: "play.fill") { onStart(settings) }
                    Spacer(minLength: 24)
                }
                .padding(20)
            }
            .background(PaperBackground())
            .navigationTitle(KifuCopy.current.text(.newGame))
            .onChange(of: settings.boardSize) { _, size in
                settings.handicap = min(settings.handicap, Handicap.maxStones(for: size))
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(KifuCopy.current.text(.cancel)) { dismiss() } } }
        }
    }

    private var settingDivider: some View { Rectangle().fill(KifuPalette.gold.opacity(0.3)).frame(height: 1) }
}

struct GameScreen: View {
    @EnvironmentObject private var profile: KifuProfile
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: GameViewModel
    private let engineFactory: any GoEngineFactory
    @State private var showScoreReview = false
    @State private var showRecordReview = false
    @State private var confirmResign = false
    @State private var archiveID = UUID()
    let settings: GameSettings
    init(settings: GameSettings, initialRecord: GameRecord? = nil,
         engineFactory: any GoEngineFactory = KataGoEngineFactory()) {
        self.settings = settings
        self.engineFactory = engineFactory
        _model = StateObject(wrappedValue: GameViewModel(settings: settings, initialRecord: initialRecord,
                                                      engineFactory: engineFactory))
    }
    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .buttonStyle(.plain).accessibilityLabel(KifuCopy.current.text(.done))
                    VStack(alignment: .leading) {
                        Text(KifuCopy.current.text(.gameVsAI)).font(.headline)
                        Text("\(settings.boardSize.n)×\(settings.boardSize.n) · \(KifuCopy.current.rules(settings.ruleset))")
                            .font(.caption).foregroundStyle(KifuPalette.secondaryInk)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        if model.isThinking { ProgressView().scaleEffect(0.65).tint(KifuPalette.gold) }
                        Text(model.status).font(.caption.weight(.semibold)).lineLimit(2)
                    }
                    .foregroundStyle(model.isThinking ? KifuPalette.gold : KifuPalette.jade)
                }
                .foregroundStyle(KifuPalette.ink).padding(.horizontal, 16)
                if model.canRetryAI {
                    Button {
                        model.retryAI()
                    } label: {
                        Label(KifuCopy.current.text(.askAI), systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KifuPalette.jade)
                    .padding(.horizontal, 20)
                }
                HStack(spacing: 10) { PlayerCard(title: KifuCopy.current.text(.player), color: model.humanColor, active: !model.isThinking && !model.gameOver); PlayerCard(title: "Kifu AI", color: model.aiColor, active: model.isThinking) }.padding(.horizontal, 20)
                GobanView(board: model.board, coordinates: true, highlightLiberties: settings.hints && !model.awaitingScoreConfirmation,
                          suggestedPoint: model.aiSuggestion, lastMove: model.lastMove, markedDead: model.markedDead,
                          interactive: !model.isThinking && !model.gameOver) { point in
                    if model.awaitingScoreConfirmation { model.toggleDeadGroup(at: point) }
                    else { model.play(point) }
                }
                .padding(.horizontal, 16)
                if settings.boardSize == .nineteen && !model.gameOver && !model.awaitingScoreConfirmation {
                    Text(KifuCopy.current.text(.confirmPoint))
                        .font(.caption).foregroundStyle(KifuPalette.secondaryInk)
                        .padding(.horizontal, 20)
                }
                if model.awaitingScoreConfirmation {
                    SealButton(title: KifuCopy.current.text(.scoreReview)) { showScoreReview = true }
                        .padding(.horizontal, 20)
                } else {
                if model.aiPassedLastTurn {
                    Label(KifuCopy.current.text(.aiPassedFinish), systemImage: "flag")
                        .font(.footnote).foregroundStyle(KifuPalette.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                }
                HStack(spacing: 8) {
                    GameControl(icon: "lightbulb", title: KifuCopy.current.text(.hint), tint: KifuPalette.gold, enabled: !model.isThinking && !model.gameOver) { model.askHint() }
                    GameControl(icon: "arrow.uturn.backward", title: KifuCopy.current.text(.undo), tint: KifuPalette.secondaryInk, enabled: !model.moves.isEmpty && !model.gameOver) { model.undo() }
                    GameControl(icon: "flag", title: KifuCopy.current.text(.pass), tint: KifuPalette.secondaryInk, enabled: !model.isThinking && !model.gameOver) { model.pass() }
                    GameControl(icon: "xmark", title: KifuCopy.current.text(.resign), tint: KifuPalette.seal, enabled: !model.gameOver) { confirmResign = true }
                }.padding(.horizontal, 12)
                OutlineButton(title: KifuCopy.current.text(.gameMoves),
                              systemImage: "clock.arrow.circlepath") { showRecordReview = true }
                    .padding(.horizontal, 20)
                }
                if model.gameOver {
                    Text(model.result.map { KifuCopy.current.gameOutcome($0, humanColor: model.humanColor) } ?? KifuCopy.current.text(.gameFinished))
                        .font(.headline).foregroundStyle(KifuPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                }
                Spacer(minLength: 24)
            }
            .padding(.top, 8)
            }
        }
        .onAppear { [model, profile] in
            model.playerName = profile.nickname
            model.onFinished = { [weak model, weak profile] _ in
                if let model {
                    if let result = model.result {
                        switch result {
                        case .blackWinsByScore, .whiteWinsByScore, .draw:
                            let won = result.winnerIsBlack == (model.humanColor == .black)
                            profile?.recordCompletedGame(won: won, draw: result == .draw)
                        default: break
                        }
                    }
                    profile?.saveGame(id: archiveID, record: model.gameRecord, humanColor: model.humanColor)
                    UserDefaults.standard.set(model.exportedSGF, forKey: "lastGameSGF")
                }
            }
            model.begin()
        }
        .onChange(of: model.moves) { _, moves in
            if !moves.isEmpty {
                profile.saveGame(id: archiveID, record: model.gameRecord, humanColor: model.humanColor)
            }
        }
        .onDisappear {
            model.cancelPendingWork()
            if !model.moves.isEmpty {
                profile.saveGame(id: archiveID, record: model.gameRecord, humanColor: model.humanColor)
                UserDefaults.standard.set(model.exportedSGF, forKey: "lastGameSGF")
            }
        }
        .alert(KifuCopy.current.text(.resign), isPresented: $confirmResign) {
            Button(KifuCopy.current.text(.resign), role: .destructive) { model.resign() }
            Button(KifuCopy.current.text(.cancel), role: .cancel) { }
        }
        .onChange(of: model.awaitingScoreConfirmation) { _, isReady in
            if isReady { showScoreReview = true }
        }
        .sheet(isPresented: $showScoreReview) {
            ScoreReviewSheet(model: model, onConfirm: {
                model.confirmScore()
                showScoreReview = false
            })
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showRecordReview) { RecordReviewView(record: model.gameRecord) }
    }
}

private struct ScoreReviewSheet: View {
    @ObservedObject var model: GameViewModel
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(KifuCopy.current.text(.markDeadGroups))
                        .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                    GobanView(board: model.board, coordinates: true, markedDead: model.markedDead,
                              scoreReview: true, interactive: true) { point in
                        model.toggleDeadGroup(at: point)
                    }
                    HStack(spacing: 12) {
                        scoreTile(KifuCopy.current.text(.black), value: model.provisionalScore.blackTotal)
                        scoreTile(KifuCopy.current.text(.white), value: model.provisionalScore.whiteTotal)
                    }
                    SealButton(title: KifuCopy.current.text(.confirmScore), action: onConfirm)
                }
                .padding(20)
            }
            .background(PaperBackground())
            .navigationTitle(KifuCopy.current.text(.scoreReview))
        }
    }

    private func scoreTile(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(KifuPalette.secondaryInk)
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .font(.system(.title2, design: .serif, weight: .semibold))
                .monospacedDigit().foregroundStyle(KifuPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlayerCard: View {
    let title: String; let color: StoneColor; let active: Bool
    var body: some View { HStack(spacing: 8) { Circle().fill(color == .black ? KifuPalette.blackStoneMid : KifuPalette.whiteStoneMid).frame(width: 18, height: 18).overlay(Circle().stroke(KifuPalette.grid.opacity(0.4))); VStack(alignment: .leading) { Text(title).font(.caption.weight(.semibold)); Text(KifuCopy.current.color(color)).font(.caption2).foregroundStyle(KifuPalette.secondaryInk) }; Spacer() }.padding(10).background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? KifuPalette.jade : KifuPalette.gold.opacity(0.2), lineWidth: active ? 1.5 : 1)) }
}

struct GameControl: View {
    let icon: String; let title: String; let tint: Color; var enabled = true; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) { Image(systemName: icon).font(.headline); Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.75) }
                .foregroundStyle(tint).frame(maxWidth: .infinity, minHeight: 54)
                .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KifuPalette.gold.opacity(0.3)))
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain).disabled(!enabled).accessibilityLabel(title)
    }
}

struct LearnView: View {
    @EnvironmentObject private var profile: KifuProfile
    @State private var selected: Lesson?
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: KifuCopy.current.text(.learn), title: KifuCopy.current.text(.learnTitle))
                PaperCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            SealBadge(text: "L", color: KifuPalette.jade)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(KifuCopy.current.text(.beginnerPath)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                                Text(KifuCopy.current.text(.learnSubtitle)).font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                            }
                        }
                        OrnamentDivider()
                        BrushProgressBar(value: Double(profile.completedLessonIDs.count) / Double(max(1, lessons.count)))
                    }
                }
                .padding(.horizontal, 20)
                LazyVStack(spacing: 12) {
                    ForEach(lessons) { lesson in
                        let finished = profile.hasCompletedLesson(id: lesson.id)
                        Button { selected = lesson } label: {
                            PaperCard {
                                HStack(spacing: 14) {
                                    Image(systemName: lesson.icon).font(.title3)
                                        .foregroundStyle(finished ? KifuPalette.jade : KifuPalette.gold)
                                        .frame(width: 44, height: 44)
                                        .background(KifuPalette.sunken, in: RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(KifuCopy.current.chapter(lesson.id))
                                            .font(.caption2.weight(.semibold)).tracking(1.2).foregroundStyle(KifuPalette.gold)
                                        Text(KifuCopy.current.lessonTitle(lesson.id)).font(.headline).foregroundStyle(KifuPalette.ink)
                                        Text(KifuCopy.current.lessonDescription(lesson.id))
                                            .font(.caption).foregroundStyle(KifuPalette.secondaryInk).multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: finished ? "checkmark.seal.fill" : "chevron.right")
                                        .foregroundStyle(finished ? KifuPalette.jade : KifuPalette.tertiaryInk)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .sheet(item: $selected) { LessonDetail(lesson: $0) }
    }
}

struct LessonDetail: View {
    @EnvironmentObject private var profile: KifuProfile
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    @State private var board: Board
    @State private var completed = false
    @State private var triedWrongMove = false

    init(lesson: Lesson) {
        self.lesson = lesson
        _board = State(initialValue: LessonChallenge.forLesson(lesson.id).board)
    }

    private var challenge: LessonChallenge { .forLesson(lesson.id) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(KifuCopy.current.chapter(lesson.id))
                        .font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(KifuPalette.gold)
                    Text(KifuCopy.current.lessonTitle(lesson.id))
                        .font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                    Text(KifuCopy.current.lessonDescription(lesson.id))
                        .font(.body).foregroundStyle(KifuPalette.secondaryInk)
                    PaperCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(KifuCopy.current.text(.tryBoard), systemImage: "hand.tap")
                                .font(.headline).foregroundStyle(KifuPalette.ink)
                            Text(KifuCopy.current.lessonTask(lesson.id))
                                .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                            GobanView(board: board, coordinates: true, interactive: !completed) { point in
                                guard point == challenge.solution else { triedWrongMove = true; return }
                                if case .played = board.play(color: challenge.color, at: point) {
                                    completed = true
                                    triedWrongMove = false
                                    _ = profile.finishLesson(id: lesson.id)
                                }
                            }
                            if completed {
                                Label(KifuCopy.current.text(.solvedLesson), systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(KifuPalette.jade)
                            } else if triedWrongMove {
                                Label(KifuCopy.current.text(.puzzleHint), systemImage: "lightbulb")
                                    .foregroundStyle(KifuPalette.gold)
                            }
                        }
                    }
                    SealButton(title: completed ? KifuCopy.current.text(.done) : KifuCopy.current.text(.finishLater)) { dismiss() }
                }
                .padding(20)
            }
            .background(KifuPalette.paper)
            .navigationTitle(KifuCopy.current.text(.lessonTitle))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(KifuCopy.current.text(.done)) { dismiss() } } }
            .onAppear {
                completed = profile.hasCompletedLesson(id: lesson.id)
                if completed { _ = board.play(color: challenge.color, at: challenge.solution) }
            }
        }
    }
}

private struct LessonChallenge {
    let board: Board
    let color: StoneColor
    let solution: Point

    static func forLesson(_ id: Int) -> LessonChallenge {
        var board = Board(size: .nine)
        switch id {
        case 1:
            return LessonChallenge(board: board, color: .black, solution: Point(x: 4, y: 4))
        case 2:
            board.place(color: .black, at: Point(x: 4, y: 4))
            return LessonChallenge(board: board, color: .white, solution: Point(x: 3, y: 4))
        case 3:
            board.place(color: .white, at: Point(x: 1, y: 1))
            for point in [Point(x: 0, y: 1), Point(x: 2, y: 1), Point(x: 1, y: 0)] { board.place(color: .black, at: point) }
            return LessonChallenge(board: board, color: .black, solution: Point(x: 1, y: 2))
        case 4:
            for point in [Point(x: 2, y: 2), Point(x: 3, y: 2), Point(x: 4, y: 2), Point(x: 2, y: 3), Point(x: 4, y: 3), Point(x: 2, y: 4), Point(x: 4, y: 4)] { board.place(color: .black, at: point) }
            return LessonChallenge(board: board, color: .black, solution: Point(x: 3, y: 4))
        case 5:
            for x in 2...6 {
                board.place(color: .black, at: Point(x: x, y: 2))
                board.place(color: .black, at: Point(x: x, y: 4))
            }
            board.place(color: .black, at: Point(x: 2, y: 3))
            board.place(color: .black, at: Point(x: 6, y: 3))
            return LessonChallenge(board: board, color: .black, solution: Point(x: 4, y: 3))
        case 6:
            board.place(color: .black, at: Point(x: 2, y: 3))
            board.place(color: .black, at: Point(x: 4, y: 3))
            return LessonChallenge(board: board, color: .black, solution: Point(x: 3, y: 3))
        default:
            board.place(color: .white, at: Point(x: 4, y: 4))
            for point in [Point(x: 3, y: 4), Point(x: 5, y: 4), Point(x: 4, y: 3)] { board.place(color: .black, at: point) }
            return LessonChallenge(board: board, color: .black, solution: Point(x: 4, y: 5))
        }
    }
}

struct TsumegoView: View {
    @EnvironmentObject private var profile: KifuProfile
    @State private var puzzle: Puzzle
    @State private var board: Board
    @State private var solved = false
    @State private var isDaily = true
    @State private var message = KifuCopy.current.text(.puzzlePrompt)
    init() {
        let daily = Puzzle.daily()
        _puzzle = State(initialValue: daily)
        _board = State(initialValue: daily.board)
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: KifuCopy.current.text(.tsumego), title: isDaily ? KifuCopy.current.text(.dailyTitle) : KifuCopy.current.text(.tsumego))
                PaperCard {
                    HStack(spacing: 14) {
                        Image(systemName: "square.grid.3x3").font(.title2).foregroundStyle(KifuPalette.gold)
                            .frame(width: 44, height: 44).background(KifuPalette.sunken, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(KifuCopy.current.text(.captureGroup)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                            Text(KifuCopy.current.text(.blackToPlay)).font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                GobanView(board: board, coordinates: true, interactive: !solved) { point in
                    guard !solved else { return }
                    if point == puzzle.solution, case .played = board.play(color: .black, at: point) {
                        solved = true
                        message = KifuCopy.current.text(.puzzleExplanation)
                        if isDaily { _ = profile.solvePuzzle() }
                    } else {
                        message = KifuCopy.current.text(.puzzleHint)
                    }
                }
                .padding(.horizontal, 20)
                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(solved ? KifuCopy.current.text(.correct) : message, systemImage: solved ? "checkmark.seal" : "scope")
                            .font(.subheadline.weight(.medium)).foregroundStyle(solved ? KifuPalette.jade : KifuPalette.ink)
                        if solved {
                            Text(KifuCopy.current.text(.puzzleExplanation)).font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                            SealButton(title: KifuCopy.current.text(.nextPuzzle)) {
                                puzzle = Puzzle.next(after: puzzle)
                                board = puzzle.board
                                solved = false
                                isDaily = false
                                message = KifuCopy.current.text(.puzzlePrompt)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 24)
            }
            .padding(.bottom, 24)
        }
    }
}

struct AnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board: Board
    @State private var sourceRecord: GameRecord?
    private let originalRuleset: Ruleset
    private let originalKomi: Double
    private let onPlay: (GameRecord, StoneColor) -> Void
    private let engineFactory: any GoEngineFactory
    @State private var selectedColor: StoneColor
    @State private var candidates: [MoveCandidate] = []
    @State private var hasAnalysis = false
    @State private var thinking = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var showExporter = false
    @State private var document = SGFDocument(text: "")
    init(board: Board,
         record: GameRecord? = nil,
         onPlay: @escaping (GameRecord, StoneColor) -> Void = { _, _ in },
         engineFactory: any GoEngineFactory = KataGoEngineFactory()) {
        _board = State(initialValue: board)
        _sourceRecord = State(initialValue: record)
        _selectedColor = State(initialValue: record?.sideToPlay(after: record?.moves.count ?? 0) ?? .black)
        originalRuleset = record?.ruleset ?? .chinese
        originalKomi = record?.komi ?? Ruleset.chinese.defaultKomi
        self.onPlay = onPlay
        self.engineFactory = engineFactory
    }

    private var currentRecord: GameRecord {
        if var sourceRecord {
            if sourceRecord.sideToPlay(after: sourceRecord.moves.count) != selectedColor {
                sourceRecord.setupEdits.append(.init(afterMove: sourceRecord.moves.count,
                                                    nextToPlay: selectedColor))
            }
            return sourceRecord
        }
        return GameRecord.setupPosition(board, toPlay: selectedColor,
                                        ruleset: originalRuleset, komi: originalKomi)
    }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PaperCard {
                    HStack(spacing: 12) {
                        Image(systemName: "scope").font(.title2).foregroundStyle(KifuPalette.gold)
                            .frame(width: 44, height: 44).background(KifuPalette.sunken, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(KifuCopy.current.text(.analyzePosition)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                            Text(KifuCopy.current.text(.analysisPrompt)).font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                        }
                    }
                }
                .padding(.horizontal, 20)
                GobanView(board: board, coordinates: true, suggestedPoint: candidates.first?.point, interactive: true) { point in
                    if board.stone(at: point) == nil { board.place(color: selectedColor, at: point) } else { board.clear(at: point) }
                    sourceRecord = nil
                    candidates = []
                    hasAnalysis = false
                    analysisTask?.cancel()
                    thinking = false
                    requestID = UUID()
                }
                .padding(.horizontal, 16)
                if board.size == .nineteen {
                    Text(KifuCopy.current.text(.confirmPoint))
                        .font(.caption).foregroundStyle(KifuPalette.secondaryInk)
                        .padding(.horizontal, 20)
                }
                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(KifuCopy.current.text(.color)).font(.caption.weight(.semibold)).foregroundStyle(KifuPalette.gold)
                        Picker(KifuCopy.current.text(.color), selection: $selectedColor) {
                            Text(KifuCopy.current.text(.black)).tag(StoneColor.black)
                            Text(KifuCopy.current.text(.white)).tag(StoneColor.white)
                        }
                        .pickerStyle(.segmented)
                        Button { askAI() } label: {
                            HStack(spacing: 7) {
                                if thinking { ProgressView().tint(KifuPalette.ink) }
                                Text(thinking ? KifuCopy.current.text(.thinking) : KifuCopy.current.text(.askAI))
                            }
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .background(KifuPalette.seal, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain).disabled(thinking).opacity(thinking ? 0.7 : 1)
                        OutlineButton(title: KifuCopy.current.text(.continueFromHere),
                                      systemImage: "play.fill") {
                            onPlay(currentRecord, selectedColor)
                        }
                        OutlineButton(title: KifuCopy.current.text(.exportPosition),
                                      systemImage: "square.and.arrow.up") {
                            document = SGFDocument(text: GameRecordSGF.sgfString(for: currentRecord))
                            showExporter = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(KifuCopy.current.text(.candidates)).font(.system(.title3, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink); Spacer(); Label(KifuCopy.current.text(.offline), systemImage: "checkmark.shield").font(.caption).foregroundStyle(KifuPalette.jade) }
                        OrnamentDivider()
                        if candidates.isEmpty {
                            Text(KifuCopy.current.text(hasAnalysis ? .hintPass : .analysisPrompt))
                                .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                        } else {
                            ForEach(Array(candidates.enumerated()), id: \.offset) { index, item in
                                HStack {
                                    Text("\(index + 1)").font(.headline).foregroundStyle(KifuPalette.gold).frame(width: 22)
                                    Text(item.point?.humanCoordinate(on: board.size) ?? KifuCopy.current.text(.passMove)).font(.headline)
                                    Spacer(minLength: 8)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 24)
            }
            .padding(.top, 20)
            }
            .background(PaperBackground())
            .navigationTitle(KifuCopy.current.text(.analyzePosition))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(KifuCopy.current.text(.done)) { dismiss() } } }
            .onChange(of: selectedColor) { _, _ in
                analysisTask?.cancel()
                requestID = UUID()
                candidates = []
                hasAnalysis = false
                thinking = false
            }
            .onDisappear { analysisTask?.cancel() }
        }
        .fileExporter(isPresented: $showExporter, document: document,
                      contentType: .sgf, defaultFilename: "kifu-position") { _ in }
    }

    private func askAI() {
        analysisTask?.cancel()
        thinking = true
        let snapshot = board
        let color = selectedColor
        let id = UUID()
        requestID = id
        let context = EngineGameContext(record: currentRecord)
        var config = EngineConfig.level(5, boardSize: board.size, komi: context.komi)
        config.simulations = 50_000
        config.timeLimit = 30
        config.randomness = 0
        config.deterministicMoveSelection = true
        config.tacticalFocus = true
        config.maximizeWinProbability = true
        let request = EngineRequest(board: snapshot, colorToPlay: color, context: context, config: config)
        let engine = engineFactory.makeEngine()
        analysisTask = Task {
            do {
                let result = try await engine.search(request: request)
                guard !Task.isCancelled, requestID == id else { return }
                candidates = result.candidates
                hasAnalysis = true
                thinking = false
            } catch is CancellationError {
                return
            } catch {
                guard requestID == id else { return }
                candidates = []
                hasAnalysis = false
                thinking = false
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var profile: KifuProfile
    @State private var showLanguage = false
    @State private var showLicenses = false
    @State private var showEditName = false
    @State private var draftName = ""

    private var estimatedRank: String {
        let progress = max(0, profile.wins * 2 - profile.losses)
        return "\(max(1, 30 - progress / 3))k"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(eyebrow: KifuCopy.current.text(.profile), title: KifuCopy.current.text(.profileTitle), action: { showLanguage = true })

                Button {
                    draftName = profile.nickname
                    showEditName = true
                } label: {
                    PaperCard {
                        HStack(spacing: 16) {
                            SealBadge(text: "K", color: KifuPalette.gold)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(profile.nickname).font(.system(.title2, design: .serif, weight: .semibold)).foregroundStyle(KifuPalette.ink)
                                Text(KifuCopy.current.text(.beginnerPath)).font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "pencil.line").foregroundStyle(KifuPalette.gold)
                        }
                    }
                }
                .buttonStyle(.plain).padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    profileSectionTitle(KifuCopy.current.text(.botGameStats))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        StatTile(value: "\(profile.games)", label: KifuCopy.current.text(.completedGames))
                        StatTile(value: "\(profile.wins)", label: KifuCopy.current.text(.wins))
                        StatTile(value: "\(profile.losses)", label: KifuCopy.current.text(.losses))
                        StatTile(value: "\(profile.winRate)%", label: KifuCopy.current.text(.winRate))
                        StatTile(value: estimatedRank, label: KifuCopy.current.text(.rating))
                        StatTile(value: "\(profile.currentStreak)", label: KifuCopy.current.text(.dailyStreak), icon: "flame")
                    }
                    .padding(.horizontal, 20)
                }

                Button { showLanguage = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "globe").foregroundStyle(KifuPalette.gold).frame(width: 28)
                        Text(KifuCopy.current.text(.language)).foregroundStyle(KifuPalette.ink)
                        Spacer()
                        Text(profile.language.rawValue).foregroundStyle(KifuPalette.secondaryInk)
                        Image(systemName: "chevron.right").foregroundStyle(KifuPalette.tertiaryInk)
                    }
                    .padding(16)
                    .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(KifuPalette.gold.opacity(0.3)))
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                Button { showLicenses = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text").foregroundStyle(KifuPalette.gold).frame(width: 28)
                        Text(KifuCopy.current.text(.openSourceLicenses)).foregroundStyle(KifuPalette.ink)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(KifuPalette.tertiaryInk)
                    }
                    .padding(16)
                    .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(KifuPalette.gold.opacity(0.3)))
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                Spacer(minLength: 20)
            }
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showLanguage) {
            NavigationStack {
                List {
                    Picker(KifuCopy.current.text(.language), selection: $profile.language) {
                        ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
                .navigationTitle(KifuCopy.current.text(.languageTitle))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(KifuCopy.current.text(.done)) { showLanguage = false } } }
            }
        }
        .sheet(isPresented: $showLicenses) {
            NavigationStack {
                ScrollView {
                    Text((Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt")
                          .flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "")
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(20)
                }
                .navigationTitle(KifuCopy.current.text(.openSourceLicenses))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(KifuCopy.current.text(.done)) { showLicenses = false } } }
            }
        }
        .sheet(isPresented: $showEditName) {
            NavigationStack {
                Form { TextField(KifuCopy.current.text(.player), text: $draftName).textInputAutocapitalization(.words) }
                    .navigationTitle(KifuCopy.current.text(.profileTitle))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(KifuCopy.current.text(.cancel)) { showEditName = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(KifuCopy.current.text(.done)) {
                                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty { profile.nickname = String(trimmed.prefix(30)) }
                                showEditName = false
                            }
                        }
                    }
            }
        }
    }

    private func profileSectionTitle(_ text: String) -> some View {
        Text(text).font(.system(.title3, design: .serif, weight: .semibold))
            .foregroundStyle(KifuPalette.ink).padding(.horizontal, 20)
    }

}

struct StatTile: View {
    let value: String
    let label: String
    var icon: String? = nil
    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.caption).foregroundStyle(KifuPalette.gold) }
                Text(value).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
            }.foregroundStyle(KifuPalette.ink)
            Text(label).font(.caption2).foregroundStyle(KifuPalette.secondaryInk).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(KifuPalette.gold.opacity(0.32), lineWidth: 1))
    }
}
