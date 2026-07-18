# \# architecture.md — Mimari Dokümanı (v4.1)

# 

# > \*\*SÜRÜM NOTU (v4.1 — BÜYÜK YENİDEN TASARIM)\*\*

# > Bu sürüm, oyunu "word search" (harf ızgarasında gizli kelime arama) mekaniğinden,

# > \*\*rekabetçi İskandinav çengel bulmaca\*\* (Easybrain "Cross Up" tarzı) mekaniğine taşır.

# > Oyuncu, bir bota karşı sıra-tabanlı puan yarışı yapar; elindeki harfleri ipuçlu

# > bulmaca tahtasına yerleştirir.

# >

# > v3.x'teki word search grid üretimi (`word\_search\_generator.py`) ve eski JSON şema

# > \*\*terk edilmiştir\*\*. Korunan altyapı için bkz. §12 (Korunan/Atılan Kod).

# >

# > \*\*GÜNCEL DURUM (2026-07) — bu doküman ilk tasarımdır, ürün evrildi. Kaynak-doğruluk = `CLAUDE.md`.\*\*

# > Aktif sapmalar (doküman gövdesi bunları HENÜZ yansıtmıyor):

# > • \*\*İlerleme:\*\* "günlük eşleşme" (§1.1) DEĞİL — 200 sıralı bölüm, sert ilerleme, bot zorluğu

# >   bölüm no'sundan türer. \*\*`matchmaking` feature'ı yok\*\* (§2/§9'daki referanslar hayali).

# > • \*\*Grid:\*\* üretimde tek boyut \*\*9×7 tam-çerçeve\*\*; §1.2/§5.3'teki 3-boyut (6×5/8×6/10×7) ve

# >   §5.7-5.8'deki "loose" model UYGULANMADI (strict tam-çerçeve kullanıldı).

# > • \*\*Resume box adı `active_session`\*\* (§11'deki `active_game` değil). Codec: `session_codec.dart`.

# > • \*\*Yapıldı, gövdede yok:\*\* drag&drop (`rack_widget`/`grid_painter`), F6 puan-anlatısı +

# >   harf-uçuşu (`narration_*.dart`, zamanlama UI-tarafı, bloc gate'lenmez), level-select

# >   (`features/levels/`, `/levels` giriş rotası).

# > • \*\*Sıradaki içerik işi:\*\* P1 re-clue (clue kalitesi — bkz. memory `p1-reclue-diagnosis`).

# 

# \---

# 

# \## İçindekiler

# 1\. Oyun Mekaniği Spesifikasyonu

# 2\. Klasör Yapısı (Feature-First)

# 3\. Katman Mimarisi ve State Yönetimi

# 4\. JSON Şema v2 (Puzzle Veri Modeli)

# 5\. Mask Template Sistemi

# 6\. CSP Fill Algoritması (Python)

# 7\. İpucu Sistemi (TDK → LLM → Placeholder)

# 8\. Flutter Runtime: GameBloc + Skor Motoru

# 9\. Flutter Runtime: AI Rakip (Bot)

# 10\. Flutter Runtime: Harf Yerleştirme + Animasyon

# 11\. Veri Saklama (Hive) + Resume

# 12\. Reklam ve Monetizasyon

# 13\. Korunan / Atılan Kod Tablosu

# 14\. Türkçe Dil Kuralları

# 15\. Üretim Hattı Özeti (Pipeline)

# 

# \---

# 

# \## 1. Oyun Mekaniği Spesifikasyonu

# 

# \### 1.1 Genel Akış

# \- Oyun \*\*günlük\*\*: her gün bir bot profiliyle (örn. "Sokrates") eşleşilir.

# \- \*\*Sıra-tabanlı\*\*: Önce oyuncu hamle yapar → "Onayla" → sonra bot hamle yapar → tekrar oyuncu.

# \- Oyun, \*\*tahtadaki son boş hücre dolunca\*\* biter. Süre sınırı yoktur.

# \- Yarıda bırakılırsa, \*\*kaldığı yerden devam\*\* edilir (resume, §11).

# \- Bitişte: basit özet ekranı ("Kazandın! 109 vs 38, +71 puan fark"). \*\*Zengin istatistik dashboard MVP'de YOK.\*\*

# 

# \### 1.2 Tahta (Grid)

# \- İskandinav çengel bulmaca: ipucu hücreleri grid \*\*içinde\*\*, ok yönüyle.

# \- İpucu tipi: \*\*metin\*\* ("İÇİNE ALMAK") veya \*\*görsel\*\* (MVP'de görsel sonra, §7).

# \- \*\*Çift ipucu hücresi\*\*: bir hücrede 2 ipucu, farklı yönlere (örn. üst yarı "ESKİ HÜKÜMDAR UNVANI" → sağ ok, alt yarı "ON BİRİNCİ AY" → aşağı ok).

# \- Oklar: sağ (→) veya aşağı (↓). Kelime, ipucu hücresinden ok yönünde uzanır.

# \- Kelimeler \*\*kesişir\*\* (intersection): ortak hücre, iki kelime için de geçerli harf.

# \- \*\*Tek-harf cevaplar\*\* olabilir ("ÜÇÜNCÜ HARFİMİZ" → C; "KLORUN SİMGESİ" → tek hücre).

# \- Türkçe karakterler: Ç, Ş, Ğ, İ, I, Ö, Ü tam desteklenir (kuyruklu Ş/Ç render dahil).

# 

# \### 1.3 Harf Eli (Rack)

# \- Başlangıçta \*\*5 harf\*\*.

# \- \*\*Reklam izleyerek 6. harf\*\* açılır (rack'teki "+/Ad" yuvası → rewarded video).

# \- Rack harfleri, \*\*tahtada çözülmesi gereken hücrelere uygun\*\* rastgele dağıtılır (Scrabble torbası DEĞİL — bulmacanın ihtiyaç duyduğu harfler ağırlıklı).

# \- Bir hamle onaylandıktan sonra rack eksilen harf sayısı kadar yeniden doldurulur.

# &#x20; - \*\*İstisna:\*\* Yanlış yerleştirilen harf rack'e geri döner; sıra tekrar gelince o harf rack'te kalır (yani 5 yerine 4 yeni harf gelir, biri eski).

# 

# \### 1.4 Puanlama (KESİN KURALLAR)

# | Olay | Puan |

# |------|------|

# | Doğru harf yerleştirme | \*\*+1\*\* (her harf, yeşil "+1" animasyonu) |

# | Yanlış harf yerleştirme | \*\*−1\*\* (kırmızı "−1", harf rack'e döner) |

# | Bir kelimeyi tamamlama | \*\*kelime uzunluğu kadar\*\* bonus (örn. 4 harfli → +4) |

# | Eli tamamen boşaltma (5 harf) | \*\*+5\*\* ("Harikasın 🚀 Muhteşem 5'li") |

# | Eli tamamen boşaltma (6 harf, power-up'lı) | \*\*+6\*\* ("Etkileyici 🎉 Süper 6'lı") |

# 

# > \*\*NOT — İki ayrı bonus:\*\* "Kelime tamamlama" bonusu (kelime uzunluğu kadar) ve

