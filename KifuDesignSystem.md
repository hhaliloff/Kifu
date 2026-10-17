# Kifu — Go & Baduk: Design System Specification

**Version:** 1.0 · **Platform:** iOS 17+ · **Framework:** SwiftUI · **Themes:** Paper (light, primary) / Ink Night (dark)
**Localization:** RU · EN · KO · JA · ZH

---

## 0. Design Philosophy

**"A quiet tea house, not a casino."**

Kifu should feel like unrolling a handscroll in a wood-and-paper room: calm, crafted, premium. Three principles govern every decision:

1. **Calm (静)** — Muted, desaturated palette. Generous whitespace. One accent at a time. No neon, no gradients-for-their-own-sake, no gratuitous confetti.
2. **Craft (匠)** — Materials are honest: xuan paper, pine-soot ink, katsura wood, cinnabar seal paste, jade, gold leaf. Texture is *subtle and procedural*, never a heavy bitmap.
3. **Clarity (明)** — The board is sacred. Ornament never competes with position legibility. Beginner guidance is warm, not noisy.

**Motif library** (use sparingly, one motif per surface):

| Motif | Usage |
|---|---|
| Seal stamp (印章) | Logo, achievements, "Black to play" chips, win/loss result, primary buttons |
| Brush stroke (笔触) | Progress bars, underlines, dividers, banners |
| Ensō circle (円相) | Loading spinner, correct-answer feedback |
| Handscroll (卷轴) | Home menu cards, lesson sheets, modals |
| Bamboo (竹) | Dividers, slider thumb track nodes, empty-state illustration |
| Ink wash (水墨) | Hero backgrounds, header washes, heatmaps |

---

## 1. Color System

### 1.1 Tokens — Paper theme (light, default)

| Token | Hex | Role |
|---|---|---|
| `paper.base` | `#F6F0E4` | App background (xuan paper) |
| `paper.elevated` | `#FBF7EE` | Cards, sheets, tab bar |
| `paper.sunken` | `#EFE7D4` | Input wells, pressed card, track backgrounds |
| `ink.primary` | `#211B14` | Primary text, grid lines, brush strokes |
| `ink.secondary` | `#5C5344` | Secondary text, captions, coordinates |
| `ink.tertiary` | `#8A7F6B` | Placeholders, disabled, locked seals |
| `hairline` | `#211B14` @ 12% | Card borders, separators |
| `seal.red` | `#C13A2E` | **Primary accent** — cinnabar. Buttons, seals, last-move marker, selected states |
| `seal.redPressed` | `#A02D23` | Pressed state |
| `seal.onRed` | `#FBF7EE` | Text/glyphs on cinnabar (contrast ≈ 6.8:1) |
| `jade` | `#3E7D5C` | Secondary accent — success, liberty hints, toggles, active-turn ring |
| `jade.pressed` | `#2F6046` | Pressed |
| `jade.wash` | `#3E7D5C` @ 12% | Liberty/valid-move fills |
| `gold` | `#B08A3C` | Antique gold — ratings, best-move arrows, chart dots, premium badges |
| `azurite` | `#3F5E8C` | Mineral blue (石青) — info, AI hints, links |
| `azurite.pressed` | `#2F476B` | Pressed |
| `warn` | `#C0872A` | Warnings (time trouble, atari notice) |
| `error` | `#C13A2E` | Errors share the cinnabar hue family — **always pair with an icon**, never color alone |

**Semantic mapping:** success = `jade`, error = `seal.red` + `exclamationmark` icon, warning = `warn` amber, hint/info = `azurite`.

### 1.2 Tokens — Ink Night theme (dark)

| Token | Hex | Role |
|---|---|---|
| `night.base` | `#12100D` | App background (lamp-black ink) |
| `night.elevated` | `#1C1915` | Cards, sheets, tab bar |
| `night.sunken` | `#0C0B09` | Wells, tracks |
| `paper.onNight` | `#EDE5D3` | Primary text |
| `paper.onNight2` | `#A79B85` | Secondary text |
| `paper.onNight3` | `#756B5A` | Tertiary |
| `hairline.night` | `#EDE5D3` @ 12% | Borders |
| `seal.red.night` | `#E26755` | Brightened cinnabar; pair with `#12100D` bold text (≥ 4.5:1) |
| `seal.red.nightPressed` | `#C04E3D` | Pressed |
| `jade.night` | `#5FA37E` | Success / accents |
| `gold.night` | `#D4AE60` | Gold |
| `azurite.night` | `#7C9CC9` | Info / hints |
| `warn.night` | `#D9A44C` | Warning |
| `error.night` | `#E26755` | Error + icon |

**Stones, board wood, and seal red on physical objects do not change with theme** — a slate stone is slate under any lamp. Only shadows strengthen in dark mode (see §3).

### 1.3 Board & stone palette (both themes)

| Token | Hex | Notes |
|---|---|---|
| `wood.light` | `#EFCB8B` | Katsura wood gradient — top stop |
| `wood.mid` | `#E0B26A` | Middle stop |
| `wood.deep` | `#C89652` | Bottom stop / edge vignette |
| `wood.gridInk` | `#3A2A18` | Grid lines & hoshi — warm brown-black, softer than pure black on wood |
| `stone.b.hi` | `#5A5753` | Black slate radial gradient — highlight stop (top-left offset) |
| `stone.b.mid` | `#232120` | Middle stop |
| `stone.b.edge` | `#0D0C0B` | Rim stop |
| `stone.w.hi` | `#FFFFFF` | Shell gradient — highlight |
| `stone.w.mid` | `#F4EFE3` | Middle — warm, never blue-gray |
| `stone.w.edge` | `#D9D2BE` | Rim |
| `shadow.ink` | `#1A120A` | Shadow base color (multiply) |

