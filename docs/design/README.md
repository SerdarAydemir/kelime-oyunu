# Handoff: Kelime Zirvesi (Word Summit) — Flutter UI redesign

## Overview
Complete visual redesign of the existing Flutter crossword app (`SerdarAydemir/kelime-oyunu`, branch `main`). The game is a Scandinavian-style arrow crossword ("çengel bulmaca") played turn-by-turn against a bot ("Rakip"). The redesign adds a mountain-climb metaphor: each level is a camp on a vertical trail, every win is +40 m, and the total level count is never shown so the climb feels endless.

Screens covered: splash, onboarding, consent, ATT interstitial, home, climb map, game (six states), clue sheet, swap sheet, result (won / lost / draw), settings, shop, legal, plus app icon and store screenshot frames. Everything exists in a dark and a light theme.

## About the Design Files
The `.dc.html` files in this bundle are **design references built in HTML** — they show intended look and behavior, they are not production code. The task is to **recreate these designs inside the existing Flutter codebase**, using its established structure (`lib/features/*`, `lib/core/constants/app_colors.dart`, `game_constants.dart`, the BLoC layer, `app_router.dart`). Do not port the HTML/JS; read it for exact values and behavior.

Open `Kelime Zirvesi.dc.html` in a browser (keep `support.js` and `kz-tokens.js` next to it). It is a pannable canvas of phone frames; the game screen, settings toggles and swap sheet are interactive.

**`kz-tokens.js` is the single source of truth** for colors (both themes), typography, radii, spacing, button heights, layout constraints, TR/EN strings, icon paths and the logo SVG. Port it 1:1 into `app_colors.dart` / a new `app_theme.dart` / `app_strings.dart`.

## Fidelity
**High-fidelity.** Colors, type sizes, radii, spacing and copy are final. Recreate pixel-accurately at 390 dp reference width; everything must scale to other widths (board cell 49–56 dp).

## Global rules
- Reference frame 390 × 844 dp. Status bar 50 dp top; home indicator 34 dp bottom — all content respects both safe areas. A `←` back icon (40 dp circle, `surface` background) is on every screen except home and splash.
- Fonts: **Lora** (serif; titles, scores, level numbers, letters) and **Nunito Sans** (everything else). Bundle both via `google_fonts` or assets.
- Two themes from `THEMES.dark` / `THEMES.light`. Setting "Görünüm": Açık / Koyu / Sistem, default Sistem.
- Amber accent `#f2c27a`, arrows `#c77a3c`, letter inks (player `#1a1a1a`, bot `#1a4b8c`, pending `#c77a3c`) are identical in both themes.
- "Rakip" is the opponent name everywhere (never "Sokrates"). Level count is never shown; the version string is just `Kelime Zirvesi 1.0.0`.
- Ad gates carry a tiny "▶ reklam" sub-label (7 px, 65 % opacity) under the button text. Hidden entirely in levels 1–3 (`showAdLabels && level > 3`).

## Screens

### Splash
Flat `bgFlat`. Centered: logo in a 120 dp rounded tile (r28, `LOGO_BG` gradient), "Kelime Zirvesi" Lora 700 40, tag "RAKİBE KARŞI ÇENGEL BULMACA" Nunito 600 11, ls 3, 70 %. Thin 120 × 3 progress bar (accent on `surface`) 64 dp from bottom.

### Onboarding (3 cards, skippable)
"Atla" top-right. Card 1: mini board strip (clue cell → pending amber "İ" → highlighted empty cell → empty) with a floating amber tile "L" rotated −8°, bobbing 2.4 s. Below: "1 / 3" (Nunito 600 11 ls 3 muted), title Lora 700 28, body Nunito 400 15 / 1.55 muted, step chips (İpucu · Harf koy · Onayla · Rakip cevap verir; active chip amber). Bottom: 3 dots (active 22 × 6 amber) and "Devam" primary 56.
Steps 2–3 reuse the layout with the next chip active (copy for those is the chip text; keep to one sentence each).

