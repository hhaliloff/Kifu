import SwiftUI
import UniformTypeIdentifiers
import GoCore

private struct ReviewItem: Identifiable {
    let id = UUID()
    let record: GameRecord
}

private enum ReviewAction {
    case analyze(GameRecord)
    case play(GameRecord, StoneColor)
}

struct LibraryView: View {
    @EnvironmentObject private var profile: KifuProfile
    @State private var showImporter = false
    @State private var importError: String?
    @State private var importedRecords: [GameRecord] = []
    @State private var reviewItem: ReviewItem?
    @State private var pendingReviewAction: ReviewAction?
    @State private var importWorker: Task<[GameRecord], Error>?
    @State private var importRequestID = UUID()
    @State private var pendingDelete: UUID?

    let onCreatePosition: () -> Void
    let onAnalyze: (GameRecord) -> Void
    let onPlay: (GameRecord, StoneColor) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: KifuCopy.current.text(.library),
                             title: KifuCopy.current.text(.myGames))
                SealButton(title: KifuCopy.current.text(.createPosition), systemImage: "square.grid.3x3") {
                    onCreatePosition()
                }
                .padding(.horizontal, 20)
                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SGF").font(.system(.title3, design: .serif, weight: .semibold))
                        Text(KifuCopy.current.text(.sgfDescription))
                            .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                        OutlineButton(title: KifuCopy.current.text(.importSGF),
                                      systemImage: "square.and.arrow.down") { showImporter = true }
                    }
                }.padding(.horizontal, 20)

                if let importError {
                    Label(importError, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(KifuPalette.warn).padding(.horizontal, 20)
                }
                if profile.archiveError != nil {
                    Label(KifuCopy.current.text(.archiveSaveFailed), systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(KifuPalette.warn).padding(.horizontal, 20)
                }

                if !importedRecords.isEmpty {
                    Text(KifuCopy.current.text(.importedGames))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .padding(.horizontal, 20)
                    ForEach(importedRecords.indices, id: \.self) { index in
                        recordRow(importedRecords[index], subtitle: "SGF · \(index + 1)") {
                            reviewItem = ReviewItem(record: importedRecords[index])
                        }
                    }
                }

                Text(KifuCopy.current.text(.savedGames))
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .padding(.horizontal, 20)
                if profile.savedGames.isEmpty {
                    PaperCard {
                        Text(KifuCopy.current.text(.emptyHistory))
                            .font(.subheadline).foregroundStyle(KifuPalette.secondaryInk)
                    }.padding(.horizontal, 20)
                } else {
                    ForEach(profile.savedGames) { game in
                        recordRow(game.record,
                                  subtitle: game.savedAt.formatted(date: .abbreviated, time: .shortened),
                                  onDelete: { pendingDelete = game.id }) {
                            reviewItem = ReviewItem(record: game.record)
                        }
                        .contextMenu {
                            Button(KifuCopy.current.text(.deleteGame), role: .destructive) {
                                pendingDelete = game.id
                            }
                        }
                    }
                }
                Spacer(minLength: 24)
            }
            .padding(.bottom, 24)
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.sgf, .data, .plainText]) { handleImport($0) }
        .alert(KifuCopy.current.text(.deleteGame),
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } })) {
            Button(KifuCopy.current.text(.deleteGame), role: .destructive) {
                if let pendingDelete { profile.deleteGame(id: pendingDelete) }
                pendingDelete = nil
            }
            Button(KifuCopy.current.text(.cancel), role: .cancel) { pendingDelete = nil }
        }
        .sheet(item: $reviewItem, onDismiss: {
            guard let action = pendingReviewAction else { return }
            pendingReviewAction = nil
            switch action {
            case .analyze(let record): onAnalyze(record)
            case .play(let record, let color): onPlay(record, color)
            }
        }) { item in
            RecordReviewView(record: item.record, onAnalyze: { record in
                pendingReviewAction = .analyze(record)
                reviewItem = nil
            }, onPlay: { record, color in
                pendingReviewAction = .play(record, color)
                reviewItem = nil
            })
        }
        .onDisappear { importWorker?.cancel() }
    }

    private func recordRow(_ record: GameRecord, subtitle: String,
                           onDelete: (() -> Void)? = nil,
                           action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: action) {
                PaperCard {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3")
                            .font(.title3).foregroundStyle(KifuPalette.gold)
                            .frame(width: 44, height: 44)
                            .background(KifuPalette.sunken, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.gameName ?? "\(record.boardSize.n)×\(record.boardSize.n) · \(KifuCopy.current.text(.moveNumber)) \(record.moves.count)")
                                .font(.headline).foregroundStyle(KifuPalette.ink)
                            Text(subtitle).font(.caption).foregroundStyle(KifuPalette.secondaryInk)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").foregroundStyle(KifuPalette.gold)
                    }
                }
            }
            .buttonStyle(.plain)
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundStyle(KifuPalette.seal)
                        .frame(width: 48, height: 52)
                        .background(KifuPalette.elevated, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KifuCopy.current.text(.deleteGame))
            }
        }
        .padding(.horizontal, 20)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let request = UUID()
            importRequestID = request
            importError = nil
            importWorker?.cancel()
            let worker = Task.detached(priority: .userInitiated) { () throws -> [GameRecord] in
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   size > 5_000_000 { throw CocoaError(.fileReadTooLarge) }
                guard let stream = InputStream(url: url) else { throw CocoaError(.fileReadNoSuchFile) }
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 32_768)
                while true {
                    try Task.checkCancellation()
                    let count = buffer.withUnsafeMutableBufferPointer {
                        stream.read($0.baseAddress!, maxLength: $0.count)
                    }
                    if count < 0 { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
                    if count == 0 { break }
                    guard data.count + count <= 5_000_000 else { throw CocoaError(.fileReadTooLarge) }
                    data.append(contentsOf: buffer.prefix(count))
                }
                let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .shiftJIS)
                    ?? String(data: data, encoding: .windowsCP1252)
                    ?? String(data: data, encoding: .isoLatin1)
                guard let text else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                return try GameRecordSGF.parseAll(text)
            }
            importWorker = worker
            Task {
                do {
                    let records = try await worker.value
                    guard importRequestID == request else { return }
                    importWorker = nil
                    importedRecords = records
                    profile.importGames(records)
                    reviewItem = records.first.map(ReviewItem.init(record:))
                } catch {
                    guard importRequestID == request else { return }
                    importWorker = nil
                    if !(error is CancellationError) {
                        importError = KifuCopy.current.importFailure(error)
                    }
                }
            }
        } catch {
            importError = KifuCopy.current.importFailure(error)
        }
    }
}

