# HANDOFF — P1 re-clue ve havuz kalite kapısı (2026-09-13/14)

## Özet

- Küfür kara listesi geri geldi: `scripts/build_blacklist.py` (ooguz/turkce-kufur-karaliste,
  CC BY-SA 4.0), 601 giriş, en az 4 harf (gerekçe script docstring'inde). Commit 12956b0.
- Havuz kalite kapısı kalıcı: `rebuild_pool_from_master.py` flash-lite ipuçlu kelimeleri
  varsayılan dışlar (29.996 → 8.805). Commit 916d14f. CLAUDE.md kuralı eklendi.
- 16 hassas cevap emekli edildi, 17 bulmaca yeniden üretildi. Commit'ler 516094e, 1b73f29
  ve kapanış commit'i.
- Pack'teki flash-lite kalıntısı 135 kelimeden 122'si Claude ile yeniden ipuçlandı
  (`scripts/reclue_apply.py`, `source="claude_reclue"`, `model="claude-fable-5-1"`,
  eski metin `previous` alanında). 49 dosyada 123 ipucu metni güncellendi. Commit d468496.
- Doğrulama: pytest 157 yeşil, `flutter test` 167 yeşil, verify_pack ok (200 mask benzersiz,
  placeholder 0).

## Kuru koşu: kalite havuzu (q1) vs mevcut havuz (f1), 200 bölüm (2026-09-13)

Ölçüm scripti oturum scratchpad'inde kaldı (`dry_run.py`: generate_pack'i scan_grid ve CSP
guard sayaçlarıyla sardı). Çıktılar /tmp altındaydı, yeniden başlatmada silindi; tablo
oturum kaydından.

| metrik | kalite q1 | mevcut f1 |
|---|---|---|
| havuz (kombine, 1-8 harf) | 8779 | 29629 |
| başarılı / başarısız | 200 / 0 | 200 / 0 |
| 200-mask sınırına dayanan | 0 | 0 |
| ort. fill_attempts | 5.92 | 4.16 |
| maks fill_attempts | 145 | 40 |
| ort. mask fallback | 1.62 | 1.04 |
| maks mask fallback | 48 | 13 |
| fallback'lı puzzle | 82 | 87 |
| denenen mask (toplam) | 525 | 409 |
| node bütçesi aşımı | 984 | 631 |
| scan_grid reddi (blacklist) | 0 | 0 |
| CSP guard budaması | 1.957.556 | 1.824.784 |
| tekil kelime | 1596 | 1991 |
| süre (dk) | 141.3 | 232.9 |

Slot uzunluğu dağılımı (200 bölüm):

| uzunluk | kalite q1 | mevcut f1 | mevcut pack |
|---|---|---|---|
| 1 | 697 | 704 | 704 |
| 2 | 818 | 812 | 831 |
| 3 | 881 | 872 | 879 |
| 4 | 606 | 605 | 578 |
| 5 | 289 | 308 | 312 |
| 6 | 812 | 804 | 799 |
| 7 | 25 | 28 | 33 |
| 8 | 363 | 359 | 362 |

Sonuç: kapı yeterli. Kalite havuzu 200/200 doldurdu, hiçbir bulmaca 200-mask sınırına
yaklaşmadı (maks 48), blacklist hiçbir mask'i reddetmedi (CSP guard içinde yönlendiriyor).
Süre mevcut havuzdan kısa (domain küçük), fallback biraz yüksek. İkinci koşular (q2/f2)
önceki oturum kapanınca tamamlanmadı; q1/f1 tek örnek.

## Değişen bulmacalar

- Yeniden üretilen (geometri değişti): 9, 20, 29, 36, 39, 83, 106, 108, 114, 118, 119,
  147, 168, 169, 172, 181, 200.
- Yalnız ipucu metni değişen (geometri aynı): 1, 3, 11, 13, 16, 22, 25, 30, 31, 33, 35, 48, 52, 60, 62, 68, 69, 71, 77, 78, 79, 81, 82, 84, 85, 95, 104, 107, 113, 121, 124, 131, 136, 144, 149, 150, 157, 158, 166, 176, 177, 180, 183, 185, 190, 191, 194, 195, 200.

## Hassas listeye eklenenler (bölüm 8, sahip onayı)

LİVATA, NAZİZM, SADİSTÇE, KATLEDİŞ, MAKTUL, HARAKİRİ, ÇİŞ, LAVMAN, İBRANİ, ŞİA, Şİİ,
İSEVİLİK, TAKİYE, PAŞABABA, MALİKİ, MAKTEL. Gündelik dini-kültürel kelimeler (NAMAZ, MİNARE, HELAL, NOEL,
TAVAF, SELA, EZANİ, İLAHİ, İTİKAT, İNFAK, MOLLA, YARADAN, PUT, ENAM) nötr ipucuyla kaldı.