### Consent (/consent)
`bgGame` with two faint mountain polygons (`mtn1` 70 %, `mtn2` 60 %). "HOŞ GELDİN" tag, title "Tırmanışa başlamadan önce" Lora 700 40. Bottom card (`sheet` bg, r20): title "Reklamlar ve veri" Lora 700 18, body Nunito 400 14 / 1.55 `sheetMuted`, links "Gizlilik politikası · Kullanım koşulları" 700 13 `#c77a3c`. Buttons: "Kabul et ve başla" primary 56, "Seçenekleri yönet" outlined 48.

### ATT interstitial (iOS only, shown right before the system ATT dialog)
`bgFlat`. 64 dp `surface` circle with shield-check icon in accent, tag "BİR ADIM KALDI", title "Takip izni hakkında" Lora 700 36, body Nunito 400 15 / 1.6 muted, a bordered r18 list with two bullet lines (green dot). Buttons "Devam" primary, "Şimdi değil" text-only 48. Never mimic the system dialog.

### Home
`bgHome` gradient + three mountain polygons (`mtn1` 85 %, `mtn2`, `mtn3`) + dashed amber trail path with an amber dot.
- Tag "RAKİBE KARŞI ÇENGEL BULMACA" Nunito 600 12 ls 3, 80 %; name "Kelime / Zirvesi" Lora 700 62 / 0.95 two lines, ls −1.
- Pill (`card` bg, blur 6, 1 px `border`, r999): "Şu an" 600 13 · "Bölüm {n}" Lora 700 20 · "· {m} m" 600 13. Altitude = (n − 1) × 40 + base.
- Stats row Nunito 600 12: "Bugünün serisi · {d} gün" / "Bulunan kelime · {w}".
- Save card (`card`, r18, 16 × 18 padding): "Yarım kalan oyun" 700 13 75 % + "Bölüm {n} · Sen 12 – Rakip 9" Lora 600 18. Empty state: "Kaydedilmiş oyun yok" + "Yeni bölüme başlamak için aşağıya dokun" at 60 %.
- CTA "Tırmanışa devam et" (or "Bölüm {n} ile başla") primary 56, shadow `0 10 30 rgba(242,194,122,.35)`. Then "Harita" / "Ayarlar" outlined 48 side by side.

### Climb map
Vertical scroll; content height = N × 96 dp + 240, where N = max(level + 40, 80) — always render ~40 nodes above the player. Trail: dashed amber polyline (3 px, dash 5 9, 60 %) through node centers at x = 195 + 118·sin(n·0.85), y = H − 140 − (n−1)·96.
- Sticky top 200 dp fog gradient (`fog` → transparent) with header "TIRMANIŞ / Bölüm {n} · {m} m" and caption "yukarısı sisin içinde…" (600 12, 60 %).
- Node states: **done** = 48 dp r12 card (`board` bg, 2 px amber border) showing a 2 × 2 mini grid (clue / letter with level number Lora 700 11 / letter / amber) — tappable, replays the level; **current** = 68 dp amber circle, number Lora 700 24 + "BURADASIN" 800 8, pulse ring 2 s, glow `0 0 40 rgba(242,194,122,.5)`; **next two** = 44 dp dashed circle with lock icon, no number; **far** = 14 dp dot `faint`.
- Bottom label "Kamp · başlangıç". On open, scroll so the current node sits at 60 % of viewport height.