# > "el boşaltma" bonusu (5 veya 6) \*\*farklı\*\* şeylerdir. Bir hamlede ikisi de gerçekleşebilir.

# 

# \### 1.5 Aksiyon Butonları (Alt Panel)

# \- \*\*Değiştir\*\* (sol): Bottom-sheet açar, "en fazla 5 harf seç" → reklam izle → yeni harfler. Sıra harcar.

# \- \*\*Pas / Onayla\*\* (orta): Grid'e harf konmadıysa "Pas" (sıra bota geçer), en az 1 harf konduysa "Onayla".

# \- \*\*Kelime / "K" (sağ, Ad rozetli)\*\*: İpucu hücresine tıklayınca açılan modal — "Bu ipucunu kullanmak istiyor musun? → Kelimeyi Aç" → reklam izle → o kelime açığa çıkar (gri harflerle). Sıra harcamaz (yardım).

# 

# \### 1.6 Renk Kodları (Tahta)

# \- \*\*Turuncu/sabit siyah harf\*\*: oyuncunun doğru yerleştirdiği, kalıcı.

# \- \*\*Yeşil "+1" / "+N" rozeti\*\*: puan animasyonu (kısa süreli).

# \- \*\*Kırmızı çerçeve + "−1"\*\*: yanlış yerleştirme.

# \- \*\*Gri harf\*\*: "Kelimeyi Aç" ile açılan veya bot tarafından doldurulan harf.

# \- \*\*Yeşil arka plan hücre\*\*: ipucu hücresi.

# 

# \### 1.7 Ekranlar

# \- \*\*Yükleme\*\*: logo + progress bar + silik ipucu görselleri arka planda ("Yükleniyor...").

# \- \*\*Günlük Rakip popup\*\*: "Bugün Rakibin: Sokrates" + avatar + açıklama + "Oyuna Başla".

# \- \*\*Oyun ekranı\*\*: üst skor tabelası (Sen X vs Y Bot+avatar), scrollable grid, rack, aksiyon barı, alt banner.

# \- \*\*Oyun sonu\*\*: "Kazandın!/Kaybettin" + skorlar + fark + "Yarın yeni karşılaşma".

# \- \*\*3 sekmeli alt nav\*\* (genel uygulama): Ana / Günlük / Profil(Me).

# 

# \---

# 

# \## 2. Klasör Yapısı (Feature-First)

# 

# ```

# lib/

# ├── main.dart

# ├── app.dart

# ├── core/

# │   ├── constants/        # app\_colors, app\_typography, app\_dimensions

# │   ├── theme/            # app\_theme (light + dark)

# │   ├── router/           # app\_router (go\_router)

# │   ├── utils/            # result.dart, logger.dart, turkish.dart

# │   ├── errors/           # app\_exception.dart

# │   └── di/               # service\_locator.dart (get\_it)

# ├── data/

# │   ├── models/           # puzzle, cell, word, player\_state, bot\_profile (Hive + json)

# │   ├── repositories/     # puzzle\_repository, progress\_repository

# │   └── sources/          # asset\_puzzle\_source (JSON loader), secure\_hive

# ├── features/

# │   ├── gameplay/

# │   │   ├── bloc/         # game\_bloc, game\_event, game\_state

# │   │   ├── engine/       # score\_engine, bot\_engine, rack\_manager

# │   │   ├── view/         # game\_screen

# │   │   └── widgets/      # grid\_painter, rack\_widget, score\_header,

# │   │                     #   action\_bar, clue\_modal, swap\_sheet, flying\_letter

# │   ├── matchmaking/      # daily\_opponent (bot seçimi + popup)

# │   ├── home/             # ana menü + sekmeler

# │   ├── result/           # oyun sonu özet ekranı

# │   ├── monetization/     # ad\_service, iap\_service (+ mock'lar)

# │   └── settings/

# └── l10n/                 # .arb dosyaları (tr)

# 

# assets/

# ├── puzzles/              # Python'ın ürettiği .json bölümler + manifest.json

# ├── clue\_images/          # (FAZ ileri) görsel ipuçları

# ├── fonts/

# └── audio/

# 

# tools/

# └── puzzle\_generator/     # (eski level\_generator yeniden adlandırılır)

# &#x20;   ├── src/kelime\_gen/

# &#x20;   │   ├── schema.py            # YENİ v2 şema

# &#x20;   │   ├── word\_pool.py         # KORUNDU (Türkçe filtre + frekans)

# &#x20;   │   ├── mask\_template.py     # YENİ: mask yükle + transform

# &#x20;   │   ├── csp\_filler.py        # YENİ: AC-3 + backtracking fill

# &#x20;   │   ├── clue\_writer.py       # YENİ: TDK/placeholder ipucu

# &#x20;   │   ├── post\_fill\_safety.py  # KORUNDU (küfür tarama, uyarlanır)

# &#x20;   │   ├── difficulty.py        # UYARLANIR

# &#x20;   │   ├── generator.py         # YENİDEN: mask seç → fill → ipucu → doğrula

# &#x20;   │   └── \_\_main\_\_.py          # CLI

# &#x20;   ├── templates/               # YENİ: elle tasarlanmış mask şablonları

# &#x20;   │   ├── small\_\*.json   (6×5)

# &#x20;   │   ├── medium\_\*.json  (8×6)

# &#x20;   │   └── large\_\*.json   (10×7)

# &#x20;   └── tests/

# ```

# 

# \---

# 

# \## 3. Katman Mimarisi ve State Yönetimi

# 

# \### 3.1 Katman Sırası

# ```

# View → Bloc/Cubit → Engine → Repository → Source/Data

# ```

# Ters yön çağrı yasak. UI iş mantığı içermez; event gönderir, state dinler.

# 

# \### 3.2 State Yönetimi

# \- \*\*Gameplay → `Bloc`\*\* (event-driven, karmaşık sıra-tabanlı akış).

# \- \*\*Diğer her şey → `Cubit`\*\* (home, settings, matchmaking, result).

# \- Gameplay'in alt motorları (`ScoreEngine`, `BotEngine`, `RackManager`) \*\*saf Dart sınıflarıdır\*\* (Bloc'tan bağımsız, unit-test edilebilir). Bloc bunları orkestratör olarak kullanır.

# 

# \### 3.3 Neden Flame YOK (ADR-0004 devam)

# Grid + animasyonlar `CustomPainter` + `AnimationController` + `Overlay` ile çözülür.

# Flame, bu 2D ızgara-tabanlı, fizik içermeyen oyun için aşırı ağırdır. Harf uçma

# animasyonu Overlay+AnimatedPositioned ile yapılır (§10).

# 

# \---

# 

# \## 4. JSON Şema v2 (Puzzle Veri Modeli)

# 

# \### 4.1 Üst Seviye Yapı

# ```json

# {

# &#x20; "schema\_version": 2,

# &#x20; "puzzle\_id": 27,

# &#x20; "size": "medium",

# &#x20; "grid": { "rows": 8, "cols": 6 },

# &#x20; "cells": \[ /\* CellSpec\[] — aşağıda \*/ ],

