# HANDOFF — Oturum E: Tasarım eksikleri turu + yayın öncesi kalite geçişi (2026-09-26)

Tasarım fazı bu oturumla **kapandı**: README'deki her ekran uygulamada var,
bilinçli sapmalar `docs/design/README.md` "Flutter sapmaları"nda kayıtlı.
Analiz 0 sorun, **316 test** yeşil, release APK temiz ilk açılışla emülatörde
doğrulandı. Önceki oturumlar: `HANDOFF_DESIGN_A..D.md`.

## Commit'ler

| Commit | Ne |
|---|---|
| `295ce59 fix(consent): ridge opacities per README` | `MountainBackdrop.alphas`; onayda mtn1 %70 / mtn2 %60 |
| `56c3115 feat(home): backdrop blur on the glass pill and save card` | `GlassSurface` (blur 6 / 8) |
| `4a05001 feat(narration): dashed flight arcs and the ↑ on the word badge` | `FlightArc`; rakip mavi, yanlış harf kırmızı yay; "+N ↑" |
| `f3008ad fix(a11y): text contrast ≥ 4.5:1` | `link` token, `light.error`, `dark.sheetMuted`, alfalar ≥ %66 |
| `c68d8f3 chore(l10n): onboarding demo glyphs from arb; drop dead routes` | lib/ altında UI literal 0; `/menu`, `/packs` silindi |
| `776b4bc feat(nav): system back lands somewhere sensible` | PopScope her rotada |
| `61a4085 feat(a11y): screen-reader labels` | `GridSemantics`, taş/buton etiketleri, pill live region |
| `8a3e582 fix(ui): large-font pass` | 1.3 / 1.6 ölçekte taşma yok; sabit geometri ölçeklenmez |
| `26ad2f3 fix(ui): compact game layout on short screens` | < 700 dp: taş 48, bar 44, boşluk 4 |
| `9057718 feat(settings): progress reset restarts the tutorial` | Sıfırla → `/onboarding?first=1` |

## 1. Tasarım eksikleri turu (HANDOFF_DESIGN_D tablosu)

Kapatılanlar: Consent sırt opaklıkları; Home blur; Game uçuş yayları ve
"+12 ↑". Tablo `HANDOFF_DESIGN_D.md`'de güncellendi.

Kalanlar ve gerekçeleri:

| Satır | Neden kapatılmadı |
|---|---|
| Onboarding 2–3 illüstrasyon | README'de spec yok; türetilen hâller (yerleşmiş harf / rakip harfi) duruyor. Tasarımcıdan spec gelince. |
| ATT madde metinleri | README'de metin yok; `attBody`'den türetildi (arb `attBullet1/2`). Metin onayı tasarımcıda. |
| Game ipucu font tablosu | **Bilinçli:** 9–14 px otomatik sığdırma + hece-tire (test edilmiş, clue-budget ile uyumlu). |
| Result "+40 m → X m" | **Bilinçli:** kampın irtifası. |
| Settings "Nasıl oynanır?" | README'de yok; oturum D isteğiyle eklendi (ek satır, sapma değil). |
| Shop fiyatları | Mağazadan gelecek (FAZ 6). |
| Legal gövde | İçerik işi; asset markdown'a yazılınca kodsuz güncellenir. |
| Store ekran görüntüsü çerçeveleri | Uygulama ekranı değil; mağaza pazarlama görseli (ayrı iş). |
| Ses / titreşim davranışı | FAZ 5. |

## 2. Native splash koyu tema

Zaten doğruydu: `values-night-v31/styles.xml` `windowSplashScreenBackground=#0b1a33`,
`drawable-night-v21/background.png` #0b1a33 (API < 31). Emülatörde
`cmd uimode night yes` ile doğrulandı: native splash zemini `#0b1a33`, ikon
dairesi `#1c3358`. Kullanıcının gördüğü krem flaş, cihaz **açık** modda
iken uygulama tercihi "Koyu" olduğunda oluşur — sistem splash'i uygulama
tercihini bilemez (kaçınılmaz; `ThemeMode.system` kullananda tutarlı).
Değişiklik gerekmedi.

## 3. Kalite geçişi

### a) Büyük yazı (1.3 / 1.6)
`test/features/quality/text_scale_test.dart` her ekranı iki ölçekte pump eder
(home, harita, oyun chrome'u, ipucu/swap sheet'leri, ayarlar, mağaza,
onboarding, sonuç). Bulunan ve düzeltilen taşmalar:
- Home: pill `Row` → `Wrap`; gövde `CustomScrollView` + `SliverFillRemaining`
  (taşınca kaydırır, sığınca `Spacer` davranışı aynı); marka adı 1.2× tavan.