### Game screen
- Header: back · "BÖLÜM" 600 11 ls 3 70 % + level Lora 700 22 · more (⋯).
- Scorebar grid `1fr auto 1fr`: 38 dp avatar circle (amber for player, `bot` blue for Rakip) with person silhouette; "Sen"/"Rakip" 600 11 70 %; score Lora 700 22. "VS" 600 11 ls 2 55 %.
- Turn pill (r999, 700 11): amber tint for player states, blue tint `rgba(127,167,216,.18)` for bot, red tint for wrong letter. Texts: "Sıra sende" / "{n} harf bekliyor · onayla" / "Boş bir hücreye dokun" / "Rakip düşünüyor" / "{WORD} · +{n} puan" / "Bu harf buraya uymuyor".
- **Board**: 9 rows × 7 cols fixed, cell 50 dp at 390 (allow 49–56), gap 2, board padding 6, r16, `board` bg, 1 px `boardBorder` (light only), `boardShadow`. Cell r6. Corner cell = logo on `#0b1a33`. Clue cells `cellClue`, text `clueText` Nunito 600, auto size: ≤ 8 chars 12 px, ≤ 14 chars 10 px, else 9 px, max 3 lines, `hyphens: manual` (never break mid-word; use soft hyphen at syllable). Double clue cell: 8 px, 1 px divider at 50 %, each half ≤ 2 lines & ≤ 16 chars. Arrows: 5 px triangles `#c77a3c` at right edge (across) / bottom edge (down). Letter cells `cellLetter`, letter Lora 700 22; pending cell `cellPending` + ink `#c77a3c`; wrong flash `cellWrong` + 2 px inset `error`, 600 ms.
- **Rack**: 5 tiles 52 × 56 r10 gap 6 + dashed slot. Idle: `tile` bg, `0 4 0 tileShadow`. Selected: amber, translateY −8, shadow `0 12 24 rgba(242,194,122,.4)`. Placed: dashed `faint` empty slot. Wrong-return: 2 px `error` ring. "+ HARF EKLE" slot: 1.5 px dashed accent, plus icon 16, label 800 7.5 — ad-gated, then rack becomes 6 tiles.
- **Bottom bar** (44 dp from bottom): swap 52 dp circle (1.5 px `faint` border, swap icon) · confirm pill 52 (amber, "Onayla" when ≥1 pending else "Pas") · hint 52 dp circle (amber 15 % fill, 1.5 px amber border, lamp icon 17, "İPUCU AL" 800 7 + ad sub-label).
- **States shown**: Sıra sende (interactive) · Rakip düşünüyor (player side 55 %, rack 45 %, bar 40 %, confirm pill becomes `surface` with "Sıra rakipte", bot avatar 3 px blue ring pulsing) · Kelime tamamlandı (3 px amber ring + `0 0 30 6 rgba(242,194,122,.55)` glow around the word, glow pulses 1.2 s; "+12 ↑" amber badge bobs then flies to score) · Harf uçuşu (bot tile Lora 24 ink `#1a4b8c`, rotated −14°, dashed blue arc from avatar to target cell which has a 2 px blue inset) · Yanlış harf (tile flies back along a red dashed arc, 2 px red ring, rack tile keeps ring 600 ms) · Bağlantı yok (toast above rack: `solid` bg r14, wifi-off icon red, "Bağlantı yok · reklam yüklenemedi" 600 12, "Tekrar dene" 800 12 amber).

### Clue sheet (tap a clue cell)
Dim `dim` overlay; sheet `sheet` bg r28 top, handle 44 × 5. Title "İpuçları" Lora 700 24, subtitle "{row}. satır · {col}. sütun — bu hücre iki kelimeye açılıyor" 600 12 `sheetMuted`. One card per clue (`sheetCard`, r16, p16): 36 dp r10 `#c77a3c` square with arrow icon, "SAĞA · 3 HARF" 600 11 ls 1, clue text Lora 600 18. "Kapat" 52 `solid`.

### Swap sheet
Same shell. Header "Harf değiştir" + "Kalan hak · {n} harf" 700 12. Sub "Değiştirmek istediğin harflere dokun." Tiles 56 × 60 r10 (`sheetCard`, `0 4 0 tileShadow`); selected → amber, 3 px `#c77a3c` ring, translateY −6. Hint line "{n} harf seçildi" / "Henüz harf seçilmedi". Buttons (40 % opacity when nothing selected): "Şimdi değiştir [▶ reklam] · sıra sende kalır" primary 56; "Değiştir ve pas · ücretsiz, sıra rakibe" outlined 52.

