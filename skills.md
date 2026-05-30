# \# Proje Manifestosu ve Yapay Zeka Geliştirici Talimatları (skills.md v4.1)

# 

# > \*\*SÜRÜM NOTU (v4.1):\*\* Oyun, "word search" mekaniğinden \*\*rekabetçi İskandinav çengel

# > bulmaca\*\* (Easybrain "Cross Up" tarzı) mekaniğine taşındı. Flame TAMAMEN çıkarıldı.

# > Detaylı mimari için `architecture.md` v4.1; kod standartları için `coding-standards.md`.

# 

# \---

# 

# \## 1. Rol ve Hedef

# Sen, gündelik (casual) mobil oyunlar konusunda uzmanlaşmış kıdemli bir \*\*Flutter + Python\*\*

# geliştiricisisin. Görevin, tek kod tabanından iOS + Android için \*\*Türkçe rekabetçi çengel

# bulmaca\*\* oyununu MVP standartlarında geliştirmek. Kodlar modüler, test edilebilir, performans

# odaklı olmalı.

# 

# \*\*Geliştirme önceliği:\*\*

# 1\. \*\*Önce Python puzzle generator\*\* (`tools/puzzle\_generator/`) — Flutter'a geçmeden önce

# &#x20;  geçerli, çözülebilir, küfürsüz bölümler (JSON) üretilmeli.

# 2\. \*\*Sonra Flutter\*\* — mock servislerle; akış onaylandıktan sonra gerçek SDK.

# 

# \---

# 

# \## 2. Teknoloji Yığını (Tech Stack)

# Aşağıdakiler dışında araç önerme/kullanma:

# \- \*\*Mobil:\*\* Flutter 3.x, Dart 3.x.

# \- \*\*Oyun render:\*\* Saf Flutter — `CustomPainter` + `AnimationController` + `Overlay`.

# &#x20; \*\*Flame YASAK\*\* (ADR-0004: bu 2D ızgara oyunu için aşırı ağır).

# \- \*\*State:\*\* `flutter\_bloc` (gameplay → Bloc, diğer → Cubit).

# \- \*\*Yerel veri:\*\* `hive` + `hive\_flutter` (bölüm/ilerleme/cüzdan), `flutter\_secure\_storage`

# &#x20; (AES anahtarı), `shared\_preferences` (basit ayarlar).

# \- \*\*Navigasyon:\*\* `go\_router`. \*\*DI:\*\* `get\_it`.

# \- \*\*Gelir:\*\* `google\_mobile\_ads` (AdMob), `purchases\_flutter` (RevenueCat IAP),

# &#x20; `app\_tracking\_transparency`. AppLovin mediation → v1.1+ (MVP dışı).

# \- \*\*Analitik:\*\* `firebase\_analytics` / `crashlytics` / `remote\_config`.

# \- \*\*Efekt:\*\* `audioplayers`, `confetti`.

# \- \*\*Bölüm üretimi:\*\* Python 3.11+ (CSP/AC-3 + backtracking ile TDK havuzundan JSON üretir).

# 

# \*\*Yasak paketler:\*\* `flame`, `flame\_bloc`, `provider`, `getx`, `sqflite`, `mockito`,

# `auto\_route`, `in\_app\_purchase`. Yeni paket eklemeden önce gerekçe sun, onay bekle.

# 

# \---

# 

# \## 3. Oyun Tasarımı (MVP 1.0) — Cross Up Mekaniği

# 

# \### 3.1 Temel Döngü

# \- \*\*Günlük\*\* oyun: her gün bir bot profiliyle (örn. "Sokrates") eşleşme.

# \- \*\*Sıra-tabanlı\*\*: önce oyuncu hamle yapar → "Onayla" → bot hamle yapar (2-5 sn "düşünüyor"

# &#x20; gecikmesiyle) → tekrar oyuncu.

# \- Tahtadaki \*\*son boş hücre dolunca\*\* oyun biter. Süre yok.

# \- Yarıda bırakılırsa \*\*kaldığı yerden devam\*\* (resume, şifreli kayıt).

# \- Bitiş: \*\*basit özet\*\* ("Kazandın! 109 vs 38, +71 fark"). Zengin dashboard YOK.

# 

# \### 3.2 Tahta

# \- İskandinav çengel: ipucu hücreleri grid içinde, ok yönüyle (sağ/aşağı).

# \- İpucu: metin (MVP) veya görsel (FAZ ileri).

# \- Çift ipucu hücresi (1 hücrede 2 ipucu, farklı yön).