# &#x20; "words": \[ /\* WordSpec\[] — aşağıda \*/ ],

# &#x20; "difficulty": "medium",

# &#x20; "difficulty\_score": 45,

# &#x20; "template\_id": "medium\_03",

# &#x20; "safety": { "post\_fill\_scanned": true, "scanner\_version": "2.0.0" },

# &#x20; "generated\_at": "2026-05-29T23:01:00Z",

# &#x20; "generator\_version": "2.0.0"

# }

# ```

# 

# \### 4.2 CellSpec — Her hücrenin tipi

# Grid `rows×cols` boyutunda; her hücre şu tiplerden biri:

# 

# ```json

# // Boş harf hücresi (oyuncu dolduracak)

# { "row": 1, "col": 1, "type": "letter", "solution": "K", "word\_ids": \["w1", "w7"] }

# 

# // Tek ipucu hücresi

# { "row": 0, "col": 1, "type": "clue",

# &#x20; "clues": \[ { "text": "İÇİNE ALMAK", "arrow": "down", "word\_id": "w1" } ] }

# 

# // Çift ipucu hücresi (2 ipucu, farklı yönler)

# { "row": 2, "col": 3, "type": "clue",

# &#x20; "clues": \[

# &#x20;   { "text": "ESKİ HÜKÜMDAR UNVANI", "arrow": "right", "word\_id": "w4" },

# &#x20;   { "text": "ON BİRİNCİ AY",        "arrow": "down",  "word\_id": "w5" }

# &#x20; ] }

# 

# // Görsel ipucu hücresi (FAZ ileri — MVP'de image\_id null/opsiyonel)

# { "row": 0, "col": 4, "type": "clue",

# &#x20; "clues": \[ { "text": "Lahana", "image\_id": "cabbage", "arrow": "down", "word\_id": "w3" } ] }

# 

# // Bloklu/kullanılmayan hücre (tahtanın dışı kalan boşluklar)

# { "row": 5, "col": 2, "type": "blank" }

# ```

# 

# \*\*Alan kuralları:\*\*

# \- `arrow`: `"right"` | `"down"` (MVP). İleride çapraz eklenebilir ama PLAN DIŞI.

# \- `solution`: tek Türkçe büyük harf (`tr\_upper` ile normalize, §14).

# \- `word\_ids`: bu hücrenin parçası olduğu kelime(ler); kesişim hücresinde >1.

# \- Bir `clue` hücresi 1 veya 2 ipucu taşır (`clues` listesi 1-2 eleman).

# 

# \### 4.3 WordSpec — Her kelimenin tanımı

# ```json

# {

# &#x20; "id": "w1",

# &#x20; "answer": "KAPSAMAK",

# &#x20; "length": 8,

# &#x20; "direction": "down",

# &#x20; "clue\_cell": { "row": 0, "col": 1 },

# &#x20; "start\_cell": { "row": 1, "col": 1 },

# &#x20; "cells": \[ {"row":1,"col":1}, {"row":2,"col":1}, ... ],

# &#x20; "clue": { "text": "İÇİNE ALMAK", "image\_id": null, "source": "placeholder" },

# &#x20; "frequency\_score": 35

# }

# ```

# \- `cells`: çözüm hücrelerinin sıralı listesi (ipucu hücresi hariç).

# \- `clue.source`: `"tdk"` | `"llm"` | `"placeholder"` (§7).

# \- `frequency\_score`: word\_pool'dan gelir (difficulty hesabı için).

# \- Tek-harf kelime: `length: 1`, `cells` tek eleman.

# 

# \### 4.4 Doğrulama Kuralları (schema\_validator)

# \- Her `WordSpec.cells\[i]` → `grid` sınırları içinde.

# \- Her çözüm hücresi `cells\[i]` için `CellSpec.solution == answer\[i]`.

# \- Kesişim: bir `letter` hücresi birden çok `word\_id` taşıyorsa, tüm o kelimelerin

# &#x20; o noktadaki harfi \*\*aynı\*\* olmalı (uyumlu kesişim — çatışma = geçersiz).

# \- `clue\_cell` tipi `clue` olmalı ve ilgili `word\_id`'yi içermeli.

# \- `safety.post\_fill\_scanned == true` değilse dosya yazılmaz (§6.4, korunan kural).

# \- Türkçe upper-case: tüm `answer` ve `solution` `tr\_upper` formatında.

# 

# \---

# 

# \## 5. Mask Template Sistemi

# 

# \### 5.1 Neden Şablon? (Strateji 1)

# Akademik literatür (Engel 2009, TU München): İskandinav crossword üretimi iki problemdir —

# (1) \*\*mask\*\* (hücre yerleşimi + ok yönleri) ve (2) \*\*fill\*\* (kelime doldurma). Mask üretimi

# zordur ve otomatik çözümler düşük kalitelidir; fill ise çözülmüş bir CSP problemidir.

# 

# \*\*Kararımız:\*\* Mask'leri \*\*elle/yarı-elle tasarla\*\* (Strateji 1 + hibrit-C: Claude Code taslak

# üretir, kullanıcı seçer/düzeltir), fill'i \*\*CSP ile otomatik\*\* yap.

# 

# \### 5.2 Çeşitlilik Stratejisi (Tek-tip mask sorununun çözümü)

# İki katman:

# 1\. \*\*Çok şablon\*\*: 3 boyut × \~15+ şablon = 45+ elle şablon. Bilinçli çeşitlilik

# &#x20;  (sağ kolonda bazen tek uzun kelime, bazen 2-3 kısa; ipucu hücreleri farklı noktalarda).

# 2\. \*\*Transform\*\*: Her şablon → yatay ayna + 180° döndürme ile \~3-4 varyant.

# &#x20;  45 şablon → \~150 efektif mask. (Transform `mask\_template.py`'de otomatik.)

# 3\. \*\*Çok dolum\*\*: Her mask farklı kelime setiyle defalarca dolar → yüzlerce bölüm.

# 

# \### 5.3 Boyutlar

# | Tip | Grid | Kelime (hedef) | Oturum | Kullanım |

# |-----|------|----------------|--------|----------|

# | \*\*small\*\* | 6×5 | 6-8 | 2-3 dk | İlk bölümler, günlük hızlı |

# | \*\*medium\*\* | 8×6 | 9-12 | 4-5 dk | Ana akış |

# | \*\*large\*\* | 10×7 | 13-16 | 6-8 dk | Zor/hafta sonu |

# 

# \### 5.4 Mask Şablon Formatı (`templates/medium\_03.json`)

# Mask, \*\*çözüm harflerini içermez\*\* — sadece hücre tiplerini ve ok yönlerini tanımlar.

# CSP filler daha sonra `solution` ve `answer` alanlarını doldurur.

# 

# ```json

# {

# &#x20; "template\_id": "medium\_03",

# &#x20; "size": "medium",

# &#x20; "grid": { "rows": 8, "cols": 6 },

# &#x20; "cells": \[

# &#x20;   { "row": 0, "col": 1, "type": "clue", "clues": \[ { "arrow": "down", "slot\_id": "s1" } ] },

# &#x20;   { "row": 0, "col": 4, "type": "clue", "image\_slot": true,