### 1.4 Contrast requirements

- All body text ≥ 4.5:1; large display text ≥ 3:1. Verified pairs: `ink.primary`/`paper.base` ≈ 14:1; `seal.onRed`/`seal.red` ≈ 6.8:1; `jade`/`paper.base` ≈ 5:1; `azurite`/`paper.base` ≈ 6.5:1; `#12100D` on `seal.red.night` ≈ 4.6:1.
- iOS **Increase Contrast** setting: darken `wood.gridInk` to `#241A0E`, bump grid line weight +0.5pt, raise hairline alpha 12% → 25%.

### 1.5 Procedural texture guidance (zero bitmap assets)

All textures are generated at runtime; keep opacity low enough that screenshots barely show them but their absence is felt.

| Texture | Implementation | Parameters |
|---|---|---|
| **Paper grain** | `Canvas` drawing ~1,800 seeded random 1×1.5pt specks + a few 6–10pt fibers in `ink.primary`, tiled once over full screen; or a 256px `CIFilter.randomGenerator` image cropped & softened | Opacity 3–4%, blend `.multiply`, **fixed seed** so grain never shimmers between frames |
| **Paper vignette** | `RadialGradient` centered, `paper.base` → `ink.primary` @ 6% at corners | Static, behind all content |
| **Ink wash hero** | 2–3 overlapping `RadialGradient` blobs (`ink.primary` @ 6–8%) + `.blur(radius: 30)` | Home header, empty states only |
| **Wood** | `LinearGradient` (`wood.light` → `wood.mid` 45% → `wood.deep`) at 100°, plus 5–7 long wavy grain strokes (`wood.deep` @ 5%, 1pt, slight curves via `Canvas`), plus radial edge vignette @ 8% | Grain strokes run along board's long axis |
| **Brush stroke** | `Capsule` with asymmetric taper: leading radius full, trailing radius 40%, plus a 1pt lighter streak along top edge @ 20% | Progress bars, underlines |
| **Seal texture** | Two concentric rounded rects, outer stroke 2pt offset 0.5pt up-left; glyph with 0.5pt inner shadow | Suggests carved stone chop |

SF Symbols cover all iconography (see §9 inventory); the only bundled asset is the CJK calligraphy font (§2).

---

## 2. Typography

### 2.1 Font strategy by script

The app is localized RU/EN/KO/JA/ZH. **Calligraphy is a display-only layer**; UI body text is always the system font for legibility and Dynamic Type.

| Layer | ZH | JA | KO | Latin (EN/RU) |
|---|---|---|---|---|
| **Display / seals / chapter titles** | **Ma Shan Zheng** (Google Fonts, OFL — App Store safe, bundle the single Regular weight) → fallback chain `Kaiti SC` (system, 楷体, ships with iOS) → `Songti SC` | `Hiragino Mincho ProN` (system serif) — do **not** force Ma Shan Zheng on kana; it covers CJK ideographs only | System serif via `.system(.serif)` | `.system design: .serif` (New York) — warm, editorial, zero assets |
| **UI body / labels / numbers** | SF Pro (system) | SF Pro + system JA fallback | SF Pro + system KO fallback | SF Pro |

**Rules:**
- Apply the calligraphy face by *script detection*, not by app locale — a Russian user studying Chinese terms should still see 詰棋 rendered in the calligraphy face. Practical approach: use the display font for any string containing CJK Unified Ideographs, serif for pure Latin/Cyrillic.
- Cyrillic (RU) never uses the calligraphy font; New York serif carries the classic feel for RU.
- If the bundled font fails to load at runtime, fall back to `Kaiti SC` silently — never crash, never swap to a cartoonish face.

### 2.2 Type scale (iOS points, Dynamic Type mapped)

| Style | Size/Weight | Face | Dynamic Type | Usage |
|---|---|---|---|---|
| Display Seal | 44 / regular | Calligraphy/serif | `.largeTitle` (allow up to 60) | Home seal, result seal 胜/负, empty states |
| Large Title | 34 / regular | Serif | `.largeTitle` | Screen titles |
| Title 1 | 28 / regular | Serif | `.title` | Section heroes |
| Title 2 | 22 / regular | Serif | `.title2` | Card headers, sheet titles |
| Title 3 | 20 / semibold | Serif | `.title3` | List section headers |
| Headline | 17 / semibold | SF | `.headline` | Button labels, emphasized rows |
| Body | 17 / regular | SF | `.body` | Reading text; line spacing ×1.35 for CJK paragraphs |
| Callout | 16 / regular | SF | `.callout` | Secondary rows |
| Subheadline | 15 / regular | SF | `.subheadline` | Card subtitles |
| Footnote | 13 / regular | SF | `.footnote` | Meta info, timestamps |
| Caption | 12 / medium | SF | `.caption` | Tab labels, chips |
| Board coords | 10 / regular, tracking +1 | Serif | fixed (exempt) | A–T / 1–19 coordinates |
| Counters/clock | 17 / semibold + **tabular figures** | SF | `.headline` | Captures, timers, score |
| Stone move numbers | 9 / semibold tabular | SF | fixed | Review mode overlay on stones |

**Numerals:** all timers, scores, and capture counts use monospaced digits so values don't jitter. Decorative Chinese numerals (一二三四五) may appear in non-interactive ornaments only.