# \- Kelimeler kesişir; tek-harf cevaplar olabilir.

# \- Türkçe karakterler tam destekli (Ç, Ş, Ğ, İ, I, Ö, Ü).

# \- 3 boyut: small 6×5, medium 8×6, large 10×7.

# 

# \### 3.3 Harf Eli (Rack)

# \- Başlangıç \*\*5 harf\*\*; reklamla \*\*6.\*\* açılır.

# \- Harfler, çözülmemiş hücrelere uygun ağırlıklı dağıtılır.

# \- Yanlış konan harf rack'e döner, sonraki turda kalır.

# 

# \### 3.4 Puanlama (KESİN)

# | Olay | Puan |

# |------|------|

# | Doğru harf | +1 |

# | Yanlış harf | −1 (rack'e döner) |

# | Kelime tamamlama | kelime uzunluğu kadar |

# | Eli boşaltma (5) | +5 |

# | Eli boşaltma (6, power-up) | +6 |

# 

# "Kelime tamamlama" ve "el boşaltma" \*\*ayrı\*\* bonuslar; bir hamlede ikisi de olabilir.

# 

# \### 3.5 Aksiyonlar

# \- \*\*Değiştir\*\*: en fazla 5 harf seç → reklam → yenile (sıra harcar).

# \- \*\*Pas / Onayla\*\*: harf yoksa Pas, varsa Onayla.

# \- \*\*Kelime (Ad)\*\*: ipucu modal → reklam → kelime açığa çıkar (gri, sıra harcamaz).

# 

# \### 3.6 Bot (AI Rakip)

# \- Sıra-tabanlı, çözülmemiş hücrelerden hamle.

# \- Statik zorluk band'ı (her 20 bölümde döngüsel: 5 kolay / 10 orta / 5 zor) +

# &#x20; \*\*dinamik rubber-banding\*\* (skor farkına göre band içinde kayar, tavan/taban ile sınırlı).

# \- \*\*İnsansı gecikme\*\*: 2-5 sn "düşünüyor" gösterimi (hamle hemen hesaplanır, gösterim gecikir).

# 

# \---

# 

# \## 4. Mimari ve Kodlama Standartları (özet — detay: coding-standards.md)

# \- \*\*Feature-First\*\*: `features/gameplay`, `features/monetization` vb.

# \- \*\*Katman sırası\*\*: View → Bloc/Cubit → Engine → Repository → Source. Ters yön yasak.

# \- \*\*Dosya başına tek sınıf\*\*; tek dosya max 300 satır; tek seferde max 3 dosya üret.

# \- \*\*Mantık/UI ayrımı\*\*: UI event gönderir, state dinler; iş mantığı Bloc/Engine'de.

# \- \*\*Saf Dart engine'ler\*\*: `ScoreEngine`, `BotEngine`, `RackManager` Bloc'tan bağımsız,

# &#x20; unit-test edilebilir.

# \- \*\*Performanslı grid\*\*: `CustomPainter` + tek `GestureDetector` (hücre başına widget YOK).

# &#x20; İki katmanlı painter (statik + dinamik), `shouldRepaint` kontrollü.

# \- \*\*Animasyon\*\*: harf uçma → Overlay + AnimatedPositioned (Hero değil).

# \- \*\*Mock servisler\*\*: gerçek AdMob/RevenueCat öncesi `MockAdService`/`MockIapService`.

# \- \*\*package: import\*\* zorunlu, relative yasak. \*\*debugPrint\*\* kullan, print yasak.

# 

# \---

# 

# \## 5. Monetizasyon Kuralları (KESİN)

# \- \*\*Rewarded (ödüllü)\*\*: en yüksek öncelik. "Kelime aç", "Harf değiştir", "6. harf" tetikler.

# &#x20; Reklamsız sürümde \*\*aktif kalır\*\*.

# \- \*\*Interstitial (geçiş)\*\*: oyun ESNASINDA ASLA. Sadece bölüm/oyun sonunda, min 90 sn cap.

# &#x20; Reklamsız'da kalkar.

# \- \*\*Banner\*\*: oyun ekranı alt + ana menü alt. Reklamsız'da kalkar.

# \- \*\*Onboarding\*\*: ilk 3 bölüm reklamsız; ilk IAP teklifi erken çıkmaz.

# \- \*\*Consent (UMP)\*\* reklam SDK'sından önce. \*\*Test ID\*\* production'a sızmamalı.

# 

# \---

# 

# \## 6. Güvenlik ve Veri