# &#x20;     "clues": \[ { "arrow": "down", "slot\_id": "s3" } ] },

# &#x20;   { "row": 2, "col": 3, "type": "clue",

# &#x20;     "clues": \[ { "arrow": "right", "slot\_id": "s4" }, { "arrow": "down", "slot\_id": "s5" } ] },

# &#x20;   { "row": 1, "col": 1, "type": "letter" },

# &#x20;   { "row": 5, "col": 2, "type": "blank" }

# &#x20; ],

# &#x20; "slots": \[

# &#x20;   { "slot\_id": "s1", "direction": "down",  "clue\_cell": {"row":0,"col":1},

# &#x20;     "cells": \[ {"row":1,"col":1}, {"row":2,"col":1}, {"row":3,"col":1} ], "length": 3 }

# &#x20; ],

# &#x20; "transformable": true

# }

# ```

# \- `slot`: doldurulacak bir kelime yuvası (uzunluk + hücreler + yön). CSP'nin "değişken"i.

# \- `slot\_id`: ipucu ↔ slot bağlantısı.

# \- `image\_slot: true`: bu ipucunun görsel olabileceğini işaretler (FAZ ileri).

# \- `transformable`: ayna/döndürme uygulanabilir mi (asimetrik dekorlar için false olabilir).

# 

# \### 5.5 Transform (mask\_template.py)

# \- `mirror\_horizontal(mask)`: sütunları ters çevir, ok yönlerini ayarla (right ↔ ... dikkat:

# &#x20; right aynalanınca sol-kaynak olur; İskandinav'da sadece right/down olduğu için ayna

# &#x20; sonrası ok yönü yeniden hesaplanır — geçersiz olanlar elenir).

# \- `rotate\_180(mask)`: hem satır hem sütun ters; right→(left geçersiz) olacağından

# &#x20; rotate\_180 yalnızca right+down simetrisi korunan şablonlarda uygulanır.

# \- \*\*Kritik:\*\* Transform sonrası mask `validate\_mask()` ile doğrulanır; geçersiz ok

# &#x20; yönü üreten transformlar atılır. (Sadece right/down kısıtı korunmalı.)

# 

# \### 5.6 Şablon Tasarım Süreci (hibrit-C)

# 1\. Claude Code, `templates/` altına boyut başına taslak şablonlar üretir (kurallı:

# &#x20;  kenarlardan ok, çeşitli slot dağılımları).

# 2\. Kullanıcı, Cross Up ekran görüntülerine bakarak en iyi şablonları seçer/düzeltir.

# 3\. Onaylanan şablonlar repoya girer.

# 

# \### 5.7 Otomatik Mask Sentezi + "Kenar Incidental" Gerçeği (Sınır İmkânsızlık Teoremi)

# 

# `mask\_synth.py` elle şablonlara ek olarak şablonları \*\*otomatik\*\* (deterministik, seed'li) üretir.

# Tasarımın temelinde şu kanıtlanmış gerçek yatar:

# 

# \*\*Sınır İmkânsızlık Teoremi.\*\* "blank=0 (tam dolu) + HER harf dizisinin grid-içi clue-head'i

# var (incidental dizi YOK) + min uzunluk 3 + kelimeler kesişir (connected)" — bu dört kısıt

# \*\*aynı anda tutulamaz\*\*, grid boyutundan bağımsız. Kanıt (sol-üst köşe): bir yatay run'ın

# head'i solunda, dikey run'ın head'i üstündedir; dolayısıyla col 0'da başlayan yatay run ve

# row 0'da başlayan dikey run \*\*grid dışında\*\* head ister → head'siz. Köşe (0,0) harf olamaz

# (iki yönü de head'siz → öksüz), clue olmalı; ama clue olunca ya barren kalır ya da onu

# besleyecek kelime row 2 / col 1'de kaçınılmaz bir \*\*head'siz kenar run'ı\*\* doğurur. Hangi

# yapı denenirse denensin köşe çelişki üretir. ∎

# 

# \*\*Sonuç (kabul edilen model — "loose"):\*\* Gerçek İskandinav çengelinde olduğu gibi, grid

# \*\*kenarındaki\*\* hücreler "unchecked" olabilir (yalnızca tek yöne ait). Yani:

# \- \*\*Interior run\*\* (start ≥ 1, yani başının solunda/üstünde grid-içi hücre var): \*\*slot\*\*'tur;

# &#x20; clue-head'i vardır, uzunluğu 3–8 \*\*(HARD)\*\*.

# \- \*\*Edge-start run\*\* (col 0 / row 0'da başlayan): \*\*incidental\*\* — slot değildir, clue'su yoktur,

# &#x20; uzunluk kısıtsızdır; her hücresi \*\*dik yöndeki bir interior slot\*\* tarafından kaplanmalıdır.

# \- Öksüz yok (her harf ≥1 interior slot'ta), barren yok (her clue ≥1 slot başlatır),

# &#x20; length-2 interior yasak, \*\*min kesişim ≥ slot\_sayısı/2\*\* (HARD).

# \- blank=0 KORUNUR (kenar farkı "blank" değildir; o hücreler de harf/clue'dur, sadece o

# &#x20; bölgedeki bazı diziler clue'suzdur — Cross Up'ın kenar davranışının ta kendisi).

# 

# \*\*Connectivity bulgusu (üçüncü sınır sonucu):\*\* "Tüm slot'lar TEK bağlı bileşen" hedefi de

# blank=0 + min-3 + no-orphan altında \*\*infeasible\*\*. 6×6 exhaustive (tam tarama) → 0 tek-bileşen

# geçerli grid; 8×6/9×6'da constructive en iyi \*\*2 bileşen\*\* (nadir), tipik 3-5. Neden: gerçek

# İskandinav çengeli 2-harfli kelimeler + daha gevşek "unchecked" sayesinde bağlanır; min-3 kuralı

# tüm slot'ları tek bileşende zincirlemeyi engeller. \*\*Uzlaşma:\*\* "tek bileşen" HARD kısıtı yerine

# \*\*`bileşen ≤ max_components` (default 3, görsel incelemeyle ayarlanır)\*\* kullanılır; `min_crossings`

# HARD kalır. (max\_components=2 ulaşılabilir ama nadir → düşük yield.)

# 

# \*\*Üreteç yaklaşımı (kesişim-önce constructive):\*\* Serbest CLUE/LETTER DFS ve reading-order

# constructive \*\*elendi\*\* (deneysel: ~0 connected çözüm). Doğru yöntem: önce interlocking

# across+down \*\*iskeleti\*\* yerleştir (kesişimler kasıtlı), sonra frontier-backtracking ile grid'i

# doldur, en son tüm kısıtları + min-kesişim'i doğrula; başarısızsa farklı seed ile yeniden dene.

# 

# \### 5.8 Dördüncü Sınır Sonucu — "Solid Blok Kaçınılmazlığı" ve min-1 Çözümü

# 

# \*\*Bulgu.\*\* blank=0 + \*\*min uzunluk 3\*\* ⟹ \*\*dolu (solid) harf bloğu KAÇINILMAZ.\*\* 6×6 exhaustive