**Localization notes:**
- CJK text: never force line breaks mid-word; allow natural per-character wrapping; increase line spacing to ×1.35.
- German-length Russian strings: buttons must fit "Начать партию" — allow 2-line button labels at 15pt minimum before truncating.
- Rank terms are locale-specific: kyu/dan labels localized (级/段, 級/段, 급/단).

---

## 3. The Goban (Board Design)

The board is the product's soul. It must look like a real katsura goban photographed in soft window light.

### 3.1 Geometry

- Square board, centered horizontally. Width = screen width − 2 × screen margin (20pt; 16pt on iPhone SE → 343pt board). Max width 420pt on Pro Max / iPad — beyond that, add tea-house margin, don't stretch the board.
- `cell = (boardWidth − 2 × gridMargin) / (size − 1)` where `gridMargin = 0.9 × cell` (coordinates hidden) or `1.4 × cell` (coordinates shown).
- Coordinates: letters A–T skipping **I** across top/bottom, numbers bottom-up on both sides, 10pt serif, `ink.secondary`.

### 3.2 Wood & grid

| Element | Spec |
|---|---|
| Wood fill | Per §1.5: 3-stop linear gradient + Canvas grain + 8% edge vignette |
| Frame | Optional thin frame: 6pt dark walnut `#4A3524` band, corner radius 14pt, inner shadow (top/left `shadow.ink` @ 18% 2pt) so board sits *into* the frame |
| Board drop shadow | y 8 / blur 24 / `shadow.ink` @ 25% (light), black @ 50% (dark) — board floats like a lacquered object |
| Grid lines | `wood.gridInk`, full opacity. Weight: 19×19 → **1.0pt**, 13×13 → 1.1pt, 9×9 → 1.25pt. **Edge lines +0.3pt** bolder (real gobans have heavier rims) |
| Hoshi | Radius = cell ÷ 7 (≈2.4pt on 19×19), `wood.gridInk`. Positions standard: 19×19 → rows/cols 4-10-16; 13×13 → (4,4)(4,10)(7,7)(10,4)(10,10); 9×9 → (3,3)(3,7)(5,5)(7,3)(7,7). Tengen may be rendered 15% larger as a quiet accent |

### 3.3 Stones

| Property | Black (slate) | White (shell) |
|---|---|---|
| Diameter | 0.94 × cell (slight overlap like real stones) | same |
| Fill | Radial gradient `stone.b.hi` → `stone.b.mid` (55%) → `stone.b.edge`, center offset (−0.35, −0.35) of radius — light from top-left | `stone.w.hi` → `stone.w.mid` (55%) → `stone.w.edge`, same offset |
| Specular | Optional 2pt white dot @ 55% at (−0.3, −0.35), blur 1 — slate is matte; keep subtle | Skip (shell reads glossy via gradient alone) |
| Shadow | y 1.5 / blur 2 / black 45% — lifts stone off wood. No shadow on ghost stones | same |
| Shell banding | — | Optional: one 6% warm arc `stone.w.edge` across lower third (clamshell grain); 9×9/13×13 only where stones are large enough |

### 3.4 Game-state rendering

| State | Spec |
|---|---|
| **Ghost stone** | Stone at 45% opacity + 1pt `ink.primary` ring; no shadow. Appears on touch-down, follows finger |
| **Touch targeting** | Crosshair: two 1pt `wood.gridInk` lines @ 50% extending one cell beyond the ghost in each axis. Optional precision **loupe** (magnified 3×3 region above finger) as a setting; "two-tap confirm" mode available in Settings for 19×19 on small phones |
| **Last move** | Signature marker: **7×7pt cinnabar square rotated 45°, radius 1.5pt** — a tiny seal chip. On black stones use `seal.red`; on white stones use `seal.redPressed` for contrast. (Dot alternative in accessibility settings) |
| **Move numbers** (review/analysis) | 9pt tabular; white text on black stones, `ink.primary` on white stones; center-aligned |
| **Liberty highlighting** (beginner mode) | Selected group's liberties: 0.18×cell circles, `jade.wash` fill + 1pt `jade` @ 40% ring. Atari: last liberty pulses (§6) with `warn` color |
| **Territory (scoring)** | Rounded squares, side 0.42×cell, radius 2pt: black territory = `ink.primary` @ 60%; white territory = `paper.elevated` @ 85% + 1pt `ink.primary` @ 30% ring. **Dead stones dim to 45% opacity** and lose their shadow. Never encode territory by color alone for color-blind users: black territory squares are solid, white are hollow |
| **AI heatmap** (analysis) | Per-intersection radial blobs, ramp `gold` → `seal.red` by winrate weight, `.multiply` blend @ 55%, clipped to board |
| **Best-move overlays** | AI best: `gold` curved arrow (2.5pt, arrowhead 8pt) + `jade` ring. Played mistake: `seal.red` ring. Top-3 candidates: labeled dots A/B/C with winrate captions |
| **Ko marker** | Small 0.3×cell triangle outline, `ink.primary` @ 70% |

---

## 4. Component Library

Spacing system: 4pt base grid — tokens `4, 8, 12, 16, 20, 24, 32`. Screen margin 20pt (16pt ≤375pt width). Card padding 16pt. Section gap 24pt.
Corner radius scale: chips 8 · buttons 12 · cards 16 · sheets 20 · board frame 14.

### 4.1 Buttons

