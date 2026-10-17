import Foundation
import GoCore

enum KifuCopyKey: Hashable {
    case home, learn, tsumego, library, profile
    case greeting, greetingSubtitle, streak, today, minutes, brandSubtitle, homePrompt, playAI
    case continuePath, nextStep, lesson, liberties, dailyPuzzle, capture, tools, understandPosition, analyzePosition
    case board, size, rules, chineseRules, japaneseRules, color, black, white, handicap, aiStrength, level, beginnerHelp
    case firstSteps, beginner, intermediate, advanced, dan, newGame, startGame, cancel
    case gameVsAI, yourTurn, aiThinking, player, gameFinished, coachReady, review, hint, undo, pass, resign
    case coach, calmGame, keyMoments, moveGrowth, coachExplanation, retryPosition
    case learnTitle, beginnerPath, learnSubtitle, tryBoard, placeStone, placeStoneLiberty, watchPosition, solvedLesson, finishLater, lessonTitle
    case dailyTitle, blackToPlay, correct, nextPuzzle, puzzlePrompt, puzzleHint, dailyStreak
    case myGames, sgfDescription, importSGF, exportGame, analyzePositionShort, askAI, candidates, offline, analysisPrompt, thinking, done, passMove
    case profileTitle, learnerPath, games, completedGames, botGameStats, wins, losses, winRate, puzzles, lessons, rating, launches, achievements, language, languageTitle
    case chapter, chapterOne, chapterTwo, chapterThree, chapterFour, chapterFive
    case stonesAndBoard, stonesAndBoardDescription, libertiesDescription, captureAndKo, captureAndKoDescription, territory, territoryDescription, lifeAndDeath, lifeAndDeathDescription
    case cornerThreat, captureGroup, puzzleExplanation, illegalOccupied, illegalKo, illegalMove, boardPosition
    case playHint
    case importFailed
    case percentage
    case scoreReview, markDeadGroups, confirmScore, resumePlay, aiPassedFinish, hintPass, searchInterrupted
    case confirmPoint, deadGroupMarked, deadGroupUnmarked
    case savedGames, importedGames, emptyHistory, exportPosition, continueFromHere, deleteGame, moveNumber, archiveSaveFailed, gameMoves, createPosition
    case openSourceLicenses
}

struct KifuCopy {
    let language: AppLanguage

    static var current: KifuCopy {
        let raw = UserDefaults.standard.string(forKey: "language") ?? ""
        return KifuCopy(language: AppLanguage(rawValue: raw) ?? .russian)
    }