# (tam tarama): 218 geçerli min-3 grid'in \*\*tamamında\*\* ≥3×3 tam-harf dikdörtgeni var, no-block

# olan SIFIR. Yani min-3 ile her tam-dolu grid "word-search" görünümüne mahkûm; gerçek Cross Up'ın

# serpiştirilmiş, değişik-uzunlukta görünümü min-3 ile imkânsız.

# 

# \*\*Çözüm (kabul edilen): min uzunluk 3 → 1.\*\* Tek-harf (simge: "Azotun simgesi"→N) ve 2-harf

# kelimeler slot olarak serbest. Kanıt: 6×6'da blank=0 + min-1 + no-3×3-blok \*\*209,583\*\* geçerli

# grid (5×5 tam tarama) — fizibıl ve bol. interior run geçerlik kuralı \*\*1≤len≤8\*\* (length-1/2

# artık valid slot); length-1 → symbols havuzu, length-2 → 2-harf havuz, 3-8 → ana havuz.

# 

# \*\*Aşırı-parçalanma karşı dengesi (length-bias).\*\* min-1 kontrolsüz bırakılırsa grid "nokta-nokta"

# olur (8+ bileşen, çok tek-harf). Bu yüzden:

# \- \*\*Length dağılım bias'ı:\*\* 3-5 ağır (çoğunluk), 6-8 ılımlı (birkaç uzun), 1-2 nadir.

# \- \*\*Tek/çift-harf slot tavanı\*\* (`max_len1_slots`, `max_len2_slots` ≈ 3) → dottiness engellenir.

# \- \*\*No-3×3-blok\*\* fill sırasında budanır (min-1 ile kısa slot bloğu kırabildiğinden fizibıl).

# \- Ölçülen denge (8×6): slot ~16-18, clue oranı ~0.25-0.30, L3-5 baskın, L6-8 0-2, bileşen ≤4.

# \- \*\*Clue oranı bandı 0.25-0.40\*\* (önceki 0.30-0.40 tahmini deneysel olarak yüksek çıktı:

# &#x20; no-block+dengeli grid'ler doğal olarak ~0.27'de kümeleniyor).

# 

# \---

# 

# \## 6. CSP Fill Algoritması (Python)

# 

# \### 6.1 Problem Tanımı

# Verilen bir \*\*mask\*\* (slot'lar = değişkenler) ve \*\*kelime havuzu\*\* (domain) için, her slot'a

# uzunluğu uyan bir kelime ata; kesişen slot'lar kesişim noktasında \*\*aynı harfi\*\* paylaşsın.

# Bu klasik bir Constraint Satisfaction Problem'dir (referans: Harvard CS50 crossword,

# N1SL/CrosswordGeneratorCSP, AhmadYahya97/CrosswordsGeneration).

# 

# \### 6.2 Bileşenler

# \- \*\*Değişkenler (variables):\*\* mask'teki slot'lar.

# \- \*\*Domain:\*\* her slot için, word\_pool'dan uzunluğu eşleşen kelimeler.

# \- \*\*Unary constraint:\*\* kelime uzunluğu == slot uzunluğu; tüm kelimeler farklı (bir bulmacada

# &#x20; tekrar yok).

# \- \*\*Binary constraint (arc):\*\* iki slot kesişiyorsa, kesişim hücresindeki harfler eşit.

# 

# \### 6.3 Algoritma (csp\_filler.py)

# ```

# def fill\_mask(mask, word\_pool, blacklist) -> FilledPuzzle | None:

# &#x20;   1. Node consistency: her slot domain'ini uzunluğa göre filtrele.

# &#x20;   2. AC-3: arc-consistency uygula, kesişim kısıtıyla domain'leri daralt.

# &#x20;      (kesişen slot çiftleri için desteklenmeyen kelimeleri at)

# &#x20;   3. Backtracking search:

# &#x20;      - MRV heuristic: en az domain'li slot'u seç (minimum remaining values)

# &#x20;      - Degree heuristic: eşitlikte en çok kesişimi olanı seç

# &#x20;      - LCV: kelime sıralamasında en az kısıtlayanı dene (least constraining value)

# &#x20;      - Her atamada forward-check (komşu domain boşalırsa geri al)

# &#x20;   4. Tüm slot'lar atanınca → FilledPuzzle (solution harfleri grid'e yazılır)

# &#x20;   5. Çözüm yoksa None

# ```

# \- Kelime seçimi `frequency\_score` ile ağırlıklandırılabilir (kolay bölümde yüksek frekanslı

# &#x20; kelimeleri tercih et → difficulty kontrolü).

# \- \*\*Tek-harf slot desteği:\*\* length=1 slot'lar için domain, kelime havuzundan değil

# &#x20; \*\*sembol/kısaltma havuzundan\*\* gelir (§6.5).

# 

# \### 6.4 Güvenlik (post\_fill\_safety — KORUNDU, uyarlandı)

# \- Mask dolduktan sonra, grid'de oluşan \*\*tüm yatay+dikey diziler\*\* (kesintisiz harf

# &#x20; segmentleri) küfür taramasından geçer (`scan\_grid`, v1.4'ten korunan 8-yön mantığı —

# &#x20; ama burada sadece right/down olduğu için yatay+dikey yeterli; çapraz opsiyonel kapatılır).

# \- Bir küfür segmenti bulunursa → bu fill REDDEDİLİR, CSP yeniden denenir (farklı kelime seti).

# \- `safety.post\_fill\_scanned = true` olmayan bölüm asla yazılmaz (sessiz başarı yasak,

# &#x20; `SafetyGenerationError` + `sys.exit(1)`).

# \- \*\*Fark:\*\* v3'teki rastgele dolgu artık YOK — tüm hücreler gerçek kelimelerin harfi.

# &#x20; Yine de kesişen kelimeler istenmeyen bir dizi oluşturabilir, o yüzden tarama korunur.

# 

# \### 6.5 Tek-Harf / Sembol Havuzu (YENİ — küçük, elle)

# `data/symbols.json`: tek hücrelik cevaplar için küçük küratörlü liste.

# ```json

# \[

# &#x20; { "answer": "C", "clue": "ÜÇÜNCÜ HARFİMİZ" },

# &#x20; { "answer": "Ç", "clue": "NOKTALI KUYRUK" },

# &#x20; { "answer": "O", "clue": "OKSİJEN SİMGESİ" }

# ]

# ```

# Bu liste elle hazırlanır (TDK'dan gelmez). CSP, length=1 slot'lara buradan atar.

# 

# \### 6.6 3-Katmanlı Retry (generator.py — v1.6'dan korunan desen)

# ```

# for mask\_attempt in range(MAX\_MASK\_RESELECTS=5):       # farklı mask dene

# &#x20;   mask = pick\_mask(size)  (+ rastgele transform)

# &#x20;   for fill\_attempt in range(MAX\_FILL\_ATTEMPTS=20):   # CSP'yi farklı seed'le dene

# &#x20;       result = fill\_mask(mask, word\_pool, blacklist)

# &#x20;       if result and post\_fill\_safe(result):

# &#x20;           return build\_puzzle(result, ...)