### Result screens
Mountain polygons in theme `mtn*`. Tag "BÖLÜM {n} · KAZANDIN / KAYBETTİN / BERABERE" 600 12 ls 4; headline Lora 700 44 / 1.05.
- **Won**: `bgWon` (dawn) + sun circle r70 `#fff3d6` 90 %. Headline "Bir adım daha / zirveye". Pill "+40 m → {m} m" (dark `rgba(20,12,10,.7)` bg, amber number). Score card (`card`, r20, grid 1fr auto 1fr, scores Lora 700 40; player `#e0a24a`, bot `#3a7fc4`, "fark {d}"). Buttons: "Bölüm {n+1} · tırmanmaya devam" 56 `solid`; "Tekrar oyna" / "Harita" outlined 48 in `solid` color.
- **Lost**: `bgLost` (night) + campfire (r9 amber + r22 15 %). "Kampta / bir gece daha", sub "Rakip bu eli aldı. Aynı yerden yeniden dene; yükseklik kaybı yok." Buttons "Tekrar dene" primary 56, "Haritaya dön" outlined 48.
- **Draw**: `bgDraw` (neutral), behaves like Lost. "Berabere · / Rakiple başa baş", sub "Puanlar eşit. Aynı kamptan yeniden dene; yükseklik kaybı yok."

### Settings
`bgFlat`. Title "Ayarlar" Lora 700 20. Section labels 600 11 ls 3 55 %. Groups: `surface` bg, r18, 1 px `border`, rows 14 × 18 padding, 1 px `border` dividers, label 700 15, sub 500 12 60 %.
- OYUN: Görünüm — segmented pill (Açık / Koyu / Sistem, active amber, 700 12, 6 × 12 padding) · Ses · Titreşim · Gökyüzü ("Arka plan ilerlemeyle değişir") toggles 48 × 28 (on: amber track, `#2a1a10` knob right; off: `toggleOff` track, `knob` left).
- HESAP: Reklamları kaldır → "Mağaza →" (700 13 `#c77a3c`) · Reklam tercihleri › · İlerlemeyi sıfırla → "Sil" (`error`) · Gizlilik politikası › · Kullanım koşulları ›.
- Footer "Kelime Zirvesi 1.0.0" 500 12 45 %.

### Shop
Header "Kamp dükkânı" + coin pill (amber 18 % bg, `#c77a3c`, coin icon, 800 13). Hero card gradient `135deg #f2c27a → #c77a3c`, ink `#2a1a10`, r20: "TEK SEFERLİK" / "Reklamsız tırmanış" Lora 700 26 / body 500 13 / price chip `#2a1a10` "₺89,99". "KAMP PARASI" 2-col cards (`surface`, r18): 150 (≈ 15 harf açma, ₺29,99 outlined) and 500 (≈ 50 harf açma, ₺79,99 amber, badge "EN ÇOK ALINAN", 1 px amber border). "ÜCRETSİZ" row "Günlük kamp ateşi / Her gün 20 para" with "Al" amber chip. Footer "Satın alımları geri yükle" (required on iOS).

### Legal (privacy / terms)
`page` bg, `pageText`. Title Lora 700 20, "Son güncelleme · …" 500 12 `pageMuted`, section headings Lora 700 22, body paragraphs; skeleton bars in the mock are placeholders for real text.

### App icon & store frames
Icon "1A Sıradağ + güneş": 7 × 5 cell grid mountain (rock `#c77a3c`, snow `#e9dcc1`/`#f6ecd9`, summit `#f2c27a`) with amber sun top-left, on `linear-gradient(160deg,#1c3358,#0b1a33)`. Files: `app-icon-1a.svg` (full, iOS flat / 1024), `app-icon-1a-foreground.svg` (Android adaptive foreground; background = the gradient). Same drawing fills the board's corner cell on `#0b1a33`.
Store screenshots: 5 frames (Oyun · Harita · Kazandın · İpucu · Ana ekran), slogan band Lora 700 (see `STRINGS.tr.slogans`), simplified phone below.