    func text(_ key: KifuCopyKey) -> String {
        if key == .openSourceLicenses {
            switch language {
            case .russian: return "Лицензии открытого кода"
            case .english: return "Open source licenses"
            case .korean: return "오픈 소스 라이선스"
            case .japanese: return "オープンソースライセンス"
            case .chinese: return "开源许可"
            }
        }
        if let index = [KifuCopyKey.botGameStats, .completedGames, .losses, .correct].firstIndex(of: key) {
            switch language {
            case .russian: return ["Партии с ботом", "до конца", "поражений", "Правильно!"][index]
            case .english: return ["Games against AI", "completed", "losses", "Correct!"][index]
            case .korean: return ["AI 대국", "완료", "패배", "정답!"][index]
            case .japanese: return ["AIとの対局", "終局", "敗北", "正解！"][index]
            case .chinese: return ["与 AI 对弈", "已完成", "败局", "正确！"][index]
            }
        }
        let archiveKeys: [KifuCopyKey] = [.savedGames, .importedGames, .emptyHistory,
                                           .exportPosition, .continueFromHere, .deleteGame,
                                           .moveNumber, .archiveSaveFailed, .gameMoves, .createPosition]
        if let index = archiveKeys.firstIndex(of: key) {
            switch language {
            case .russian: return ["История партий", "Импортированные партии", "Здесь появятся сыгранные партии",
                                   "Экспортировать SGF", "Играть с этой позиции", "Удалить партию",
                                   "Ход", "Не удалось сохранить историю партий", "Ходы партии", "Создать позицию"][index]
            case .english: return ["Game history", "Imported games", "Played games will appear here",
                                   "Export SGF", "Play from this position", "Delete game",
                                   "Move", "Could not save game history", "Game moves", "Create position"][index]
            case .korean: return ["대국 기록", "가져온 대국", "플레이한 대국이 여기에 표시됩니다",
                                  "SGF 내보내기", "이 국면에서 대국", "대국 삭제",
                                  "수", "대국 기록을 저장할 수 없습니다", "대국 수순", "포지션 만들기"][index]
            case .japanese: return ["対局履歴", "読み込んだ対局", "対局履歴がここに表示されます",
                                    "SGFを書き出す", "この局面から対局", "対局を削除",
                                    "手", "対局履歴を保存できませんでした", "棋譜", "局面を作成"][index]
            case .chinese: return ["对局历史", "导入的对局", "对局会显示在这里",
                                   "导出 SGF", "从此局面开始对局", "删除对局",
                                   "手", "无法保存对局历史", "对局棋谱", "创建局面"][index]
            }
        }
        if key == .wins { return textForWins() }
        if key == .launches { return textForVisits() }
        if let index = [KifuCopyKey.scoreReview, .markDeadGroups, .confirmScore, .resumePlay].firstIndex(of: key) {
            switch language {
            case .russian: return ["Проверка результата", "Коснись мёртвой группы, чтобы отметить или вернуть её.", "Подтвердить результат", "Продолжить партию"][index]
            case .english: return ["Review the score", "Tap a dead group to mark or restore it.", "Confirm score", "Resume game"][index]
            case .korean: return ["계가 확인", "죽은 그룹을 눌러 표시하거나 되돌리세요.", "계가 확정", "대국 계속"][index]
            case .japanese: return ["形勢を確認", "死んだ石のグループをタップして指定・解除します。", "結果を確定", "対局を続ける"][index]
            case .chinese: return ["确认胜负", "轻点死棋棋群以标记或恢复。", "确认结果", "继续对局"][index]
            }
        }
        if key == .boardPosition {
            switch language {
            case .russian: return "Позиция на доске"
            case .english: return "Board position"
            case .korean: return "바둑판 포지션"
            case .japanese: return "盤上の局面"
            case .chinese: return "棋盘局面"
            }
        }
        if key == .aiPassedFinish {
            switch language {
            case .russian: return "AI пропустил ход. Если борьба окончена, тоже пропусти — откроется подсчёт очков."
            case .english: return "AI passed. If play is settled, pass too to open scoring."
            case .korean: return "AI가 패스했습니다. 대국이 끝났다면 패스하여 계가를 시작하세요."
            case .japanese: return "AIがパスしました。終局なら、あなたもパスして地合いを確認しましょう。"
            case .chinese: return "AI 已停一手。若棋局结束，你也停一手即可开始计分。"
            }
        }
        if key == .hintPass {
            switch language {
            case .russian: return "Подсказка: пропусти ход"
            case .english: return "Hint: pass"
            case .korean: return "힌트: 패스"
            case .japanese: return "ヒント：パス"
            case .chinese: return "提示：停一手"
            }
        }
        if key == .searchInterrupted {
            switch language {
            case .russian: return "Анализ не завершён. Попробуй ещё раз."
            case .english: return "Analysis did not finish. Please try again."
            case .korean: return "분석이 완료되지 않았습니다. 다시 시도하세요."
            case .japanese: return "解析が完了しませんでした。もう一度お試しください。"
            case .chinese: return "分析未完成，请重试。"
            }
        }
        if key == .confirmPoint {
            switch language {
            case .russian: return "Выбери пункт и коснись его ещё раз для подтверждения хода."
            case .english: return "Select a point, then tap it again to confirm the move."
            case .korean: return "교차점을 선택한 뒤 다시 눌러 착수를 확정하세요."
            case .japanese: return "交点を選び、もう一度タップして着手を確定します。"
            case .chinese: return "选择交叉点后，再次轻点以确认落子。"
            }
        }
        if key == .deadGroupMarked || key == .deadGroupUnmarked {
            let index = key == .deadGroupMarked ? 0 : 1
            switch language {
            case .russian: return ["помечена как мёртвая", "не помечена как мёртвая"][index]
            case .english: return ["marked dead", "not marked dead"][index]
            case .korean: return ["죽은 돌로 표시됨", "죽은 돌로 표시되지 않음"][index]
            case .japanese: return ["死に石として指定済み", "死に石として未指定"][index]
            case .chinese: return ["已标记为死棋", "未标记为死棋"][index]
            }
        }
        return Self.table[language]?[key] ?? Self.table[.english]?[key] ?? ""
    }