# raise PuzzleGenerationError → sys.exit(1)

# ```

# 

# \---

# 

# \## 7. İpucu Sistemi (TDK → LLM → Placeholder)

# 

# \### 7.1 İki Aşama

# \*\*Aşama 1 (ŞİMDİ):\*\* TDK'dan kısa tanım çek → word\_pool'a `tdk\_definition` alanı ekle.

# Tanım yoksa/uygunsuzsa → placeholder.

# \*\*Aşama 2 (SONRA, ayrı adım):\*\* LLM ile TDK tanımını telif-temiz, kısa, kelimeyi ele

# vermeyen ipucuna çevir.

# 

# \### 7.2 Telif Notu (KRİTİK)

# TDK \*\*kelime listesi\*\* kamu malıdır; \*\*tanım metinleri\*\* TDK telifindedir. Bu yüzden TDK

# tanımı oyunda \*\*doğrudan kullanılmaz\*\* — sadece LLM'e girdi olur, LLM baştan yazar.

# Aama 1'de bölüm dosyasına yazılan ipucu ya placeholder ya (geçici, dahili) TDK olabilir;

# \*\*yayına çıkan ipuçları Aşama 2'den (LLM) gelir.\*\* `clue.source` bunu izler.

# 

# \### 7.3 Placeholder Formatı (clue\_writer.py — Aşama 1 fallback)

# ```

# "{length} harfli kelime"            # en basit

# \# veya kategori bilgisi varsa:

# "{length} harfli bir {kategori}"

# ```

# 

# \### 7.4 TDK Tanım Çekme (Aşama 1)

# \- Kaynak: TDK Sözlük (resmi API yoksa nazik crawler, rate-limit'li).

# \- Filtre: tanım kelimenin kendisini içeriyorsa at; çok uzunsa kırp; teknik/müstehcen tanımları ele.

# \- Çıktı: `word\_pool\_cleaned.json`'a `tdk\_definition` alanı (opsiyonel).

# \- \*\*Bu adım MVP'yi bloklamaz\*\* — placeholder ile bölüm üretimi çalışır, ipuçları sonra zenginleşir.

# 

# \### 7.5 Görsel İpuçları (FAZ İLERİ — MVP'de YOK)

# \- `image\_slot: true` olan slot'lar ileride `clue\_images/` altındaki görsellerle eşlenir.

# \- MVP'de bu slot'lar da metin ipucu kullanır (`image\_id: null`).

# 

# \---

# 

# \## 8. Flutter Runtime: GameBloc + Skor Motoru

# 

# \### 8.1 GameBloc — Sıra-Tabanlı State Machine

# \*\*Events:\*\*

# ```

# LoadPuzzle(puzzleId)            // bölüm + bot profili yükle

# SelectWord(wordId)             // ipucu/hücreye dokun → kelime vurgula

# PlaceLetter(rackIndex, cell)   // rack'ten harfi hücreye koy

# RecallLetter(cell)             // konan harfi rack'e geri al

# ConfirmMove()                  // "Onayla" → doğrula, puanla, sıra bota

# PassMove()                     // "Pas" → sıra bota (harf konmadıysa)

# SwapLetters(indices)           // "Değiştir" (reklam sonrası)

# RevealWord(wordId)             // "Kelimeyi Aç" (reklam sonrası)

# UnlockSixthSlot()              // 6. harf yuvası (reklam sonrası)

# BotMoveCompleted(botMove)      // bot hamlesi bitti → sıra oyuncuya

# ```

# \*\*State (GameState):\*\*

# ```

# PuzzleData puzzle              // immutable bölüm verisi

# Map<Cell,PlacedLetter> board   // tahtanın güncel durumu (kalıcı + geçici)

# List<RackTile> rack            // eldeki harfler (boş yuva dahil)

# List<Cell> pendingPlacements   // bu turda konan, henüz onaylanmamış harfler

# int playerScore, botScore

# TurnPhase phase                // playerTurn | resolving | botTurn | finished

# String? highlightedWordId

# GameStatus status              // playing | won | lost | draw

# ```

# 

# \### 8.2 ScoreEngine (saf Dart)

# ```

# class ScoreEngine {

# &#x20; // Bir onaylanan hamledeki tüm puanları hesaplar.

# &#x20; MoveResult resolveMove({

# &#x20;   required List<Placement> placements,   // bu turda konan harfler

# &#x20;   required PuzzleData puzzle,

# &#x20;   required Map<Cell,PlacedLetter> board,

# &#x20;   required int rackStartCount,           // tur başı rack (5 veya 6)

# &#x20; });

# &#x20; // Döner: doğru harf sayısı (+1 her biri), yanlışlar (−1),

# &#x20; //        tamamlanan kelimeler (uzunluk bonusu),

# &#x20; //        el boşaldı mı (+5/+6 bonusu),

# &#x20; //        toplam delta + animasyon olayları (her hücre için +1/−1/+N etiketi)

# }

# ```

# Kurallar §1.4'ten birebir. Yanlış harf → board'a koyma, rack'e iade işaretle.

# 

# \### 8.3 RackManager (saf Dart)

# \- Tur başı rack doldurma (5 veya 6).

# \- Yanlış iade edilen harfi koruma (bir sonraki turda kalır).

# \- Harf dağıtımı: tahtada \*\*henüz çözülmemiş hücrelerin\*\* çözüm harflerinden ağırlıklı

# &#x20; rastgele seçim (oyuncunun ilerleyebilmesini garanti eder; tamamen rastgele değil).

# \- Swap: seçili harfleri havuza iade, yenilerini çek.

# 

# \---

# 

# \## 9. Flutter Runtime: AI Rakip (Bot)

# 

# \### 9.1 Bot Davranışı (BotEngine, saf Dart)

# \- Sıra bota geçince çağrılır; tahtadaki \*\*çözülmemiş hücrelerden\*\* kendi hamlesini üretir.

# \- Bot, oyuncunun rack'inden bağımsızdır — kendi "bildiği" harfleri doğrudan tahtaya koyar.

# \- Hamle büyüklüğü zorluğa göre değişir (kaç harf koyacağı).

# \- Oyunun sonuna doğru, kalan boşlukları kapatma eğilimi artar (agresifleşir).

# 

# \### 9.2 Zorluk Eğrisi (Bölüm Bazlı — kullanıcı tanımı)

# Döngüsel, her 20 bölümde bir tekrar:

# ```

# Bölüm % 20:

# &#x20; 1-5   → kolay   (bot az harf koyar, bazen yanlış/atlar, oyuncuya alan bırakır)

# &#x20; 6-15  → orta    (dengeli)

# &#x20; 16-20 → zor     (bot çok harf koyar, hızlı, son boşlukları kapar)

# ```

# `BotProfile` modeli: `{ id, name, avatar, description, difficultyBand }`.

# Günlük rakip seçimi `matchmaking` feature'ında; difficultyBand bölüm numarasından türetilir.

# 

# \### 9.3 Bot "Hile" Sınırı

# Bot her zaman doğru harf koyar (yanlış koyma simülasyonu sadece "kolay" seviyede, alan

# bırakmak için kasıtlı atlama olarak modellenir). Bot, çözümü bildiği için adildir —