## Re-clue yazma kriterleri (onaylı)

1. Anlam doğru: TDK birincil, aile-uygun anlam; şüphelide uydurma yok, atlanır.
2. Biçim: ≤20 karakter, en fazla iki virgüllü öge, kelime türü uyumu, özel adda kategori.
3. Sızıntı yok: cevap, ilk 4 harfi (otomatik) ve aynı kök (elle) ipucunda geçmez.
4. Aile-uygun ve tarafsız: din/etnik kavramlarda ansiklopedik tanım; şiddet, cinsellik,
   müstehcen çift anlam yok; kararsızlık hassas aday olarak sahibe bildirilir.
5. Oynanabilir: 25-55 yaş casual için eş anlamlı/kısa tanım; ansiklopedik kelimede kategori.

Uygulama: `python scripts/reclue_apply.py batch.json` (önce `--dry-run`), sonra
`python scripts/reclue.py write-pack --puzzles-dir assets/puzzles`. TDK doğrulaması için
`https://sozluk.gov.tr/gts?ara=<kelime>` (yavaş, zaman aşımına hazırlıklı ol).

## Kapanış (2026-09-14)

- MALİKİ (puzzle 83) ve MAKTEL (puzzle 200) hassas listeye alındı (mezhep ve şiddet
  politikası), iki bulmaca regen_only ile yeniden üretildi (0 fallback). Pack'te artık
  flash-lite kaynaklı cevap yok; hassas listede 16 yeni giriş (bölüm 8).
- Yeniden üretilen bulmacaların tam listesi: 9, 20, 29, 36, 39, 83, 106, 108, 114, 118,
  119, 147, 168, 169, 172, 181, 200.
- P1 re-clue pack kapsamında KAPANDI.

## Düzeltme (2026-09-14): ekranda bayat ipucu gösteriliyordu

Puzzle JSON'unda ipucu metni iki yerde tutulur: `words[].clue` ve `cells[].clues`. Flutter
ClueRenderer `cells[].clues`'tan çizer; `reclue.py write-pack` ise yalnız `words[].clue`'yu
güncelliyordu. Sonuç: Temmuz audit'inden bu yana ve dünkü 122 re-clue dahil, ekranda bayat
ipucu gösteriliyordu (159 dosyada 646 hücre, 604 tekil metin farklıydı; örn. TOST p85'te
"Ekmek arası eritilmiş peynir"). Bu commit'le write-pack `cells[].clues`'u da word_id üzerinden
senkronluyor, `verify_pack` her hücre ipucunun words tarafıyla aynı olduğunu doğruluyor
(`clue_sync_violations`, test `test_verify_pack_flags_cell_clue_out_of_sync`) ve pack yeniden
yazıldı. regen_only ve generate zaten verify_pack'i çağırdığı için bundan sonra sessiz
sapma mümkün değil.

## Ekrana sığdırma (2026-09-14): kelime/hece sınırında kırma + ipucu bütçesi

- UI (543e3d8): ClueRenderer artık `layoutClueText` ile kelime sınırında kırar, 9 px tabanda
  Türkçe hece kuralıyla tireler (`lib/core/utils/tr_hyphenation.dart`), overflow'da ellipsis
  kalır ve debug'da `AppLogger.warning` ile ipucunu yazar. Ölçüm aracı
  `test/tooling/clue_fit_report_test.dart` (gerçek Roboto, 44/49/54/56 dp hücre).
- Bütçe: symbols/two_letter ipuçları ≤16 karakter, kelime ≤10 (`test_curated_clue_budget.py`,
  26 curated ipucu kısaltıldı); master'da 27 kısa cevabın ipucu ≤16'ya indirildi
  (reclue_apply, `previous` korunur). CLAUDE.md'ye bütçe kuralı eklendi.
- Son ölçüm: 49/54/56 dp'de overflow 0; 44 dp'de (kötümser, 330 dp ekran) çift hücrede 31 örnek
  kalıyor (PUL, TOK, FRAK, KITA, FAUL, FİL, KAK, BAR, TOST, SELA, AST, KİTAP, İKİ vb.). Hedef
  49 dp olduğu için bilinçli bırakıldı; gerekirse aynı yöntemle ≤14'e indirilir.

## Açık kalanlar

- Havuz dışındaki ~21k flash-lite kelime re-clue bekliyor; kapı sayesinde acil değil.
  3 harfli havuz dar (457 kelime, pack 314'ünü kullanıyor): kısa kelimeleri önce re-clue
  etmek yeni pack üretimini rahatlatır.
- `reports/pack_words.json` gitignored; gerekirse `scripts/extract_pack_words.py` ile
  yeniden üret.
- Emülatörde yeni ipuçlarının çift-ipucu hücrelerine sığması gözle bakılmadı.