**Primary — "Seal Button"**
- Height 50pt, radius 12pt, horizontal padding 24pt. Fill `seal.red`, label 17 semibold `seal.onRed`.
- Shadow: y 3 / blur 8 / `seal.red` @ 25%.
- Pressed: fill `seal.redPressed` + scale 0.97 (0.12s ease-out).
- Optional ornament: 2pt `seal.onRed` @ 40% inset stroke offset −1pt (carved-chop feel) on hero CTAs only (e.g., "Start Game").
- Disabled: fill `paper.sunken`, label `ink.tertiary`, no shadow.
- Loading: label replaced by ensō spinner (§4.6) in `seal.onRed`.
- Small variant: height 36, radius 10, 15 semibold ("Try again", "Rematch").

**Secondary — "Ink Outline"**
- Same metrics. Fill `paper.elevated`, 1.25pt border `ink.primary` @ 80%, label `ink.primary` 17 semibold.
- Pressed: fill `ink.primary` @ 8%.

**Tertiary — "Brush text"**
- Text only, `azurite` 17 medium, with 2pt brush underline on press. Used for "Skip", "Reveal", "Not now".

**Destructive** — Ink Outline metrics, border + label `seal.red` (e.g., Resign). Always confirm via paper sheet (§4.4) for irreversible actions.

### 4.2 Icon buttons (game controls)

- 44×44pt circle, `paper.elevated` fill, 1pt hairline border, SF Symbol 17pt `ink.primary`, 10pt caption label beneath (localized).
- Pressed: scale 0.94 + `paper.sunken` fill.
- Destructive (Resign): symbol `seal.red`.
- Disabled: 30% opacity.
- Hint button: `lightbulb` symbol tinted `azurite`; badge dot (`seal.red` 8pt) when a hint is available.

### 4.3 Cards — "Paper Card"

- Fill `paper.elevated`, radius 16, 1pt hairline border, shadow y 6 / blur 16 / `shadow.ink` @ 12% (dark: y 4 / blur 12 / black 45%).
- Pressed (when tappable): scale 0.98, shadow tightens to y 2 / blur 8.
- Menu cards (Home) add a left ink-calligraphy monogram (弈学诘析谱人, 34pt calligraphy face, `ink.primary` @ 90%).

### 4.4 Sheets — "Scroll Sheet"

- All modals use `.sheet` with detents; background `paper.base` + paper grain + top ink-wash.
- Grabber: custom 40×4pt rounded bar `ink.tertiary` — flanked by two 8pt bamboo-node dots as ornament.
- Header: Title 2 serif, left; small 20pt seal square accent (`seal.red`, white carved character) right of title for ceremonial screens (game result, achievement).

### 4.5 Navigation

**Recommendation: custom bottom tab bar** (5 tabs) over a side drawer — thumb-reachable, always-visible destinations, and Go apps benefit from persistent Home/Tsumego access. A side menu hides streak/tabs engagement.

- Height: 49pt + safe area. Background `paper.elevated` + top hairline + shadow y −2 / blur 8 / `shadow.ink` @ 6%.
- Tabs: **Home** `house` · **Learn** `text.book.closed` · **Tsumego** `puzzlepiece.extension` · **Library** `books.vertical` · **Profile** `person.crop.circle`.
- Selected: symbol + 10pt label in `seal.red`, plus 24×2.5pt **brush-stroke underline** (tapered capsule). Unselected: `ink.tertiary`.
- Tab switch: crossfade 0.2s; board/game screens keep state.
- iPad/landscape alternative: left sidebar rail (72pt) with same glyphs, vertical seal logo at top.

**Navigation bars:** large-title serif headers on scroll screens; trailing seal avatar (Profile shortcut). Back button: ink chevron + previous title; in game, replaced by `‹` + "对局" chip.

### 4.6 Progress & loading

**Brush progress bar**
- Track: 8pt capsule, `ink.primary` @ 8%.
- Fill: `ink.primary` → `ink.primary` @ 80% linear gradient, tapered tail (trailing radius 40%), 1pt lighter streak along top @ 20%.
- Percent label: caption tabular, `ink.secondary`.
- Lesson/course progress may tint fill `jade`.

**Ensō spinner (loading)**
- Circle stroke trimmed to 70%, 3pt, `ink.primary`, tapered ends; rotates 1.1s linear. Center optional calligraphy dot. Use for AI-thinking with caption "AI が考えています / 思考中…" localized.
- AI thinking additionally shows breathing ghost-stone pulse at candidate point.

**Skeletons:** paper cards with shimmer — diagonal `paper.base` → `paper.elevated` gradient sweep 1.4s.

### 4.7 Badges, streaks, achievements

**Seal badge (achievement)**
- 48pt circle, `seal.red` fill, double-ring edge (§1.5 seal texture), centered glyph: SF Symbol 20pt or single calligraphy character, `seal.onRed`, 0.5pt inner shadow (carved look).
- Locked: fill `#9B937F` (stone gray), glyph `ink.tertiary`, no ring.
- Unlock animation: §6.

**Streak flame**
- `flame.fill` masked with vertical `gold` → `seal.red` gradient + count in serif Title 3. Resting state: subtle 2s breathing scale 1.0–1.04. At 0 streak, flame becomes outline-only `ink.tertiary`.

**Difficulty selector (rank chips)**
- Horizontal chip row, radius 8, selected = `seal.red` fill + `seal.onRed` text; unselected = ink outline.
- Each chip: Chinese name in calligraphy + localized subtitle. Mapping (verify all translations with native reviewers before release):

| Chip | Pinyin | EN gloss | Strength |
|---|---|---|---|
| 入门 | rùmén | First Steps | 25–21k |
| 初级 | chūjí | Beginner | 20–15k |
| 中级 | zhōngjí | Intermediate | 14–8k |
| 高级 | gāojí | Advanced | 7–3k |
| 段位 | duànwèi | Dan level | 2k–1d |
| 棋圣 | qíshèng | Master | 2d+ |

