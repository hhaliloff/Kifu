# Kifu

Приложение для игры в го на iPhone и iPad с iOS 17+: локальный AI, обучение и анализ позиций. Проект находится в разработке.

## Возможности

- Игра против KataGo на досках 9×9, 13×13 и 19×19, выбор цвета, форы и уровня поиска.
- Японские и китайские правила, подсказки, отмена хода, пас, сдача и подсчёт очков.
- Архив партий, пошаговый просмотр, импорт SGF с вариантами и экспорт выбранной линии.
- Редактор позиции и анализ ходов с помощью KataGo.
- Семь интерактивных уроков, три мини-задачи и локальная статистика прогресса.
- Русский, английский, корейский, японский и китайский интерфейс.

## Технологии

SwiftUI, Swift и пакет `GoCore` с правилами, подсчётом и поддержкой SGF. KataGo встроен через C/C++ GTP-мост и использует Metal/MPSGraph. Модель входит в приложение, поэтому игровой AI работает офлайн, без сервера и языковых моделей.

## Сборка

Нужны macOS, Xcode с iOS SDK, XcodeGen, CMake и Ninja. Из корня проекта:

```sh
brew install xcodegen cmake ninja
xcodegen generate
open Kifu.xcodeproj
```

Выберите симулятор или iPhone и запустите схему **Kifu**. Для устройства укажите свою Development Team в настройках подписи и в `project.yml` перед повторной генерацией. KataGo собирается автоматически скриптом `Scripts/build-katago-ios.sh`; первая сборка может занять несколько минут.

Проверка сборки без подписи и запуск тестов GoCore:

```sh
xcodebuild -project Kifu.xcodeproj -scheme Kifu \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
swift test --package-path Packages/GoCore
```

## Статус и документация

Полный AI-разбор партии и расширение учебных материалов ещё предстоят. `Training/ProblemCollection` содержит исходные позиции с неподтверждёнными решениями; они не подключены как проверенный набор задач.

Подробности: [обзор проекта](PROJECT_OVERVIEW.md), [дизайн-система](KifuDesignSystem.md), [лицензии сторонних компонентов](Sources/Kifu/Resources/ThirdPartyNotices.txt) и [модель KataGo](Resources/KataGo/NOTICE.md).