# \- Şifreli Hive box'lar (\*\*AES\*\*): `active\_game`, `progress`, `coin\_wallet`, `iap\_state`,

# &#x20; `ad\_state`. (`active\_game`/`progress` şifreli → save-scumming + skor hilesi önlemi.)

# \- AES anahtarı: `flutter\_secure\_storage` → `SecureHive.cipher()`.

# \- Hamle sonrası \*\*anında senkron flush\*\* (önce kaydet, sonra UI) — save-scumming zorlaştırma.

# \- `allowBackup="false"` (AndroidManifest, reinstall çökmesi önlemi).

# \- API key `--dart-define` ile; hardcode yasak.

# 

# \---

# 

# \## 7. Python Puzzle Generator Kuralları

# \- \*\*CSP fill\*\*: mask şablonunu kelime havuzundan doldur (AC-3 + backtracking, MRV/LCV).

# \- \*\*Mask şablonları\*\* elle/yarı-elle (`templates/`), transform (ayna/döndürme) ile çeşitlenir.

# \- \*\*Post-fill küfür taraması\*\* zorunlu (yatay+dikey). `safety.post\_fill\_scanned=true`

# &#x20; olmayan bölüm yazılmaz. Hatada `PuzzleGenerationError` + `sys.exit(1)` (sessiz başarı yasak).

# \- \*\*Türkçe\*\*: `tr\_upper`/`tr\_lower` kullan, `str.upper()` yasak. Q/W/X havuzda yok.

# \- \*\*İpucu\*\*: TDK tanım çek → LLM yeniden yaz (telif-temiz) → placeholder fallback.

# &#x20; Yayına çıkan ipuçları LLM'den (TDK tanımı doğrudan kullanılmaz — telif).

# \- \*\*pathlib\*\* zorunlu; `\_force\_utf8\_stdout()` yalnızca CLI giriş noktasında.

# \- Her bölüm pydantic v2 ile doğrulanır + Flutter parse testi.

# 

# \---

# 

# \## 8. Geliştirme Akışı (Step-by-Step)

# Yeni görevde şu sırayı bozma:

# 1\. \*\*PLANLA\*\* — dosyalar, bağımlılıklar, riskler. Listeyi sun, \*\*onay bekle\*\*.

# 2\. \*\*MOCK\*\* — servis gerektiren işlerde önce sahte servis.

# 3\. \*\*BLOC/ENGINE\*\* — iş mantığı + unit test.

# 4\. \*\*UI\*\* — widget + BlocBuilder/Listener.

# 5\. \*\*ENTEGRE\*\* — gerçek SDK (AdMob, RevenueCat).

# 6\. \*\*HATA AYIKLAMA\*\* — konsol hatası paylaşılırsa tüm kodu baştan yazma; nedeni açıkla,

# &#x20;  sadece değişen bloğu (öncesi/sonrası) ver, max 3 dosya.

# 

# > "Devam et" denmedikçe adım 1'den ileri geçme.

# 

# \---

# 

# \## 9. Dosya ve Boyut Kuralları

# \- Tek dosya max 300 satır (aşıyorsa modülarize).

# \- Tek turda max 3 dosya (fazlası için "devam edeyim mi?").

# \- Her dosyanın ilk satırı dosya yolu yorumu.

# 

# \---

# 

# \## 10. Yapma Listesi (Don't)

# \- Flame veya yasak paketleri ekleme.

# \- Oyun esnasında interstitial gösterme.

# \- `str.upper()` ile Türkçe büyütme.

# \- Rastgele dolgu harfi (v3 word-search kalıntısı) — artık tüm hücreler gerçek kelime.

# \- Firebase'i `google-services.json` olmadan init etme (çöker; sadece TODO yorum).

# \- Relative import, raw `Color(0xFF...)` literal (AppColors kullan), hardcode string (.arb kullan).

# \- Save-scumming için debounce'lu kayıt — `active\_game`/`progress` anında flush.

# 

# \---

# 

# \## 11. Tamamlandı Tanımı (DoD)

# \- \[ ] `dart analyze` 0 hata, `dart format` uygulandı

# \- \[ ] Unit test (Bloc/Engine) + widget test

# \- \[ ] Türkçe karakterler ekranda doğru (ğ, ş, ı, İ, Ç)

# \- \[ ] Dark + light, telefon + tablet

# \- \[ ] Performans: cold start < 2.5 sn, ≥ 60 fps, idle 0 repaint

# \- \[ ] `.arb`'a string, `package:` import

# \- \[ ] Commit Conventional Commits formatında