- Harita: sis başlığı sabit 200 dp → `minHeight` 200.
- Sheet'ler: başlık satırı `Wrap`; gövde `Flexible` + `SingleChildScrollView`;
  swap seçenek butonları `minHeight` + `Wrap` etiket.
- Ayarlar: geniş kontrol (segmented pill) `FittedBox(scaleDown)`.
- Sonuç, onboarding: kaydırılabilir gövde.
- Sabit geometri `TextScaler.noScaling`: rack/uçan/ghost taş harfleri, rozet
  metni, harita düğüm numaraları, 7–8 px mikro etiketler (İPUCU AL, HARF EKLE,
  ▶ reklam, BURADASIN). Tahta painter'ları zaten etkilenmiyordu (TextPainter).
  Test: rack "K" `textScaler == noScaling`.

### b) Küçük ekran (360×640)
`test/features/quality/small_screen_test.dart`: 360×640'ta taşma yok, rack
kompakt, tahta hücresi ≥ 36 dp. Uygulama: `MediaQuery` yüksekliği < 700 dp
→ `_compact` (taş 52×48, bar 44, boşluklar 4). Emülatörde `wm size 1080x1920`
+ `density 480` ile ana ekran görüntülendi (sığıyor, blur'lu kartlar dahil);
oyun ekranı bu profilde yalnız widget testiyle doğrulandı (cihazda
görülmedi — kompakt rack/bar için ilk gözle kontrol iOS/QA turunda).

### c) Geri navigasyon (`test/features/nav/back_navigation_test.dart`)
- Oyun → "Haritaya dön?" onayı (⋯ menüsüyle ortak `confirmLeaveGame`).
- Sonuç → harita. Harita → ana. Ayarlar/mağaza/legal → pop.
- Splash, onay, ATT, ilk-açılış onboarding → geri yok sayılır; Ayarlar'dan
  açılan onboarding pop eder.

### d) Erişilebilirlik
- `GridSemantics`: her hücre bir düğüm (ipucu metni + yön, harf, bekleyen
  harf, boş hücre, logo köşesi); dokunuşu geçirir. Taşlar (harf / seçili /
  yerleşmiş), + HARF EKLE, ⇄, lamba etiketli buton; sıra pill'i live region.
- Kontrast (WCAG 4.5:1) hesaplandı (`python` ile); düzeltmeler: `link` token
  (#8f4f20, iki tema), `light.error` #ad3f2b, `dark.sheetMuted` #7e6045,
  ikincil metin alfaları ≥ %66. Sapmalar README'de.
- TalkBack ile gerçek cihaz akışı **denenmedi** (emülatörde TalkBack yok);
  semantics testleri `ensureSemantics` ile etiketleri doğrular.

### e) Hardcoded metin
`grep` sonucu lib/ altında yalnız onboarding şeridinin demo harfleri vardı →
arb'a taşındı (`onbDemo*`). "DEV" rozeti bilinçli olarak arb dışı.

### f) Akış (emülatör, release APK, `pm clear` sonrası)
Onay → onboarding (3 kart) → ana → Harita → geri → ana → "Bölüm 1 ile
başla" → oyun → geri → "Haritaya dön?" → harita → geri → ana ("Yarım kalan
oyun" kartı) → Ayarlar → Koyu (anında koyu) → Açık → Sistem → İlerlemeyi
sıfırla → Sil → onboarding. **Sonuç → tekrar** cihazda oynanmadı (bir maçı
adb ile bitirmek pratik değil); `result_screen_test` ve `back_navigation_test`
rotayı kapsıyor.

## Release doğrulama
`flutter build apk --release` (57.3 MB) → `adb install -r` → `pm clear` →
monkey → logcat: FATAL 0, `Displayed .../.MainActivity +456 ms`; akış
yukarıdaki gibi. Ekran görüntüleri oturum içinde incelendi (light + dark
ayarlar, gece splash örneklemesi).

## Açık kalanlar
- TalkBack gerçek cihaz turu; iOS simülatörü (ATT ekranı hiç görülmedi).
- Harita: 200 done kartı widget — kaydırma performansı ölçülmedi.
- Store ekran görüntüsü çerçeveleri (pazarlama).
- FAZ 5 ses/haptik, FAZ 6 gerçek SDK'lar, kamp parası harcama yolu.