# zorluk, \*\*kaç hücre ve hangi hızda\*\* kapattığıyla ayarlanır, çözümü bilip bilmemesiyle değil.

# 

# \### 9.4 Dinamik Zorluk (Rubber-Banding)

# Statik band (§9.2) \*\*taban çizgisidir\*\*; bot hamle seçerken anlık skor farkına göre band

# \*\*içinde\*\* kayar. Amaç: rekabeti hep zirvede tutmak.

# 

# ```

# skorFarkı = botScore - playerScore

# Bot, tahtadaki olası hamleleri bulur, sonra:

# &#x20; - Bot ÖNDEYSE (skorFarkı > 0):  daha kısa/düşük puanlı hamle seç (oyuncuya nefes)

# &#x20; - Bot GERİDEYSE (skorFarkı < 0): en yüksek puanlı hamleyi seç (acımasız)

# &#x20; - Başa başsa: band'ın varsayılan davranışı

# ```

# 

# \*\*KRİTİK DENGE — aşırı rubber-banding hissedilmemeli:\*\*

# \- Ayar, \*\*zorluk band'ı içinde\*\* sınırlanır (clamp). Kolay bölümde yumuşak aralık,

# &#x20; zor bölümde geniş aralık. Bot asla tamamen aptallaşmaz veya "tanrı" olmaz.

# \- \*\*Tavan/taban:\*\* her band için min/max agresiflik tanımlı; rubber-banding bu sınırlar

# &#x20; arasında interpolasyon yapar. Oyuncu "bot hep bana denk geliyor" diye sahtelik

# &#x20; hissetmemeli — bu yüzden ayar yumuşak ve sınırlı.

# \- `BotProfile.difficultyBand` taban davranışı belirler; rubber-banding üstüne ince ayar.

# 

# \### 9.5 İnsansı Gecikme (Humanized Delay)

# Sıra bota geçince anında hamle yapmak mekanik/sinir bozucu hissettirir. Bot hamlesi

# \*\*hesaplanır ama gösterimi geciktirilir\*\*:

# 

# ```

# GameBloc akışı (sıra bota geçince):

# &#x20; 1. emit(phase = botTurn, botThinking = true)

# &#x20;      → UI: "Sokrates düşünüyor..." + avatar etrafında animasyon

# &#x20; 2. Bot hamlesi HEMEN hesaplanır (BotEngine, UI donmaz)

# &#x20; 3. await Future.delayed(random 2-5 sn)   // sadece GÖSTERİM gecikmesi

# &#x20; 4. add(BotMoveCompleted(move))

# &#x20;      → harfler tahtaya yerleşir, bot skoru artar, sıra oyuncuya

# ```

# \- Gecikme \*\*rastgele 2-5 sn\*\* (her seferinde sabit değil → daha insansı).

# \- Hesaplama gecikmeden önce yapılır; gecikme yalnızca dramatik bekleme içindir.

# 

# \---

# 

# \## 10. Flutter Runtime: Harf Yerleştirme + Animasyon

# 

# \### 10.1 Grid Çizimi (GridPainter — CustomPainter)

# \- \*\*İki katmanlı painter:\*\*

# &#x20; - Statik katman: grid çizgileri, ipucu hücreleri (metin/ok/yeşil zemin), kalıcı harfler.

# &#x20; - Dinamik katman: vurgulanan kelime (gri highlight), geçici harfler, puan rozetleri.

# \- `shouldRepaint`: yalnızca ilgili katman değiştiğinde true.

# \- Tek `GestureDetector` → hücre koordinatına çevir (hit-test), Bloc'a event.

# \- Scrollable + (opsiyonel) zoomable: `InteractiveViewer` ile sarmalanır (large grid için).

# \- Türkçe karakter render: `Inter`/`Nunito` (Latin-Extended) ile Ş/Ç kuyrukları doğru.

# 

# \### 10.2 Harf Uçma Animasyonu (Overlay tabanlı)

# \*\*Yaklaşım: Overlay + AnimatedPositioned (Hero DEĞİL).\*\*

# Gerekçe: Hero route-geçişleri içindir; burada aynı ekranda rack→grid uçuşu var.

# ```

# 1\. Oyuncu rack tile'a dokunur (veya hedef hücreye sürükler).

# 2\. Tile'ın global pozisyonu + hedef hücre global pozisyonu hesaplanır.

# 3\. OverlayEntry ile uçan bir harf widget'ı eklenir.

# 4\. AnimationController (200-300ms, Curves.easeOutBack) ile pozisyon tween'lenir.

# 5\. Animasyon bitince Overlay kaldırılır, Bloc'a PlaceLetter event'i gider,

# &#x20;  harf grid'de "geçici" olarak görünür.

# ```

# \- Puan rozetleri ("+1", "+N", "−1"): hücre üstünde kısa Overlay animasyonu (yükselip solma).

# \- Onay sonrası "Harikasın 🚀 +5" toast: ekran ortasında AnimatedOpacity+Scale banner.

# \- Konfeti (kazanınca): `confetti` paketi (zaten pubspec'te).

# 

# \### 10.3 Performans Bütçesi

# \- Idle (animasyon yokken): 0 repaint hedefi.

# \- Cold start < 2.5 sn, oynanış ≥ 60 fps.

# 

# \---

# 

# \## 11. Veri Saklama (Hive) + Resume

# 

# \### 11.1 Box'lar

# | Box | İçerik | Şifreli? |

# |-----|--------|----------|

# | `active\_game` | yarım kalan oyun durumu (resume) | \*\*AES\*\* |

# | `progress` | tamamlanan bölümler, seri, kazanma sayısı | \*\*AES\*\* |

# | `coin\_wallet` | coin bakiyesi | \*\*AES\*\* |

# | `iap\_state` | reklamsız satın alma durumu | \*\*AES\*\* |

# | `ad\_state` | reklam frequency cap zaman damgaları | \*\*AES\*\* |

# | `settings` | ses, tema vb. (shared\_preferences de olabilir) | hayır |

# 

# AES anahtarı: `flutter\_secure\_storage` → `SecureHive.cipher()` (v3'ten korunan desen).

# 

# \### 11.2 Resume + Save-Scumming Önlemi

# \- `active\_game` ve `progress`, \*\*hem oyuncu hem bot hamlesinden sonra ANINDA\*\* yazılır

# &#x20; (bu iki box için debounce YOK — save-scumming önlemi).

# \- Yazım \*\*senkron ve UI güncellemesinden ÖNCE\*\*: önce şifreli kaydet, sonra ekranı güncelle.

# &#x20; Böylece "force kill" ile son hamleyi geri almak zorlaşır.

# \- Ek olarak `AppLifecycleListener` (onPause/onInactive) ile son durum garanti flush.

# \- İçerik: board durumu, rack, skorlar, sıra fazı, bölüm id, bot durumu, skor geçmişi.

# \- Oyun bitince `active\_game` temizlenir; `progress` güncellenir (seri, kazanma).

# \- AndroidManifest `allowBackup="false"` (reinstall çökmesi önlemi).

# 