### 4.8 Form controls

- **Stone slider** (difficulty/komi/handicap): brush-stroke track (§4.6) with **white shell stone thumb** (28pt, §3.3 rendering), haptic tick per step.
- **Toggle**: system switch, `jade` tint.
- **Segmented** (rules CN/JP, color choice): capsule container `paper.sunken`, selected pill `paper.elevated` + hairline + 2pt `seal.red` brush underline.
- **Text fields**: `paper.sunken` fill, radius 10, 1pt hairline, focus = 1.5pt `azurite` ring; label above in footnote `ink.secondary`.

### 4.9 Banners & feedback

- **Hint banner**: Paper Card with 4pt tapered `azurite` brush edge on the left, `lightbulb` icon, 15pt text, close `xmark`. Auto-dismiss 8s, swipe-to-dismiss.
- **Atari notice** (beginner): same pattern, `warn` edge, `exclamationmark` icon — appears once per atari, never spams.
- **Toast**: bottom ink pill (`ink.primary` @ 92% fill, `paper.elevated` text, radius 20), 2.5s. "Game saved to library."
- **Empty state**: centered composition — ensō ring + single stone illustration (programmatic), Title 2 serif headline, Body `ink.secondary`, one Seal Button CTA. E.g., SGF Library empty: "谱架还空着 / No game records yet."
- **Error state**: same composition with `exclamationmark` in `seal.red` + retry Seal Button. Network loss during AI game: banner "Connection lost — your game is safe locally."

---

## 5. Screen Layouts

Frames below are ~393pt width (iPhone 15). iPhone SE (375pt): screen margins 16, board 343, player cards collapse to single-line rows. Pro Max (430): board caps at 420, extra space becomes outer margin.

### 5.1 Home

```
┌────────────────────────────────────────────┐
│ おはよう, Player                  🔥 12  ◉ │  greeting (localized) · streak · profile seal
│                                            │
│            ╭──────────╮                    │
│            │   棋譜    │   Kifu            │  app seal: 64pt cinnabar rounded square,
│            ╰──────────╯   围棋 · 바둑 · 囲碁 │  carved white characters + subtitle
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ 诘  Daily Tsumego          streak 12 → │ │  daily card: gold brush edge
│ │     Black to live · #129               │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ 弈  Play vs AI                         │ │  menu = vertical handscroll of paper cards,
│ │     19路 · 段位 · 中国规则              │ │  monogram left (calligraphy 34pt),
│ └────────────────────────────────────────┘ │  title Headline + subtitle Subheadline
│ ┌────────────────────────────────────────┐ │  ink.secondary, chevron.right
│ │ 学  Learn                              │ │
│ │     Ch. 3 — Ladders & Nets   ▓▓▓░░ 62%│ │  inline brush progress on active course
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ 诘  Tsumego · 128 solved               │ │
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ 析  Analysis · review your games       │ │
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ 谱  SGF Library · 42 records           │ │
│ └────────────────────────────────────────┘ │
│                                            │
│  ⌂ Home   📖 Learn   🧩 Tsumego  📚  ◉ Me │  custom tab bar, brush underline on active
└────────────────────────────────────────────┘
```

- Background: `paper.base` + grain + faint ink-wash behind the seal header.
- States: streak flame hidden at 0 (avoid negative pressure); daily card becomes "Completed ✓" (jade brush check) after solving.

### 5.2 Game Setup