struct RecordReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let record: GameRecord
    let onAnalyze: ((GameRecord) -> Void)?
    let onPlay: ((GameRecord, StoneColor) -> Void)?
    @State private var moveIndex: Int
    @State private var humanColor: StoneColor
    @State private var showExporter = false
    @State private var document = SGFDocument(text: "")

    init(record: GameRecord, onAnalyze: ((GameRecord) -> Void)? = nil,
         onPlay: ((GameRecord, StoneColor) -> Void)? = nil) {
        self.record = record
        self.onAnalyze = onAnalyze
        self.onPlay = onPlay
        _moveIndex = State(initialValue: record.moves.count)
        _humanColor = State(initialValue: record.sideToPlay(after: record.moves.count))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    GobanView(board: record.position(after: moveIndex), coordinates: true,
                              lastMove: moveIndex > 0 ? record.moves[moveIndex - 1].point : nil)
                        .padding(.horizontal, 16)
                    PaperCard {
                        VStack(spacing: 12) {
                            Text("\(KifuCopy.current.text(.moveNumber)) \(moveIndex) / \(record.moves.count)")
                                .font(.headline.monospacedDigit())
                            Slider(value: Binding(get: { Double(moveIndex) },
                                                  set: { moveIndex = Int($0) }),
                                   in: 0...Double(max(1, record.moves.count)), step: 1)
                                .disabled(record.moves.isEmpty)
                                .accessibilityLabel(KifuCopy.current.text(.moveNumber))
                            HStack {
                                Button { moveIndex = max(0, moveIndex - 1) } label: {
                                    Image(systemName: "chevron.left").frame(width: 48, height: 44)
                                }.disabled(moveIndex == 0)
                                Spacer()
                                Button { moveIndex = min(record.moves.count, moveIndex + 1) } label: {
                                    Image(systemName: "chevron.right").frame(width: 48, height: 44)
                                }.disabled(moveIndex == record.moves.count)
                            }
                        }
                    }.padding(.horizontal, 20)
                    PaperCard {
                        VStack(spacing: 12) {
                            if onPlay != nil {
                                Picker(KifuCopy.current.text(.color), selection: $humanColor) {
                                    Text(KifuCopy.current.text(.black)).tag(StoneColor.black)
                                    Text(KifuCopy.current.text(.white)).tag(StoneColor.white)
                                }.pickerStyle(.segmented)
                            }
                            if let onAnalyze {
                                OutlineButton(title: KifuCopy.current.text(.analyzePositionShort),
                                              systemImage: "scope") { onAnalyze(record.prefix(moveIndex)) }
                            }
                            if let onPlay {
                                OutlineButton(title: KifuCopy.current.text(.continueFromHere),
                                              systemImage: "play.fill") {
                                    onPlay(record.prefix(moveIndex), humanColor)
                                }
                            }
                            OutlineButton(title: KifuCopy.current.text(.exportPosition),
                                          systemImage: "square.and.arrow.up") {
                                document = SGFDocument(text: GameRecordSGF.sgfString(for: record.prefix(moveIndex)))
                                showExporter = true
                            }
                        }
                    }.padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(PaperBackground())
            .navigationTitle(record.gameName ?? KifuCopy.current.text(.myGames))
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(KifuCopy.current.text(.done)) { dismiss() }
            } }
            .onChange(of: moveIndex) { _, index in
                humanColor = record.sideToPlay(after: index)
            }
        }
        .fileExporter(isPresented: $showExporter, document: document,
                      contentType: .sgf, defaultFilename: "kifu-move-\(moveIndex)") { _ in }
    }
}