# > \*\*DÜRÜST GÜVENLİK NOTU:\*\* AES şifreleme + anında flush, save-scumming'i \*makul ölçüde

# > zorlaştırır\* ama \*\*%100 engellemez\*\*. Kararlı bir kullanıcı flush anından önce force-kill

# > edebilir. Tam koruma sunucu-otoritesi (online) gerektirir → MVP DIŞI. Hedefimiz "kolay

# > istismarı engellemek", "kırılamaz" değil. Şifreleme ayrıca JSON box'ların düz metin

# > okunup düzenlenmesini (coin/skor hilesi) engeller.

# 

# \---

# 

# \## 12. Reklam ve Monetizasyon

# 

# \### 12.1 Reklam Yerleşimleri (videodan doğrulanmış)

# | Tip | Yer | Kural |

# |-----|-----|-------|

# | \*\*Banner\*\* | Oyun ekranı alt + ana menü alt | Reklamsız satın alınca kalkar |

# | \*\*Interstitial\*\* | Bölüm/oyun arası (oyun bitince) | Oyun ESNASINDA yok; min 90 sn cap; reklamsız'da kalkar |

# | \*\*Rewarded\*\* | "Kelime" (ipucu aç), "Değiştir" (harf değiştir), 6. harf yuvası | Reklamsız'da AKTİF kalır |

# 

# \### 12.2 Kurallar (KORUNDU, v3'ten)

# \- İlk 3 bölüm: hiç reklam yok.

# \- Consent (UMP) → reklam SDK'sı başlatılmadan önce.

# \- `AdService` interface ağ-bağımsız; MVP impl `admob\_ad\_service.dart` (+ `mock\_ad\_service`).

# \- Test reklam ID'leri production'a sızmamalı: `AdUnitIds.assertNoTestIdsInRelease()`.

# \- AppLovin mediation v1.1+'a ertelendi.

# 

# \---

# 

# \## 13. Korunan / Atılan Kod Tablosu

# 

# | Bileşen | Durum | Not |

# |---------|-------|-----|

# | `word\_pool.py` | ✅ \*\*KORUNDU\*\* | Türkçe filtre, küfür, frekans — aynen kullanılır |

# | `data/raw/tdk\_words.txt`, `profanity\_blacklist.txt` | ✅ KORUNDU | Kaynak veri |

# | `post\_fill\_safety.py` (scan\_grid) | ✅ KORUNDU (uyarlanır) | Sadece yatay+dikey; rastgele dolgu kısmı çıkar |

# | `schema.py` (pydantic altyapısı) | 🔄 YENİDEN | v2 şema (cells/clues/words) — yapı korunur, içerik yeni |

# | `difficulty.py` | 🔄 UYARLANIR | Yeni faktörler (slot sayısı, ipucu zorluğu, frekans) |

# | `\_\_main\_\_.py` (typer CLI iskeleti) | ✅ KORUNDU (komut güncellenir) | `generate` mantığı değişir |

# | `word\_search\_generator.py` | ❌ \*\*ATILDI\*\* | Yerine CSP filler |

# | Eski JSON şema (grid: harfli matris) | ❌ ATILDI | Yerine v2 (cells + words) |

# | `hint\_writer.py` (placeholder) | 🔄 → `clue\_writer.py` | İpucu mantığı genişler |

# | 196 üretilmiş word-search level | ❌ ATILDI | Yeni şemayla yeniden üretilecek |

# | Flutter iskelet (main/app/core/theme/router) | ✅ \*\*KORUNDU\*\* | Aynen kullanılır |

# | Flutter `AppColors/Typography/Dimensions/Result/Logger` | ✅ KORUNDU | Aynen |

# | `pubspec.yaml` tech stack | ✅ KORUNDU | Flame yok, mevcut paketler yeterli |

# 

# \*\*Yeni yazılacaklar:\*\* `mask\_template.py`, `csp\_filler.py`, `clue\_writer.py` (genişletilmiş),

# `templates/\*.json` (elle), `data/symbols.json`, ve tüm `features/gameplay` runtime

# (GameBloc, ScoreEngine, BotEngine, RackManager, GridPainter, animasyonlar).

# 

# \---

# 

# \## 14. Türkçe Dil Kuralları (KORUNDU)

# \- `tr\_upper()` / `tr\_lower()`: `i↔İ`, `ı↔I` doğru. `str.upper()` YASAK.

# \- Tüm `answer`/`solution` üretimde `tr\_upper` ile normalize.

# \- Q, W, X kelime havuzunda yok (word\_pool filtresi).

# \- Flutter render: Latin-Extended font (Inter/Nunito) → Ş, Ç, Ğ kuyrukları doğru.

# \- Windows konsol: `\_force\_utf8\_stdout()` yalnızca CLI giriş noktasında.

# 

# \---

# 

# \## 15. Üretim Hattı Özeti (Pipeline)

# 

# \### Python (bölüm üretimi — offline)

# ```

# 1\. word\_pool.py        → word\_pool\_cleaned.json  (KORUNDU)

# 2\. (Aşama1) clue: TDK tanım çek → word\_pool'a ekle (opsiyonel, MVP placeholder)

# 3\. mask\_template.py    → templates/\*.json yükle + transform → mask havuzu

# 4\. csp\_filler.py       → mask'i word\_pool'dan doldur (AC-3 + backtracking)

# 5\. post\_fill\_safety    → küfür tara (yatay+dikey)

# 6\. clue\_writer.py      → her kelimeye ipucu (placeholder/tdk/llm)

# 7\. difficulty.py       → difficulty\_score

# 8\. schema.py           → v2 JSON doğrula + yaz (safety flag zorunlu)

# 9\. build\_manifest.py   → manifest.json (KORUNDU, uyarlanır)

# &#x20;  → assets/puzzles/

# ```

# 

# \### Flutter (oynanış — runtime)

# ```

# LoadPuzzle → matchmaking (günlük bot) → GameScreen

# &#x20; → GameBloc (sıra-tabanlı) orkestratör:

# &#x20;      RackManager (harf dağıt) + ScoreEngine (puanla) + BotEngine (bot hamle)

# &#x20; → GridPainter (çiz) + Overlay (uçan harf, rozet, toast)

# &#x20; → her hamle: Hive active\_game flush (resume)

# &#x20; → tahta dolunca: result ekranı (basit özet)

# &#x20; → reklam: banner/interstitial/rewarded (AdService)

# ```

# 

# \### İlk Üretim Hedefi

# \- Önce \*\*medium\*\* boyutta \~10-15 mask şablonu + CSP fill → \~50 test bölümü.

# \- Doğrulama: tüm bölümler schema\_validator'dan geçer, küfür yok, çözülebilir.

# \- Sonra small + large eklenir, hedef 150-200 bölüm.

# 

# \---

# 

# > \*\*Bir sonraki adım:\*\* Bu doküman onaylanınca, `skills.md` ve `coding-standards.md`

# > v4.0'a uyumlanır (özellikle "Oyun Tasarımı" ve "Python pipeline" bölümleri), eski

# > `architecture.md` bununla değiştirilir, sonra Python tarafında ilk yeni modül

# > (`schema.py` v2) yazılır.