```
┌────────────────────────────────────────────┐
│ ‹        对局 · New Game                   │
│                                            │
│ Board size · 棋盘                          │
│  ╭────╮   ╭────────╮   ╭────╮              │
│  │ 9×9│   │ 13×13  │   │19×19│             │  snap-paging carousel of wood board
│  ╰────╯   ╰────────╯   ╰────╯              │  thumbnails; selected = 2pt seal.red ring
│           ● ○ ○                             │  + scale 1.05; dots indicator
│                                            │
│ Difficulty · 棋力                          │
│ [入门][初级][中级][高级][段位][棋圣]          │  rank chips (§4.7), scrollable
│                                            │
│ Your color · 执子                          │
│ ( ● 执黑 | ○ 执白 | ✦ 猜先 Nigiri )         │  segmented; stones rendered per §3.3
│                                            │
│ Rules · 规则        Komi · 贴目            │
│ ( 中国规则 | 日本规则 )   [ − ] 6.5 [ + ]    │  segmented + stone stepper
│                                            │
│ Handicap · 让子       Time · 用时           │
│ [None][2][3][4][5]    [不限][10'][30']      │  chip rows
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │          开始对局 · Start Game          │ │  hero Seal Button w/ carved inset stroke
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

- Scrollable sheet-style page; hero CTA pinned above safe area with paper fade behind it.

### 5.3 Game Screen

```
┌────────────────────────────────────────────┐
│ ‹  对局 vs AI · 19路                  ⚙    │
│ ┌────────────────────────────────────────┐ │
│ │[玄] AI · 中级        ⚪×3    10:00  ◌  │ │  opponent card: seal avatar, rank,
│ └────────────────────────────────────────┘ │  capture pile, clock (tabular), turn ring
│                                            │
│   ┌──────────────────────────────────┐     │
│   │ A B C D E F G H J K L M N ...    │     │  goban per §3 — fills width,
│   │ ┌────────────────────────────┐   │     │  coordinates optional in Settings
│   │9 │··························│   │     │
│   │8 │··························│   │     │
│   │7 │··········◍···············│   │     │  ◍ = white stone, ◉ = black,
│   │… │··············◉◈··········│   │     │  ◈ = last-move seal chip
│   │  └────────────────────────────┘   │     │
│   └──────────────────────────────────┘     │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │[己] You · 12k       ⚫×5    09:41  ●   │ │  active card: breathing jade ring
│ └────────────────────────────────────────┘ │
│ ┌─ 💡 Hint ────────────────────────────┐  │
│ │ Consider the upper side — expand your │  │  beginner-mode hint banner (§4.9),
│ │ framework.                        ✕  │  │  azurite brush edge
│ └──────────────────────────────────────┘  │
│   ↩        💡        ✋        ⚑          │
│  Undo     Hint      Pass     Resign       │  ink icon buttons (§4.2)
└────────────────────────────────────────────┘
```

- **Capture piles:** up to 5 mini stones (12pt) stacked + `×N` caption tabular; overflow beyond 5 shows pile of 3 + count.
- Turn ring: 2pt `jade` stroke around the active player's card, 1.6s breathing opacity 100%→45%.
- Clock: `warn` color under 30s byo-yomi; subtle pulse, no flashing.
- Resign → confirmation Scroll Sheet ("认输？ This ends the game.") with Seal-destructive confirm.
- Game end → auto-navigate to Post-game Coach (5.6) with paper-slide transition.

### 5.4 Lesson Screen

```
┌────────────────────────────────────────────┐
│ ‹  学 · Chapter 3              ▓▓▓░░░ 62%  │  brush progress in nav bar
│                                            │
│        第 3 课 · The Ladder                 │  calligraphy chapter number + serif title
│                                            │
│  When stones are chased in a zig-zag       │  body text on paper scroll,
│  pattern, they cannot escape…              │  generous 24pt paragraphs spacing
│                                            │
│   ┌──────────────┐                         │
│   │  ink diagram  │   ← mini goban         │  inline diagram card (wood, 5×5 crop)
│   └──────────────┘                         │
│                                            │
│ ╭────────────────────────────────────────╮ │
│ │ 试试 · Try it: capture the white stone │ │  interactive task card:
│ │ ┌────────────────────────────────┐     │ │  7×7 live board, task seal chip,
│ │ │ ··◍····                        │     │ │  correct → jade brush check + stamp "对"
│ │ │ ·◉·◍···  ← tap to play         │     │ │  wrong → gentle shake + red brush ✗
│ │ └────────────────────────────────┘     │ │
│ ╰────────────────────────────────────────╯ │
│                                            │
│        ‹ Previous          Next ›          │  ink outline buttons
└────────────────────────────────────────────┘
```

- Scroll view with paper grain; diagrams and interactive boards reuse the §3 renderer in miniature (fixed 6–8pt cells, no coordinates).

### 5.5 Tsumego Screen

```
┌────────────────────────────────────────────┐
│ ‹        诘棋 · Tsumego          🔥 12     │
│                                            │
│  ╭────────╮                                │
│  │ 黑先   │  Black to play · #129         │  seal chip: cinnabar square,
│  ╰────────╯                                │  carved white characters
│                                            │
│        ┌────────────────────────┐          │
│        │▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│          │  cropped corner board —
│        │▒·····◉◉··············▒│          │  edges bleed off frame (▒)
│        │▒····◉··◍◍············▒│          │  to imply the larger goban
│        │▒····◉·◍··◍···········▒│          │
│        │▒····◉◉·◍◍············▒│          │
│        └────────────────────────┘          │
│                                            │
│        Correct! +1      円相 ✓             │  feedback zone:
│   ┌──────────────────────────────┐         │  success = gold ensō draw-on +
│   │        Next problem  →        │         │  jade brush check;
│   └──────────────────────────────┘         │  fail = red brush ✗ stroke,
│         Skip   ·   Reveal                  │  "Try again" (tertiary buttons)
└────────────────────────────────────────────┘
```

- Correct/wrong plays animate immediately on the board (opponent refutation auto-plays after 0.4s on failure).
- Streak increments with `.symbolEffect(.bounce)` + haptic.

### 5.6 Post-game AI Coach

```
┌────────────────────────────────────────────┐
│ ‹        复盘 · Review                     │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │            ╭──────╮                    │ │
│ │            │  胜   │   You win by 7.5  │ │  result seal (64pt): 胜/负 carved,
│ │            ╰──────╯   B+Resign? score  │ │  subtitle: score breakdown
│ │  Territory 52 · Captures 8 · Komi −6.5 │ │  footnote tabular row
│ │  Rank 12k ↗ 11k progress  ▓▓▓▓░░       │ │  rank delta in gold
│ └────────────────────────────────────────┘ │
│                                            │
│ Win rate · 胜率                            │
│  100┤        ╭─╮                           │  ink line chart, gold dots at
│   50┤    ╭──╯  ╰──╮    ● mistake          │  mistakes; area wash 6% ink;
│    0┼────╯        ╰──────                 │  hairline paper grid
│     └─────────────────────── moves         │
│                                            │
│ 3 key moments · 关键三手                    │
│ ┌────────────────────────────────────────┐ │
│ │ #47  ┌─────┐  Direction · 方向          │ │  mistake card: move badge,
│ │      │board│  This move let Black      │ │  72pt board thumbnail w/ red ring,
│ │      │thumb│  enclose the side…        │ │  tag chip, 2-line explanation,
│ │      └─────┘           [ Try again ]   │ │  small seal button
│ └────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────┐ │
│ │ #83  ┌─────┐  Life & Death · 死活       │ │
│ │      └─────┘           [ Try again ]   │ │
│ └────────────────────────────────────────┘ │
│                                            │
│      [ 🔁 Rematch ]      [ 📊 Analysis ]   │  seal primary + ink outline
└────────────────────────────────────────────┘
```

- "Try again" opens the position as an interactive tsumego-style task on the actual game branch.

### 5.7 Profile

```
┌────────────────────────────────────────────┐
│         Profile · 棋士                ⚙    │
│              ╭──────╮                      │
│              │  己   │   Player · 12k      │  avatar seal (user-chosen character),
│              ╰──────╯   rank chip          │
│                                            │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│ │  214    │ │  54%    │ │ 🔥 12   │        │  stats grid 2×3 paper cards:
│ │ games   │ │ winrate │ │ streak  │        │  big tabular number + caption
│ └─────────┘ └─────────┘ └─────────┘        │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│ │  128    │ │  62%    │ │  11k→   │        │  tsumego · course · rank trend
│ │ tsumego │ │ lessons │ │ peak    │        │
│ └─────────┘ └─────────┘ └─────────┘        │
│                                            │
│ Rating · 棋力变化                          │
│  11k┤            ╭──●                      │  ink line, gold current point,
│  12k┤      ╭────╯                          │  paper hairline grid,
│  13k┼──────╯                               │  range selector [1M][3M][All]
│     └──────────────────                    │
│                                            │
│ Achievements · 印章墙                       │
│   ⬤    ⬤    ⬤    ⬤                         │  wall of 48pt seal stamps, 4 per row;
│  初胜  十局  诘百  ◌?                       │  unlocked = cinnabar carved,
│                                            │  locked = stone gray; tap → detail sheet
└────────────────────────────────────────────┘
```

### 5.8 Analysis Screen

```
┌────────────────────────────────────────────┐
│ ‹      析 · Analysis            ⇪ Export   │  SGF export / import in nav bar
│        ┌────────────────────────┐          │
│        │    goban + overlays     │          │  board with AI overlays:
│        │  ·····A··············· │          │  candidate dots A/B/C w/ winrate
│        │  ···········◉········· │          │  labels, gold best-move arrow
│        │  ······B·············· │          │
│        └────────────────────────┘          │
│  ◀◀  ◀   ▶   ▶▶     move 47 / 214          │  variation transport, tabular counter
│ ┌────────────────────────────────────────┐ │
│ │ 🤖 Ask AI         Winrate 64.2% ▓▓▓▓░░ │ │  result panel: winrate brush bar,
│ │ Best: Q16 (+2.1)  A: R14  B: C12  C:… │ │  candidates list, score estimate
│ │ [ Heatmap ⌄ ] [ Score est. ]          │ │  toggles
│ └────────────────────────────────────────┘ │
│  Edit: ( ● place | ○ place | ✕ erase )     │  edit-mode segmented toolbar
└────────────────────────────────────────────┘
```

- Long-press a move in the transport to branch a variation; variations listed in a Scroll Sheet tree.

---

## 6. Animations & Micro-interactions

Use iOS 17 APIs: `withAnimation(.spring)`, `sensoryFeedback`, `phaseAnimator`, `.contentTransition(.numericText())`, `matchedGeometryEffect`, `.symbolEffect`. **Reduce Motion** replaces all springs/lifts with 0.15s crossfades.

| # | Trigger | Animation | Curve / duration | Haptic (sensoryFeedback) |
|---|---|---|---|---|
| 1 | Stone placed | Scale 1.12→1.0 + opacity 0.6→1 + shadow fades in; board cell does a 2pt "breath" | spring(response 0.28, damping 0.55) | `.impact(weight: .light)` |
| 2 | Capture | Stones lift −6pt, scale 1.06, then fade to 0 and fly (0.2s) toward the capturing player's pile counter; counter bumps with numericText transition | lift 0.15s ease-out → fade 0.25s | `.impact(weight: .rigid)` single stone; `.success` for group capture |
| 3 | Atari pulse (beginner) | Last-liberty dot + group ring pulse 45%→90% opacity ×3 | 0.9s ease-in-out ×3, then rests | `.warning` once |
| 4 | Hint reveal | Azurite ring draws on (trim 0→1) at suggested point + ghost stone fades in | 0.5s ease-out; ring pulses via phaseAnimator until dismissed | `.selection` |
| 5 | Achievement unlock | Full-screen dim; seal drops from 3× scale with −8° rotation, stamps to 1× with ink-bleed opacity ring + gold particle burst (12 particles, 0.6s) | spring(response 0.3, damping 0.5); particles ease-out | `.success` + heavy impact on stamp |
| 6 | Screen transitions | "Paper slide": push with 8pt parallax of the paper grain layer at 30% speed; tab switches crossfade | push 0.35s default; crossfade 0.2s | — |
| 7 | Streak milestone (7/30/100 days) | Flame scales 1→1.3→1 with `.symbolEffect(.bounce)`, ember particles rise, count rolls with numericText; ensō ring draws around flame | 0.8s total | `.success` |
| 8 | Clock low time | Timer text `warn` color + gentle opacity breath 1s loop under 10s | phaseAnimator infinite | `.warning` at 10s once |
| 9 | Wrong tsumego move | Board shakes ±4pt ×2, red brush ✗ strokes across played stone (trim animation) | 0.4s | `.error` |
| 10 | Correct tsumego/lesson | Gold ensō draws on around board, jade brush ✓ | 0.6s draw-on | `.success` |
| 11 | Button presses | Scale 0.97 / 0.94 (icon), shadow tightens | 0.12s ease-out | — |
| 12 | Sheet present | Scroll Sheet rises; grabber bamboo dots fade in 0.1s delayed | default sheet spring | — |
| 13 | AI thinking | Ensō spinner + breathing ghost at candidate point | 1.1s rotation loop | — |
| 14 | Counter changes (captures/score) | `.contentTransition(.numericText())` roll | default | — |

**Guardrails:** never animate the grid or wood; only one celebratory animation at a time; all loops (turn ring, hint pulse) stop when the view is off-screen or the app is backgrounded.

---

## 7. App Icon Concepts

### Concept A — "Stone & Seal" *(recommended)*
Cream xuan-paper field (`paper.base`) with visible grain. A single black slate stone (§3.3 rendering, radial gradient + soft contact shadow) sits slightly above center on a faint suggestion of two grid lines meeting beneath it — a lone tengen. Small cinnabar seal square (棋) in the bottom-right corner. Quiet, confident, instantly readable at 60px.

### Concept B — "Ensō Goban"
Deep ink-night background. A warm wood board corner (3×3 grid visible) lower-left; a single bold ink ensō brush ring sweeping around it, ends tapering. One gold fleck at the brush's end. Strong shelf presence among dark icons; conveys both meditation and the game.

### Concept C — "Balance"
Paper field. Two stones — black above, white below — offset diagonally like a yin-yang rhythm, connected by one fine grid line; tiny red seal dot (last-move marker) on the black stone, doubling as the app's signature UI element. Most "in-game" of the three; test small-size legibility of the red dot.

**Production notes:** deliver 1024px master, no alpha, test against iOS dark/tinted icon modes — provide a dark variant of Concept A (night field, stone unchanged).

---

## 8. Accessibility, Dynamic Type & Devices

### VoiceOver (board is fully playable by voice)
- The board is one `accessibilityElement` container with a custom **rotor: "Intersections"**; swiping moves by intersection.
- Every intersection label: `"Empty point Q16"` / `"Black stone at Q16"` / `"White stone at D4, star point"`. Groups: `"Black group, 5 stones, 3 liberties"`.
- After each move, announce: `"White played Q16. 2 black stones captured."`
- Custom actions on an empty point: *Place stone*, *Mark for analysis*; on the screen: *Pass*, *Resign*, *Hint*.
- Hint banner, atari notice, and game result post `.announcement` notifications.
- All controls meet 44×44pt minimum; stone placement supports the two-tap confirm mode (§3.4) as the accessible default.

### Dynamic Type
- All text styles scale; support up to **AX3 everywhere**, **AX5** on body-critical content (lesson text, coach explanations).
- Board geometry is fixed (coordinates exempt); cards and banners grow vertically; buttons wrap to 2 lines before truncating.
- Tab bar labels may hide at AX4+ (icons remain + VoiceOver labels).

### Other
- **Reduce Motion:** §6 substitutions.
- **Increase Contrast:** §1.4 adjustments.
- **Color-blind safety:** territory solid vs. hollow squares; liberty hints are circles vs. atari triangles; never hue-only coding.
- **Localization:** calligraphy font applied by script, not locale (§2.1); all seal characters (棋譜/胜/负/黑先/白先) localized with native-reviewed glyphs — JA uses 黒先, ZH 黑先, KO 흑선.

### Devices
- **iPhone SE (375×667):** board 343pt; game-screen player cards become single-line rows; controls row uses 40pt buttons; Home seal shrinks to 56pt.
- **Standard (390/393):** reference layouts per §5.
- **Pro Max (430):** board capped 420pt, extra margin; stats grid stays 3-column.
- **Landscape/iPad:** board left, side panel right (player cards + controls stacked); tab bar becomes left rail (§4.5). If iPad ships later, layouts already specified.

---

## 9. Asset Inventory (minimal by design)

| Asset | Type | Required? |
|---|---|---|
| Ma Shan Zheng Regular | Font file (~2 MB, OFL license — include attribution in Settings → Acknowledgements) | Yes (display CJK) |
| SF Symbols | System | Yes: `house`, `text.book.closed`, `puzzlepiece.extension`, `books.vertical`, `person.crop.circle`, `lightbulb`, `hand.raised`, `flag`, `arrow.uturn.backward`, `flame.fill`, `gearshape`, `xmark`, `chevron.left/right`, `checkmark`, `exclamationmark.triangle`, `square.and.arrow.up`, `play.fill`, `chart.line.uptrend.xyaxis` |
| Paper grain / wood / ink wash / seal texture | Procedural (Canvas, gradients, CIFilter noise) | Generated at runtime |
| Stones, board, markers | Procedural (§3) | Generated |
| App icon | Bitmap 1024px | Yes (one per concept, dark variant) |
| Ensō spinner, brush strokes, flames | Procedural shapes + SF Symbols | Generated |

---

## 10. Implementation Tokens (handoff summary)

- Color tokens: organize as semantic assets `Paper/Base`, `Paper/Elevated`, `Ink/Primary`, `Seal/Red`, `Jade`, `Gold`, `Azurite`, `Warn`, plus `Wood/*` and `Stone/*` — each with Paper/Ink Night variants per §1 (stones/wood single-variant).
- Font helpers: `displayFont(forScript:)` returning calligraphy/serif per §2.1; everything else uses system text styles.
- One shared `GobanView` renderer powers game, thumbnails, lesson minis, tsumego crops, and coach mistake cards (config: size, coordinates, overlays, interactivity).
- One shared `SealBadge`, `PaperCard`, `SealButton`, `InkIconButton`, `BrushProgressBar`, `EnsoSpinner` component set per §4.
- All animations from §6 behind a single `Motion` helper honoring Reduce Motion.

*End of specification v1.0 — questions on any token, measurement, or motion value should be resolved against §0's principles: Calm, Craft, Clarity.*