## Interactions & Behavior
- Select rack tile → tile lifts; tap empty letter cell → letter placed as pending (amber); tap a pending cell → returns to rack. Confirm commits all pending; Pas ends turn with none.
- Bot turn: disable rack/bar (opacities above), pill "Rakip düşünüyor" with 3 bobbing dots (1 s, 0.2 s stagger), tiles fly from bot avatar to cells (≈ 450 ms ease-out, slight rotation).
- Word complete: amber ring + glow 1.2 s, "+N" badge rises and flies to the player's score (≈ 600 ms), score counts up.
- Wrong letter: tile flies back to rack along an arc (≈ 500 ms), red ring 600 ms, cell flashes `cellWrong`.
- Map current node pulses (2 s); onboarding tile bobs (2.4 s). All easing ease-in-out unless noted.
- Sky ("Gökyüzü") on: home/map gradients shift night → dawn → day with progress; off: fixed dark/light gradient.
- Level count is hidden; map always shows +40 levels of fog above the player.

## State Management
- Theme mode (light / dark / system), sound, haptics, sky toggle — persisted.
- Progress: current level, altitude (level × 40 m), streak days, words found, saved game snapshot (board + scores + rack).
- Per game: board cells, pending placements, selected rack index, rack, swap credits left (12), scores, turn (player / bot), result.
- Ads: consent state, ATT status, ad-free purchase, coins balance, daily campfire claimed date; `showAdLabels` false for levels ≤ 3.
- Offline: ad load failure → toast; gameplay unaffected.

## Flutter sapmaları (uygulama tarafında eklenen / değişen token'lar)
`kz-tokens.js` tasarım kaynağı olarak değişmedi; Flutter portunda (`lib/core/theme/app_tokens_*.dart`) şu sapmalar var:
- **Eklendi `gridLine`** — hücre arası 0.5 px çizgi rengi. dark: `#e9dcc1` (= `cellClue`), light: `#e3d5b6` (= `boardBorder`). Tasarımda hücreler 2 dp boşlukla tahta zemini üzerinde ayrışıyor; painter çizgi çizdiği için ayrı token gerekti (2026-09-24, A2).
- **Sonuç ekranı literal renkleri** — güneş `#fff3d6` → `AppTokens.light.board` (%90); skor kartında oyuncu `#e0a24a` → `accent`, rakip `#3a7fc4` → `bot`. Token dışı literal eklenmedi (2026-09-24, C).
- **Değişti `light.cellLetter`** — `#ffffff` → `#fffdf7`; açık temada harf hücresi `#fffaf0` tahtadan ayrışsın diye (2026-09-24, A2).

## Design Tokens
See `kz-tokens.js` — `THEMES` (55 tokens × 2 themes with `TOKEN_META` descriptions), `TYPE` (Lora 62/40/22/15; Nunito Sans 18/15/13/12/11), `RADII` 6/10/16/18/20/999, `SPACE` 2–40, `BUTTONS` 56/52/48, `LAYOUT` constraints, `ICONS` (24 px, 2 px stroke, round caps), `STRINGS.tr` / `STRINGS.en`, `LOGO_SVG`, `LOGO_BG`.

## Assets
- `app-icon-1a.svg`, `app-icon-1a-foreground.svg` — vector; rasterize to 1024 / adaptive 108 dp.
- Icons are inline SVG paths in `ICONS`; no external icon font.
- Fonts: Lora, Nunito Sans (Google Fonts, OFL).
- No photos. Avatars are a person silhouette placeholder in a 38 dp circle (designed to be replaced by photos later).

## Files
- `Kelime Zirvesi.dc.html` — all screens, both themes (open in browser; needs `support.js`, `kz-tokens.js`).
- `Kelime Zirvesi Design System.dc.html` — token table, type scale, component states, icon set, TR/EN strings.
- `kz-tokens.js` — source of truth for every value above.
- `app-icon-1a.svg`, `app-icon-1a-foreground.svg`.