    func greeting(_ name: String) -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch language {
        case .russian: return "\(hour < 12 ? "Доброе утро" : hour < 18 ? "Добрый день" : "Добрый вечер"), \(name)"
        case .english: return "\(hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"), \(name)"
        case .korean: return "\(hour < 12 ? "좋은 아침이에요" : hour < 18 ? "안녕하세요" : "좋은 저녁이에요"), \(name)"
        case .japanese: return "\(hour < 12 ? "おはようございます" : hour < 18 ? "こんにちは" : "こんばんは")、\(name)"
        case .chinese: return "\(hour < 12 ? "早上好" : hour < 18 ? "下午好" : "晚上好")，\(name)"
        }
    }

    func minutes(_ value: Int) -> String {
        switch language {
        case .russian: return "\(value) мин"
        case .english: return "\(value) min"
        case .korean: return "\(value)분"
        case .japanese: return "\(value)分"
        case .chinese: return "\(value) 分钟"
        }
    }

    func chapter(_ id: Int) -> String {
        if id > 5 {
            switch language {
            case .russian: return "Глава \(id)"
            case .english: return "Chapter \(id)"
            case .korean: return "챕터 \(id)"
            case .japanese: return "第\(id)章"
            case .chinese: return "第\(id)章"
            }
        }
        let key: KifuCopyKey = [.chapterOne, .chapterTwo, .chapterThree, .chapterFour, .chapterFive][max(0, min(4, id - 1))]
        return text(key)
    }

    func lessonTitle(_ id: Int) -> String {
        if id == 6 {
            switch language {
            case .russian: return "Группы камней"
            case .english: return "Stone groups"
            case .korean: return "돌의 연결"
            case .japanese: return "石のつながり"
            case .chinese: return "棋子连接"
            }
        }
        if id == 7 {
            switch language {
            case .russian: return "Базовая тактика"
            case .english: return "Basic tactics"
            case .korean: return "기본 전술"
            case .japanese: return "基本の手筋"
            case .chinese: return "基本战术"
            }
        }
        return text([.stonesAndBoard, .liberties, .captureAndKo, .territory, .lifeAndDeath][max(0, min(4, id - 1))])
    }

    func lessonDescription(_ id: Int) -> String {
        if id == 6 {
            switch language {
            case .russian: return "Соедини камни, чтобы они делили либерти."
            case .english: return "Connect stones so they share liberties."
            case .korean: return "돌을 이어 활로를 함께 쓰세요."
            case .japanese: return "石をつなぎ、呼吸点を共有しましょう。"
            case .chinese: return "连接棋子，共享气。"
            }
        }
        if id == 7 {
            switch language {
            case .russian: return "Замечай атари и выбирай ход захвата."
            case .english: return "Spot atari and choose a capturing move."
            case .korean: return "단수를 보고 잡는 수를 찾으세요."
            case .japanese: return "アタリを見つけ、取る手を選びましょう。"
            case .chinese: return "识别打吃，找到提子的手。"
            }
        }
        return text([.stonesAndBoardDescription, .libertiesDescription, .captureAndKoDescription, .territoryDescription, .lifeAndDeathDescription][max(0, min(4, id - 1))])
    }

    func lessonTask(_ id: Int) -> String {
        let index = max(0, min(6, id - 1))
        switch language {
        case .russian:
            return ["Поставь чёрный камень в центр доски.", "Займи соседний пункт и уменьши число либерти чёрного камня.", "Забери последнюю либерти белого камня.", "Замкни границу и получи пункт территории.", "Раздели внутреннее пространство на два глаза.", "Соедини два чёрных камня в одну группу.", "Найди ход, который захватит белый камень."][index]
        case .english:
            return ["Place a black stone in the centre.", "Play next to black to reduce its liberties.", "Take the white stone’s last liberty.", "Close the boundary to secure territory.", "Divide the enclosed space into two eyes.", "Connect the two black stones into one group.", "Find the move that captures the white stone."][index]
        case .korean:
            return ["바둑판 중앙에 흑돌을 놓으세요.", "흑돌 옆에 두어 활로를 줄이세요.", "백돌의 마지막 활로를 차지하세요.", "경계를 닫아 집을 만드세요.", "안쪽 공간을 두 눈으로 나누세요.", "두 흑돌을 한 그룹으로 연결하세요.", "백돌을 잡는 수를 찾으세요."][index]
        case .japanese:
            return ["盤の中央に黒石を置きましょう。", "黒石の隣に打ち、呼吸点を減らしましょう。", "白石の最後の呼吸点を取りましょう。", "境界を閉じて地を作りましょう。", "内部を二つの眼に分けましょう。", "二つの黒石を一つにつなぎましょう。", "白石を取る一手を見つけましょう。"][index]
        case .chinese:
            return ["在棋盘中央落一颗黑棋。", "在黑棋旁落子，减少它的气。", "占据白棋最后一口气。", "封住边界，形成一目地。", "把内部空间分成两只眼。", "把两颗黑棋连成一块。", "找到提掉白棋的一步。"][index]
        }
    }

    func difficulty(_ value: Int) -> String {
        let keys: [KifuCopyKey] = [.firstSteps, .beginner, .intermediate, .advanced, .dan]
        return text(keys[max(0, min(keys.count - 1, value - 1))])
    }

    func rules(_ ruleset: Ruleset) -> String {
        text(ruleset == .chinese ? .chineseRules : .japaneseRules)
    }

    func color(_ color: StoneColor) -> String {
        text(color == .black ? .black : .white)
    }

    func moveMistake(_ move: Int) -> String {
        switch language {
        case .russian: return "Ход \(move) — место для роста"
        case .english: return "Move \(move) — room to grow"
        case .korean: return "\(move)수 — 성장할 순간"
        case .japanese: return "\(move)手目 — 成長の一手"
        case .chinese: return "第\(move)手 — 进步的机会"
        }
    }

    func playedMove(_ coordinate: String) -> String {
        switch language {
        case .russian: return "Ты сыграл: \(coordinate)"
        case .english: return "You played: \(coordinate)"
        case .korean: return "둔 수: \(coordinate)"
        case .japanese: return "打った手: \(coordinate)"
        case .chinese: return "你的落点：\(coordinate)"
        }
    }

    func suggestedMove(_ coordinate: String) -> String {
        switch language {
        case .russian: return "Попробуй: \(coordinate)"
        case .english: return "Try instead: \(coordinate)"
        case .korean: return "대안: \(coordinate)"
        case .japanese: return "別の一手: \(coordinate)"
        case .chinese: return "试试这一步：\(coordinate)"
        }
    }

    func gameOutcome(_ result: GameResult, humanColor: StoneColor) -> String {
        let title: String
        if let winner = result.winnerIsBlack {
            let won = winner == (humanColor == .black)
            switch language {
            case .russian: title = won ? "Победа" : "Поражение"
            case .english: title = won ? "Victory" : "Defeat"
            case .korean: title = won ? "승리" : "패배"
            case .japanese: title = won ? "勝利" : "敗北"
            case .chinese: title = won ? "胜利" : "失利"
            }
        } else {
            switch language {
            case .russian: title = "Ничья"
            case .english: title = "Draw"
            case .korean: title = "무승부"
            case .japanese: title = "引き分け"
            case .chinese: title = "平局"
            }
        }
        let margin: Double?
        switch result {
        case .blackWinsByScore(let value), .whiteWinsByScore(let value): margin = value
        default: margin = nil
        }
        guard let margin else { return title }
        let localeID: String
        switch language {
        case .russian: localeID = "ru_RU"
        case .english: localeID = "en_US"
        case .korean: localeID = "ko_KR"
        case .japanese: localeID = "ja_JP"
        case .chinese: localeID = "zh_CN"
        }
        let value = margin.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: localeID)))
        return "\(title) · \(value)"
    }

    func textForVisits() -> String {
        switch language {
        case .russian: return "открытий"
        case .english: return "visits"
        case .korean: return "방문"
        case .japanese: return "起動"
        case .chinese: return "打开次数"
        }
    }

    func textForWins() -> String {
        switch language {
        case .russian: return "побед"
        case .english: return "wins"
        case .korean: return "승리"
        case .japanese: return "勝利"
        case .chinese: return "胜场"
        }
    }

    func winRate(_ value: Int) -> String {
        switch language {
        case .russian: return "\(value)% побед"
        case .english: return "\(value)% win rate"
        case .korean: return "승률 \(value)%"
        case .japanese: return "勝率 \(value)%"
        case .chinese: return "胜率 \(value)%"
        }
    }

    func streak(_ value: Int) -> String {
        switch language {
        case .russian: return "Серия \(value)"
        case .english: return "Streak \(value)"
        case .korean: return "연속 \(value)"
        case .japanese: return "連続 \(value)"
        case .chinese: return "连续 \(value)"
        }
    }

    func boardLabel(size: Int) -> String {
        switch language {
        case .russian: return "Доска го, \(size) на \(size)"
        case .english: return "Go board, \(size) by \(size)"
        case .korean: return "\(size) 곱하기 \(size) 바둑판"
        case .japanese: return "\(size)路盤"
        case .chinese: return "\(size)路棋盘"
        }
    }

    func boardHint(interactive: Bool) -> String {
        if interactive {
            switch language {
            case .russian: return "Дважды коснитесь пересечения, чтобы поставить камень"
            case .english: return "Double tap an intersection to play"
            case .korean: return "교차점을 두 번 눌러 돌을 놓으세요"
            case .japanese: return "交点をダブルタップして打ちます"
            case .chinese: return "轻点两次交叉点落子"
            }
        }
        return text(.boardPosition)
    }

    func importFailure(_ detail: String) -> String {
        switch language {
        case .russian: return "Не удалось открыть SGF: \(detail)"
        case .english: return "Could not open SGF: \(detail)"
        case .korean: return "SGF를 열 수 없습니다: \(detail)"
        case .japanese: return "SGFを開けません: \(detail)"
        case .chinese: return "无法打开 SGF：\(detail)"
        }
    }

    func importFailure(_ error: Error) -> String {
        if let sgf = error as? SGFError {
            switch sgf {
            case .unsupportedBoardSize:
                switch language {
                case .russian: return "Поддерживаются только доски 9×9, 13×13 и 19×19."
                case .english: return "Only 9×9, 13×13 and 19×19 boards are supported."
                case .korean: return "9×9, 13×13, 19×19 바둑판만 지원합니다."
                case .japanese: return "9×9、13×13、19×19の盤に対応しています。"
                case .chinese: return "仅支持 9×9、13×13 和 19×19 棋盘。"
                }
            case .unsupportedSetupEdit:
                switch language {
                case .russian: return "Этот SGF содержит изменения расстановки в середине партии; такой вариант пока не поддерживается."
                case .english: return "This SGF changes the setup mid-game; that format is not supported yet."
                case .korean: return "이 SGF는 대국 중 배치를 변경하므로 아직 지원되지 않습니다."
                case .japanese: return "このSGFには対局途中の配置変更があり、まだ対応していません。"
                case .chinese: return "此 SGF 在对局中更改了摆子，暂不支持。"
                }
            case .inputTooLarge, .tooManyNodes, .nestingTooDeep:
                switch language {
                case .russian: return "SGF слишком большой или сложный для безопасного открытия."
                case .english: return "This SGF is too large or complex to open safely."
                case .korean: return "이 SGF는 너무 크거나 복잡하여 안전하게 열 수 없습니다."
                case .japanese: return "このSGFは大きすぎるか複雑すぎるため、安全に開けません。"
                case .chinese: return "此 SGF 过大或过于复杂，无法安全打开。"
                }
            default: break
            }
        }
        switch language {
        case .russian: return "Не удалось открыть SGF. Проверь файл и попробуй снова."
        case .english: return "Could not open SGF. Check the file and try again."
        case .korean: return "SGF를 열 수 없습니다. 파일을 확인하고 다시 시도하세요."
        case .japanese: return "SGFを開けません。ファイルを確認してもう一度お試しください。"
        case .chinese: return "无法打开 SGF。请检查文件后重试。"
        }
    }

    var splashQuote: String {
        switch language {
        case .russian: return "Тихая партия каждый день — сильная игра со временем."
        case .english: return "A quiet game each day becomes stronger play over time."
        case .korean: return "매일의 차분한 대국이 시간이 지나 더 강한 바둑이 됩니다."
        case .japanese: return "毎日の静かな対局が、やがて強い一手になります。"
        case .chinese: return "每天沉静地下一局，时间会带来更强的棋力。"
        }
    }

    var splashCaption: String {
        switch language {
        case .russian: return "Учись · Играй · Расти"
        case .english: return "Learn · Play · Grow"
        case .korean: return "배우고 · 두고 · 성장하기"
        case .japanese: return "学ぶ · 打つ · 成長する"
        case .chinese: return "学习 · 对弈 · 成长"
        }
    }

    private static let table: [AppLanguage: [KifuCopyKey: String]] = [
        .russian: [
            .home: "Главная", .learn: "Учиться", .tsumego: "Задачи", .library: "Партии", .profile: "Профиль",
            .greetingSubtitle: "Тихий путь к сильной игре", .today: "Сегодня", .brandSubtitle: "Игра го · учись и тренируйся", .homePrompt: "Партия, урок или одна задача — выбери свой ритм.", .playAI: "Играть против AI",
            .continuePath: "Продолжить путь", .nextStep: "Твой следующий шаг", .lesson: "Урок", .liberties: "Либерти", .dailyPuzzle: "Задача дня", .capture: "Захват", .tools: "Инструменты", .understandPosition: "Глубже понять позицию", .analyzePosition: "Анализ позиции", .analyzePositionShort: "Позиция для анализа",
            .board: "Доска", .size: "Размер", .rules: "Правила", .chineseRules: "Китайские", .japaneseRules: "Японские", .color: "Цвет", .black: "Чёрные", .white: "Белые", .handicap: "Фора", .aiStrength: "Сила AI", .level: "Уровень", .beginnerHelp: "Помощь новичку", .firstSteps: "Первые шаги", .beginner: "Начинающий", .intermediate: "Средний", .advanced: "Продвинутый", .dan: "Дан", .newGame: "Новая партия", .startGame: "Начать партию", .cancel: "Отмена",
            .gameVsAI: "Партия против AI", .yourTurn: "Ваш ход", .aiThinking: "AI думает…", .player: "Игрок", .gameFinished: "Партия завершена", .coachReady: "AI‑тренер разберёт ключевые моменты", .review: "Разбор", .hint: "Подсказка", .undo: "Отмена", .pass: "Пас", .resign: "Сдаться", .coach: "AI‑тренер", .calmGame: "Спокойная партия", .keyMoments: "Ключевые моменты", .moveGrowth: "Попробуй сохранить больше либерти у своей группы.", .coachExplanation: "Живые группы дают тебе время для атаки.", .retryPosition: "Попробовать позицию заново",
            .learnTitle: "Научиться играть", .beginnerPath: "Путь новичка", .learnSubtitle: "Понимать доску — значит видеть возможности", .tryBoard: "Попробуй на доске", .placeStone: "Поставь камень и наблюдай, как меняется позиция.", .placeStoneLiberty: "Поставь белый камень рядом, чтобы увидеть его либерти.", .watchPosition: "Наблюдай за изменением позиции.", .solvedLesson: "Отлично — мини-задача решена", .finishLater: "Завершить позже", .lessonTitle: "Урок",
            .dailyTitle: "Задача дня", .blackToPlay: "Ход чёрных", .correct: "Правильно! +1 к серии", .nextPuzzle: "Следующая задача", .puzzlePrompt: "Найди единственный ход, который спасает ситуацию.", .puzzleHint: "Не спеши: сначала посмотри на последнюю либерти группы.", .dailyStreak: "Серия",
            .myGames: "Мои партии", .sgfDescription: "Импортируй чужую партию или экспортируй свою для разбора.", .importSGF: "Импорт SGF", .exportGame: "Экспорт", .askAI: "Спросить AI", .candidates: "Кандидаты AI", .offline: "офлайн", .analysisPrompt: "Расставь камни как хочешь и спроси AI о лучшем продолжении.", .thinking: "Думаю…", .done: "Готово", .passMove: "Пас",
            .profileTitle: "Профиль", .learnerPath: "путь ученика", .games: "партий", .wins: "побед", .winRate: "доля побед", .puzzles: "задач", .lessons: "уроков", .rating: "рейтинг", .launches: "открытий", .achievements: "Достижения", .language: "Язык", .languageTitle: "Выбрать язык",
            .chapter: "Глава", .chapterOne: "Глава 1", .chapterTwo: "Глава 2", .chapterThree: "Глава 3", .chapterFour: "Глава 4", .chapterFive: "Глава 5", .stonesAndBoard: "Камни и доска", .stonesAndBoardDescription: "Поставь первый камень и почувствуй ритм го.", .libertiesDescription: "У каждого камня есть дыхание — его соседние пустые пункты.", .captureAndKo: "Захват и ко", .captureAndKoDescription: "Окружай группы и не возвращай позицию мгновенно.", .territory: "Территория", .territoryDescription: "Учись видеть пространство, которое контролируют группы.", .lifeAndDeath: "Жизнь и смерть", .lifeAndDeathDescription: "Две глаза — спокойствие для твоей группы.", .cornerThreat: "Угол под угрозой", .captureGroup: "Захват группы", .puzzleExplanation: "У белой группы осталась одна либерти. Забери её сейчас.", .illegalOccupied: "Здесь уже стоит камень", .illegalKo: "Этот ход запрещён правилом ко", .illegalMove: "Ход нарушает правила"
        ],
        .english: [
            .home: "Home", .learn: "Learn", .tsumego: "Puzzles", .library: "Games", .profile: "Profile", .greetingSubtitle: "A quiet path to stronger play", .today: "Today", .brandSubtitle: "Go board · learn and train", .homePrompt: "A game, a lesson, or one puzzle — choose your rhythm.", .playAI: "Play against AI", .continuePath: "Continue path", .nextStep: "Your next step", .lesson: "Lesson", .liberties: "Liberties", .dailyPuzzle: "Daily puzzle", .capture: "Capture", .tools: "Tools", .understandPosition: "Understand the position", .analyzePosition: "Position analysis", .analyzePositionShort: "Position to analyze", .board: "Board", .size: "Size", .rules: "Rules", .chineseRules: "Chinese", .japaneseRules: "Japanese", .color: "Color", .black: "Black", .white: "White", .handicap: "Handicap", .aiStrength: "AI strength", .level: "Level", .beginnerHelp: "Beginner help", .firstSteps: "First steps", .beginner: "Beginner", .intermediate: "Intermediate", .advanced: "Advanced", .dan: "Dan", .newGame: "New game", .startGame: "Start game", .cancel: "Cancel", .gameVsAI: "Game vs AI", .yourTurn: "Your turn", .aiThinking: "AI is thinking…", .player: "Player", .gameFinished: "Game finished", .coachReady: "AI coach will review key moments", .review: "Review", .hint: "Hint", .undo: "Undo", .pass: "Pass", .resign: "Resign", .coach: "AI coach", .calmGame: "A calm game", .keyMoments: "Key moments", .moveGrowth: "Try to keep more liberties for your group.", .coachExplanation: "Living groups give you time to attack.", .retryPosition: "Try position again", .learnTitle: "Learn to play", .beginnerPath: "Beginner path", .learnSubtitle: "Understanding the board means seeing possibilities", .tryBoard: "Try it on the board", .placeStone: "Place a stone and watch the position change.", .placeStoneLiberty: "Place a white stone nearby to see its liberties.", .watchPosition: "Watch the position change.", .solvedLesson: "Great — mini puzzle solved", .finishLater: "Finish later", .lessonTitle: "Lesson", .dailyTitle: "Daily puzzle", .blackToPlay: "Black to play", .correct: "Correct! +1 streak", .nextPuzzle: "Next puzzle", .puzzlePrompt: "Find the only move that saves the position.", .puzzleHint: "Take your time: look at the group's last liberty.", .dailyStreak: "Streak", .myGames: "My games", .sgfDescription: "Import a game or export yours for review.", .importSGF: "Import SGF", .exportGame: "Export", .askAI: "Ask AI", .candidates: "AI candidates", .offline: "offline", .analysisPrompt: "Place stones as you like and ask AI for the best continuation.", .thinking: "Thinking…", .done: "Done", .passMove: "Pass", .profileTitle: "Profile", .learnerPath: "12k · learner path", .games: "games", .winRate: "win rate", .puzzles: "puzzles", .lessons: "lessons", .rating: "rating", .achievements: "Achievements", .language: "Language", .languageTitle: "Choose language", .chapter: "Chapter", .chapterOne: "Chapter 1", .chapterTwo: "Chapter 2", .chapterThree: "Chapter 3", .chapterFour: "Chapter 4", .chapterFive: "Chapter 5", .stonesAndBoard: "Stones and board", .stonesAndBoardDescription: "Place your first stone and feel the rhythm of Go.", .libertiesDescription: "Every stone breathes through its neighboring empty points.", .captureAndKo: "Capture and ko", .captureAndKoDescription: "Surround groups without taking the position back at once.", .territory: "Territory", .territoryDescription: "Learn to see the space controlled by groups.", .lifeAndDeath: "Life and death", .lifeAndDeathDescription: "Two eyes bring calm to your group.", .cornerThreat: "Corner under threat", .captureGroup: "Capture the group", .puzzleExplanation: "The white group has one liberty left. Take it now.", .illegalOccupied: "A stone is already here", .illegalKo: "This move is forbidden by ko", .illegalMove: "Illegal move"
        ],
        .korean: [
            .home: "홈", .learn: "배우기", .tsumego: "문제", .library: "대국", .profile: "프로필", .greetingSubtitle: "더 강한 바둑으로 가는 조용한 길", .today: "오늘", .brandSubtitle: "바둑판 · 배우고 훈련하기", .homePrompt: "대국, 레슨 또는 한 문제 — 나만의 리듬을 선택하세요.", .playAI: "AI와 대국", .continuePath: "학습 이어가기", .nextStep: "다음 단계", .lesson: "레슨", .liberties: "활로", .dailyPuzzle: "오늘의 문제", .capture: "잡기", .tools: "도구", .understandPosition: "포지션 깊이 보기", .analyzePosition: "포지션 분석", .analyzePositionShort: "분석할 포지션", .board: "바둑판", .size: "크기", .rules: "규칙", .chineseRules: "중국식", .japaneseRules: "일본식", .color: "색", .black: "흑", .white: "백", .handicap: "접바둑", .aiStrength: "AI 실력", .level: "레벨", .beginnerHelp: "초보자 도움", .firstSteps: "첫걸음", .beginner: "초급", .intermediate: "중급", .advanced: "고급", .dan: "단", .newGame: "새 대국", .startGame: "대국 시작", .cancel: "취소", .gameVsAI: "AI 대국", .yourTurn: "당신의 차례", .aiThinking: "AI가 생각 중…", .player: "플레이어", .gameFinished: "대국 종료", .coachReady: "AI 코치가 핵심 장면을 분석합니다", .review: "복기", .hint: "힌트", .undo: "되돌리기", .pass: "패스", .resign: "기권", .coach: "AI 코치", .calmGame: "차분한 대국", .keyMoments: "핵심 장면", .moveGrowth: "그룹의 활로를 더 많이 지켜 보세요.", .coachExplanation: "살아 있는 그룹은 공격할 시간을 줍니다.", .retryPosition: "포지션 다시 풀기", .learnTitle: "바둑 배우기", .beginnerPath: "초보자 과정", .learnSubtitle: "바둑판을 이해하면 가능성이 보입니다", .tryBoard: "바둑판에서 연습", .placeStone: "돌을 놓고 포지션의 변화를 관찰하세요.", .placeStoneLiberty: "백돌을 옆에 놓아 활로를 확인하세요.", .watchPosition: "포지션의 변화를 관찰하세요.", .solvedLesson: "좋아요 — 미니 문제가 풀렸습니다", .finishLater: "나중에 완료", .lessonTitle: "레슨", .dailyTitle: "오늘의 문제", .blackToPlay: "흑선", .correct: "정답! 연속 +1", .nextPuzzle: "다음 문제", .puzzlePrompt: "상황을 구할 유일한 수를 찾으세요.", .puzzleHint: "서두르지 말고 그룹의 마지막 활로를 보세요.", .dailyStreak: "연속", .myGames: "내 대국", .sgfDescription: "대국을 가져오거나 내 대국을 내보내 복기하세요.", .importSGF: "SGF 가져오기", .exportGame: "내보내기", .askAI: "AI에게 묻기", .candidates: "AI 후보 수", .offline: "오프라인", .analysisPrompt: "돌을 자유롭게 놓고 최고의 다음 수를 AI에게 물어보세요.", .thinking: "생각 중…", .done: "완료", .passMove: "패스", .profileTitle: "프로필", .learnerPath: "12k · 학습 과정", .games: "대국", .winRate: "승률", .puzzles: "문제", .lessons: "레슨", .rating: "레이팅", .achievements: "업적", .language: "언어", .languageTitle: "언어 선택", .chapter: "챕터", .chapterOne: "챕터 1", .chapterTwo: "챕터 2", .chapterThree: "챕터 3", .chapterFour: "챕터 4", .chapterFive: "챕터 5", .stonesAndBoard: "돌과 바둑판", .stonesAndBoardDescription: "첫 돌을 놓고 바둑의 리듬을 느껴 보세요.", .libertiesDescription: "모든 돌은 주변의 빈 교차점으로 숨을 쉽니다.", .captureAndKo: "잡기와 패", .captureAndKoDescription: "그룹을 포위하고 같은 모양을 즉시 되돌리지 마세요.", .territory: "집", .territoryDescription: "그룹이 지배하는 공간을 보는 법을 배우세요.", .lifeAndDeath: "사활", .lifeAndDeathDescription: "두 눈은 그룹에 평온을 줍니다.", .cornerThreat: "위험한 귀", .captureGroup: "그룹 잡기", .puzzleExplanation: "백 그룹의 활로가 하나 남았습니다. 지금 잡으세요.", .illegalOccupied: "이미 돌이 있습니다", .illegalKo: "패 규칙상 둘 수 없습니다", .illegalMove: "둘 수 없는 수입니다"
        ],
        .japanese: [
            .home: "ホーム", .learn: "学ぶ", .tsumego: "詰碁", .library: "棋譜", .profile: "プロフィール", .greetingSubtitle: "強くなるための静かな道", .today: "今日", .brandSubtitle: "囲碁 · 学びとトレーニング", .homePrompt: "対局、レッスン、詰碁 — 自分のリズムで選びましょう。", .playAI: "AIと対局", .continuePath: "学習を続ける", .nextStep: "次のステップ", .lesson: "レッスン", .liberties: "呼吸点", .dailyPuzzle: "今日の詰碁", .capture: "取り", .tools: "ツール", .understandPosition: "局面を深く見る", .analyzePosition: "局面解析", .analyzePositionShort: "解析する局面", .board: "盤", .size: "サイズ", .rules: "ルール", .chineseRules: "中国ルール", .japaneseRules: "日本ルール", .color: "色", .black: "黒", .white: "白", .handicap: "置き石", .aiStrength: "AIの強さ", .level: "レベル", .beginnerHelp: "初心者サポート", .firstSteps: "はじめの一歩", .beginner: "初級", .intermediate: "中級", .advanced: "上級", .dan: "段", .newGame: "新しい対局", .startGame: "対局開始", .cancel: "キャンセル", .gameVsAI: "AIとの対局", .yourTurn: "あなたの手番", .aiThinking: "AIが思考中…", .player: "プレイヤー", .gameFinished: "対局終了", .coachReady: "AIコーチが要点を振り返ります", .review: "振り返る", .hint: "ヒント", .undo: "戻す", .pass: "パス", .resign: "投了", .coach: "AIコーチ", .calmGame: "落ち着いた対局", .keyMoments: "重要な場面", .moveGrowth: "自分のグループの呼吸点をもっと守りましょう。", .coachExplanation: "生きたグループは攻める時間を作ります。", .retryPosition: "局面をもう一度", .learnTitle: "囲碁を学ぶ", .beginnerPath: "初心者の道", .learnSubtitle: "盤を理解すると可能性が見えてきます", .tryBoard: "盤で試す", .placeStone: "石を置いて局面の変化を見ましょう。", .placeStoneLiberty: "白石を隣に置いて呼吸点を見ましょう。", .watchPosition: "局面の変化を見ましょう。", .solvedLesson: "すばらしい — ミニ問題を解決しました", .finishLater: "後で完了", .lessonTitle: "レッスン", .dailyTitle: "今日の詰碁", .blackToPlay: "黒番", .correct: "正解！連続 +1", .nextPuzzle: "次の問題", .puzzlePrompt: "局面を救う唯一の手を探しましょう。", .puzzleHint: "急がずに、グループの最後の呼吸点を見てください。", .dailyStreak: "連続", .myGames: "棋譜", .sgfDescription: "棋譜を読み込み、自分の対局を出力して振り返りましょう。", .importSGF: "SGFを読み込む", .exportGame: "出力", .askAI: "AIに聞く", .candidates: "AI候補手", .offline: "オフライン", .analysisPrompt: "自由に石を置き、最善の続き方をAIに聞きましょう。", .thinking: "思考中…", .done: "完了", .passMove: "パス", .profileTitle: "プロフィール", .learnerPath: "12級 · 学びの道", .games: "対局", .winRate: "勝率", .puzzles: "詰碁", .lessons: "レッスン", .rating: "レーティング", .achievements: "実績", .language: "言語", .languageTitle: "言語を選ぶ", .chapter: "章", .chapterOne: "第1章", .chapterTwo: "第2章", .chapterThree: "第3章", .chapterFour: "第4章", .chapterFive: "第5章", .stonesAndBoard: "石と盤", .stonesAndBoardDescription: "最初の石を置いて囲碁のリズムを感じましょう。", .libertiesDescription: "石には隣接する空点という呼吸点があります。", .captureAndKo: "取りとコウ", .captureAndKoDescription: "グループを囲み、同じ形をすぐに取り返さないようにします。", .territory: "地", .territoryDescription: "グループが支配する空間を見ましょう。", .lifeAndDeath: "生き死に", .lifeAndDeathDescription: "二眼はグループに安心を与えます。", .cornerThreat: "隅の危機", .captureGroup: "グループを取る", .puzzleExplanation: "白のグループには呼吸点が一つ残っています。今取りましょう。", .illegalOccupied: "そこにはすでに石があります", .illegalKo: "コウのルールで打てません", .illegalMove: "ルール違反の手です"
        ],
        .chinese: [
            .home: "首页", .learn: "学习", .tsumego: "死活题", .library: "棋谱", .profile: "个人资料", .greetingSubtitle: "通往更强棋力的安静之路", .today: "今天", .brandSubtitle: "围棋 · 学习与训练", .homePrompt: "对局、课程或一道题 — 选择你的节奏。", .playAI: "与 AI 对弈", .continuePath: "继续学习", .nextStep: "下一步", .lesson: "课程", .liberties: "气", .dailyPuzzle: "今日题目", .capture: "提子", .tools: "工具", .understandPosition: "深入理解棋局", .analyzePosition: "局面分析", .analyzePositionShort: "待分析局面", .board: "棋盘", .size: "大小", .rules: "规则", .chineseRules: "中国规则", .japaneseRules: "日本规则", .color: "颜色", .black: "黑棋", .white: "白棋", .handicap: "让子", .aiStrength: "AI 强度", .level: "等级", .beginnerHelp: "新手帮助", .firstSteps: "起步", .beginner: "入门", .intermediate: "中级", .advanced: "高级", .dan: "段位", .newGame: "新对局", .startGame: "开始对局", .cancel: "取消", .gameVsAI: "与 AI 对局", .yourTurn: "轮到你了", .aiThinking: "AI 思考中…", .player: "玩家", .gameFinished: "对局结束", .coachReady: "AI 教练会复盘关键时刻", .review: "复盘", .hint: "提示", .undo: "撤回", .pass: "停着", .resign: "认输", .coach: "AI 教练", .calmGame: "沉着的一局", .keyMoments: "关键时刻", .moveGrowth: "试着为你的棋群保留更多气。", .coachExplanation: "活棋会给你进攻的时间。", .retryPosition: "重新尝试局面", .learnTitle: "学习围棋", .beginnerPath: "新手之路", .learnSubtitle: "理解棋盘，才能看见可能性", .tryBoard: "在棋盘上试试", .placeStone: "落下一子，观察局面的变化。", .placeStoneLiberty: "在旁边放一颗白棋，看看它的气。", .watchPosition: "观察局面的变化。", .solvedLesson: "很好 — 小练习完成", .finishLater: "稍后完成", .lessonTitle: "课程", .dailyTitle: "今日题目", .blackToPlay: "黑先", .correct: "正确！连胜 +1", .nextPuzzle: "下一题", .puzzlePrompt: "找到挽救局面的唯一一步。", .puzzleHint: "不要着急，先看看棋群最后一口气。", .dailyStreak: "连胜", .myGames: "我的棋谱", .sgfDescription: "导入棋谱，或导出自己的对局来复盘。", .importSGF: "导入 SGF", .exportGame: "导出", .askAI: "询问 AI", .candidates: "AI 候选着", .offline: "离线", .analysisPrompt: "自由摆放棋子，然后询问 AI 最佳续着。", .thinking: "思考中…", .done: "完成", .passMove: "停着", .profileTitle: "个人资料", .learnerPath: "12级 · 学习之路", .games: "对局", .winRate: "胜率", .puzzles: "题目", .lessons: "课程", .rating: "等级分", .achievements: "成就", .language: "语言", .languageTitle: "选择语言", .chapter: "第", .chapterOne: "第一章", .chapterTwo: "第二章", .chapterThree: "第三章", .chapterFour: "第四章", .chapterFive: "第五章", .stonesAndBoard: "棋子与棋盘", .stonesAndBoardDescription: "落下第一颗棋子，感受围棋的节奏。", .libertiesDescription: "每颗棋子都通过相邻空点呼吸。", .captureAndKo: "提子与劫", .captureAndKoDescription: "包围棋群，不要立刻还原同一局面。", .territory: "领地", .territoryDescription: "学会看见棋群控制的空间。", .lifeAndDeath: "死活", .lifeAndDeathDescription: "两眼让棋群获得安定。", .cornerThreat: "角上有危险", .captureGroup: "吃掉棋群", .puzzleExplanation: "白棋群只剩一口气。现在提掉它。", .illegalOccupied: "这里已经有棋子", .illegalKo: "劫规则禁止这一手", .illegalMove: "这一步不符合规则"
        ]
    ]
}
