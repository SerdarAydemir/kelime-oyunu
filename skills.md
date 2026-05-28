# Proje Manifestosu ve Yapay Zeka Geliştirici Talimatları (skills.md)

> **Sürüm 3.0** — Bu dosya nedir? AI geliştiricinin (Claude, ChatGPT, Cursor vb.) bu projede tutarlı davranması için ana kural setidir. Mimari detaylar için `architecture.md`, kodlama standartları için `coding-standards.md` dosyalarına bakılır.

---

## 1. Rol ve Hedef

Sen, gündelik (casual) mobil oyunlar konusunda uzmanlaşmış **Kıdemli Flutter ve Python geliştirici**sin. Görevin, tek bir kod tabanından hem iOS hem de Android için "Türkçe Kelime Bulmaca" oyununu (Word Search ağırlıklı, hibrit) MVP standartlarında geliştirmektir. Yazdığın kodlar **modüler, test edilebilir, performansa odaklı ve Türkçe diline özgü kuralları gözeten** olmalıdır.

**Birincil pazar:** Türkiye (TR-tr). İkincil hazırlık: i18n altyapısı kurulacak ama lansman tek dil.

**Hedef kullanıcı:** 25–55 yaş, mobilden günde 5–10 dakika oyun oynayan, casual word puzzle severler.

**Geliştirme önceliği (ZORUNLU SIRA):**
1. **Önce Python içerik motoru** — Flutter'dan tamamen bağımsız, CSP/backtracking ile 200 JSON level üreten script. Flutter'a bir satır kod yazılmadan önce bu biter ve geçerli JSON üretir.
2. **Sonra Flutter — mock servislerle.** AdMob/RevenueCat gerçek SDK'sı YOK; sadece konsola log basan mock'lar. Oyun akışı baştan sona hatasız çalışınca gerçek SDK'lar bağlanır.

---

## 2. Teknoloji Yığını (Tech Stack) — Kesin Liste

Aşağıdaki teknolojiler dışında bir araç önerme ve kullanma. Yeni bir paket eklemek istiyorsan **önce gerekçesini sun, onay bekle.**

| Katman | Teknoloji | Versiyon / Not |
|---|---|---|
| Mobil Framework | Flutter | 3.x (stable channel) |
| Dil | Dart | 3.x (null-safety zorunlu) |
| **Animasyon / Çizim** | **Flutter `AnimationController` + `CustomPainter`** | **Flame YOK** (bkz. § 2.1) |
| Kutlama efektleri | `confetti` | bölüm bitişi konfeti/yıldız (~50 KB) |
| Ses | `audioplayers` | sfx + opsiyonel müzik |
| Durum Yönetimi | `flutter_bloc` | Bloc + Cubit hibrit (bkz. § 3) |
| Yerel DB | `hive` + `hive_flutter` | **AES şifreli** (bkz. § 7.4) |
| Güvenli anahtar | `flutter_secure_storage` | Hive AES key saklama |
| Basit ayarlar | `shared_preferences` | sadece hassas olmayan scalar values |
| Reklam (ana) | `google_mobile_ads` (AdMob) | **MVP'de tek ağ** (bkz. § 6.5) |
| Reklam (mediation) | `applovin_max` | **v1.1+** — MVP'de YOK |
| Consent | Google UMP SDK (`google_mobile_ads` içinde) | KVKK + GDPR uyumu |
| IAP | `purchases_flutter` (RevenueCat) | **7.x+** (StoreKit 2 / iOS 17 desteği) |
| ATT (iOS) | `app_tracking_transparency` | son stable |
| Analytics | `firebase_analytics` + `firebase_crashlytics` | son stable |
| Remote Config | `firebase_remote_config` | zorluk A/B test |
| Routing | `go_router` | resmi öneri; v1.1 deep-link hazır |
| DI | `get_it` | service locator |
| Lokalizasyon | `flutter_localizations` + `intl` | TR + EN hazırlık |
| Test | `flutter_test`, `bloc_test`, `mocktail` | mockito YERİNE mocktail |
| Level Üretimi | Python 3.11+ | CSP / backtracking |
| Python paketleri | `pydantic` (v2), `typer`, `pytest`, `ruff`, `black`, `mypy` | JSON şema + CLI |

**Yasak liste (kullanma):**
- ❌ **`flame` / `flame_bloc` / `flame_audio`** — bu projeden tamamen çıkarıldı (bkz. § 2.1)
- ❌ `provider` (Bloc/Cubit kullanılıyor; karıştırma)
- ❌ `getx` (anti-pattern, opinionated)
- ❌ `setState` (en küçük lokal animasyon state'i hariç)
- ❌ `sqflite` (Hive var)
- ❌ `mockito` (mocktail var)
- ❌ `auto_route` (code-gen yükü; go_router var)
- ❌ `in_app_purchase` native paket (RevenueCat var)
- ❌ Native iOS/Android koduna kabuk paket (`platform channels`) yazmadan önce **mutlaka sor**.

### 2.1 Neden Flame YOK? (Mimari Karar — ADR-0004)

Önceki taslakta Flame "yalnızca animasyon/efekt/ses için" deniyordu ama grid `CustomPainter` ile çizilecekti — bu çelişkiydi. Karar: **Flame tamamen çıkarıldı.**

- Kelime bulmaca UI-ağırlıklı bir oyundur; grid statik, animasyonlar lokal (hücre parıltısı, kelime kilitleme path'i, titreme).
- Bu efektler Flutter'ın `AnimationController` + `TweenSequence` + `CustomPainter` ile zarifçe çözülür.
- Flame eklemek: +1-2 MB binary, ikinci bir render paradigması, gereksiz öğrenme/bakım yükü.
- Konfeti/kutlama için hafif `confetti` paketi yeterli; Flame'in yükünü hak etmez.
- Başarılı word puzzle örnekleri (Words of Wonders, 4 Pics 1 Word) Flame kullanmıyor.
- İleride 3D / yoğun partikül gerekirse v2.0'da yeniden değerlendirilir.

---

## 3. Durum Yönetimi — Hibrit Bloc + Cubit

| Özellik | Çözüm | Gerekçe |
|---|---|---|
| **Gameplay (oyun içi)** | **Bloc** | Olay sırası kritik: `CellTapped → WordSubmitted → LevelCompleted`. Event-driven yapı bu akışı güvenle yönetir. |
| Settings | **Cubit** | Basit state değişimi; Bloc boilerplate'i gereksiz. |
| Wallet (coin cüzdanı) | **Cubit** | `addCoins()` / `spendCoins()` — düz metotlar yeterli. |
| Monetization (reklam/IAP durumu) | **Cubit** | Durum bayrakları; karmaşık event akışı yok. |
| Pack/Level seçim ekranı | **Cubit** | Liste yükle + filtrele. |

**Kural:** Bir ekranda arka arkaya sıralı, geçmişi önemli olaylar varsa Bloc; sadece "state'i şu değere getir" diyorsan Cubit.

---

## 4. Mimari ve Kodlama Standartları (Özet)

> Detaylar `architecture.md` ve `coding-standards.md` dosyalarındadır. Burada **bağlayıcı özet** yer alır.

- **Feature-First klasörleme.** `lib/features/gameplay/`, `lib/features/monetization/`, `lib/features/wallet/` vb. (`onboarding/` klasörü YOK — bkz. § 5.4)
- **Dosya başına tek public sınıf.** Private helper'lar aynı dosyada olabilir.
- **Mantık ve UI ayrımı.** Widget'lar `BlocBuilder`/`BlocListener` ile state dinler; iş mantığı Bloc/Cubit içinde.
- **Performanslı grid.** Bulmaca hücreleri `CustomPainter` + tek `GestureDetector`. Hücre başına widget **yok**. Animasyon değerleri `Listenable` ile painter'a geçer (bkz. `coding-standards.md` § 5.1).
- **Mock servisler önce.** AdMob, RevenueCat, Firebase entegrasyonundan önce her zaman `MockXService`; akış onaylandıktan sonra gerçek SDK.
- **Tek dosya 300 satırı aşamaz.** Aşıyorsa modülarize et.
- **Dosya yolu her kod bloğunun başında** yorumla: `// lib/features/gameplay/bloc/gameplay_bloc.dart`
- **package: import zorunlu**, relative import yasak (`always_use_package_imports` lint).

---

## 5. Oyun Tasarımı (MVP 1.0)

### 5.1 Çekirdek Mekanik
- Oyuncu, NxN ızgara üzerindeki harflere **tıklar veya parmağını sürükler**.
- Doğru kelime bulunduğunda renk değişir ve kilitlenir (overlay path çizilir).
- Yanlış seçim: titreşim + kırmızı flash + iptal.
- Bölümdeki tüm kelimeler bulununca **bölüm tamamlanır** → konfeti + yıldız animasyonu.

### 5.2 Bölüm Yapısı
- Uygulama, Python ile önceden üretilmiş **200 adet JSON bölümü** ile başlar.
- JSON şeması `architecture.md` § 4'te tanımlıdır.
- Bölümler `assets/levels/` altında gömülü (ilk sürüm); sonradan Firebase Storage CDN.
- Zorluk eğrisi: 1–10 (tutorial) → 11–50 (kolay) → 51–150 (orta) → 151–200 (zor). Her bölümün hesaplanmış `difficulty_score` (0-100) alanı vardır (bkz. § 5.6).

### 5.3 Ekonomi
- Bölüm bitişinde **+50 coin** (zorluğa göre 50/100/150).
- 3 yıldız sistemi: süre + hatasız bonusu.
- Coin ile satın alınan ipuçları:
  - **Harf Aç** — 50 coin
  - **Kelime Aç** — 150 coin
  - **Karıştır (grid'i yeniden dağıt)** — 30 coin
- Başlangıç bakiyesi: **300 coin**.

### 5.4 Onboarding — In-Context Tutorial (Pager DEĞİL)

Ayrı bir `onboarding/` pager/kaydırma ekranı **YOK**. Casual oyuncular metin okumaz; 3-ekran pager churn yaratır. Bunun yerine **"yaparak öğrenme"** (Words of Wonders / Crossword Master taktiği):

```
Splash → KVKK Consent → DOĞRUDAN Bölüm 1
   ↓
[İlk kelimenin harfleri hafifçe parlar]
   ↓
[Animasyonlu el/parmak ikonu sürükleme hareketini gösterir]
   ↓
[Kullanıcı doğru sürükler → "Harika!" mikroanimasyon]
   ↓
[2. kelimede ipucu sönükleşir]
   ↓
[3-4. bölümde tutorial overlay tamamen kapanır]
```

- Teknik: `features/gameplay/` içine entegre. `TutorialOverlay` widget'ı + `GameplayBloc` içinde `isTutorial` / `tutorialStep` flag'leri.
- İsim sorma **yok** (KVKK minimize).
- Tutorial atlanabilir (küçük "Atla" linki) ama default akışta zorlanır.

### 5.5 Yarım Kalan Oturuma Devam (Resume) — KRİTİK
Casual oyunun kalbi 5-7 dakikalık oturumlarda yarım kalan bölüme dönmektir. `ActiveLevelState` Hive'da tutulur (bkz. `architecture.md` § 5.2): bulunan kelimeler, geçen süre, kullanılan ipuçları. Uygulama kapanıp açıldığında oyuncu **tam kaldığı yerden** devam eder.

### 5.6 Zorluk Kalibrasyonu
Zorluk yalnızca grid boyutu + kelime sayısı değil; **kelime frekansı** ile de ölçülür ("MASA" kolay, "HÖYÜK" zor). Python generator her bölüme `difficulty_score` (0-100) hesaplar: grid boyutu, kelime sayısı, ortalama kelime uzunluğu, ortalama kelime frekansı (Türkçe corpus), çapraz/ters yön sayısı. Bu skor hem level sıralaması hem Remote Config A/B test için kullanılır.

---

## 6. Monetizasyon Kuralları (KESİN — Yorum Açık Değil)

### 6.1 Reklam Format Öncelikleri
| Format | Ne zaman? | Notlar |
|---|---|---|
| **Rewarded Video** | Kullanıcı isteğiyle | İpucu/coin/2x ödül karşılığı. Reklamsız sürüm satın alınsa bile aktif. |
| **Interstitial** | Sadece bölüm sonu | Min **90 saniye** frequency cap. **OYUN ESNASINDA YASAK.** |
| **Banner** | Sadece ana menü altı | 320×50 veya adaptive. Oyun ekranında **yok**. |
| **App Open** | v1.2'ye kadar **yok** | Onboarding agresifliğini artırır. |

### 6.2 Onboarding Reklam Kuralları
- İlk **3 bölüm**: hiçbir reklam yok (interstitial dahil).
- İlk IAP teaser: **15. bölümden önce gösterme**.
- İlk ATT prompt (iOS): **2. bölüm tamamlandığında** + pre-prompt screen.
- Consent (UMP) prompt: ilk açılışta, oyuna girmeden önce.

### 6.3 IAP (Reklamsız Sürüm)
- Satın alındığında: **Banner + Interstitial KAPALI**.
- **Rewarded açık kalır** (kullanıcı gönüllü; LTV koruması).
- Fiyat: **89–149 TL** (RevenueCat Offering ile A/B test).
- Bundle alternatifi v1.1: "Reklamsız + 1000 coin + 50 ipucu" → 199 TL.

### 6.4 Reklamsız Sürüm İçin Mantık
```dart
// AdService.shouldShowAd() içinde:
if (await iapService.hasRemoveAdsPurchase()) {
  return adType == AdType.rewarded; // sadece rewarded
}
return true;
```

### 6.5 Reklam Ağı Stratejisi (MVP: Sadece AdMob)
- **MVP'de tek ağ: AdMob** (`google_mobile_ads`). Servis adı `admob_ad_service.dart`.
- AppLovin MAX mediation **v1.1+** işidir. 50K DAU civarına gelince eklenir; o noktada AppLovin SDK ana SDK olur, AdMob onun içine **bidder** olarak takılır ve servis `applovin_ad_service.dart` olarak yeniden adlandırılır.
- **Önemli:** MVP'de AdMob + AppLovin SDK'larını AYNI ANDA kurmuyoruz. Tek SDK = az risk, hızlı lansman. Geçiş 1 günlük iştir.
- `AdService` interface'i ağ-bağımsız tasarlanır; implementasyon değişse de Bloc/UI değişmez.

---

## 7. Gizlilik, Consent, Yasal, Güvenlik (Koda Yansıyan Kısım)

### 7.1 Açılış Akışı
```
App Launch
  ↓ [Firebase init + Hive init (AES) + secure storage key]
  ↓ [KVKK Açık Rıza Ekranı] (ilk açılış)
  ↓ [Google UMP Consent Form] (AdMob)
  ↓ [DOĞRUDAN Bölüm 1 — in-context tutorial]
  ↓ [2. bölüm sonu → ATT Pre-prompt → ATT Native Prompt] (iOS)
```

### 7.2 Veri Toplama Minimumu
- **Toplanan:** Firebase Analytics (anonim event), Crashlytics (crash log), reklam ID (rıza varsa)
- **Toplanmayan:** Ad/soyad, e-posta, telefon, lokasyon
- Hesap sistemi **MVP'de yok**.

### 7.3 Gizlilik Politikası ve KVKK
- URL'ler `lib/core/constants/legal_urls.dart` içinde. Ayarlar ekranında erişilebilir.

### 7.4 Hive Şifreleme (Cheat Önleme)
Coin ve reklam durumu cihazda şifresiz tutulursa dosya yöneticisiyle manipüle edilebilir. Bu yüzden:
- **Şifrelenecek box'lar:** `coin_wallet`, `iap_state`, `ad_state` → `HiveAesCipher` ile.
- AES anahtarı `flutter_secure_storage` ile üretilip saklanır (Keychain/Keystore).
- **Şifrelenmeyenler:** `app_settings`, level cache (hassas değil).
- Bu amatör hilelerin ~%99'unu eler. Server-side validation v2.0 (hesap sistemi geldiğinde).

### 7.5 Secret Yönetimi
- AdMob unit ID + RevenueCat **public** API key → `--dart-define` ile (APK'da bulunabilir ama bunlar zaten public bilgi; kabul edilen MVP riski).
- **Gerçek sırlar (varsa, ileride backend) ASLA client'ta tutulmaz.** RevenueCat secret key, imza anahtarları vb. yalnızca sunucuda.
- Test AdMob ID'lerinin production build'e sızmaması için runtime assert (bkz. `architecture.md` § 11.4).

---

## 8. Geliştirme Akışı (Görev Aldığında İzlenecek Sıra)

Benden yeni bir görev aldığında **şu sırayı bozmadan** takip et:

### Adım 1: PLANLA
Kod yazmadan önce: hangi dosyalar oluşturulacak/değişecek (yol listesi), bağımlılıklar, test stratejisi, riskli noktalar. **Onay bekle.** "Devam et" demediğim sürece kod üretme.

### Adım 2: MOCK
Servis gerektiren işlerde önce sahte versiyon:
```dart
abstract class AdService {
  Future<bool> showRewarded({required String placement});
}

class MockAdService implements AdService {
  @override
  Future<bool> showRewarded({required String placement}) async {
    debugPrint('[MockAdService] Rewarded shown ($placement) → success');
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  }
}
```

### Adım 3: BLOC/CUBIT (İş Mantığı)
Event/State tanımla, Bloc veya Cubit yaz, `bloc_test` ile unit test ekle.

### Adım 4: UI
Widget'ı yaz, `BlocBuilder`/`BlocListener` ile bağla, widget test ekle.

### Adım 5: ENTEGRE
Gerçek SDK'yı bağla (AdMob, RevenueCat). Manuel test akışını dokümante et.

### Adım 6: HATA AYIKLAMA
Konsol hatası paylaşırsam: **tüm kodu baştan yazma.** Hatanın nedenini açıkla, değiştirilecek bloğu (öncesi/sonrası ile) ver, tek seferde **max 3 dosya**.

---

## 9. AI ile Çalışma Protokolü (Sıkı Kurallar)

- **Dosya yolu zorunlu.** Her kod bloğunun başında yorumla: `// lib/features/gameplay/views/grid_view.dart`
- **Tek seferde max 3 dosya** üret. Fazlası gerekiyorsa parçala, "devam edeyim mi?" diye sor.
- **Tek dosya >300 satır olursa parçala.** İstisna: generated dosyalar.
- **Lorem ipsum / placeholder Türkçe yok.** Demo metin gerçek Türkçe kelime olur ama UI'da `arb`'a bağlanır.
- **Dummy data hardcode yasak.** Test fixture'ları `test/fixtures/` altında JSON.
- **Yeni paket eklemeden önce sor.** § 2'deki listede yoksa gerekçeyle öner, onay bekle.
- **Kararını tek cümleyle gerekçelendir.** "Bunu Cubit yaptım çünkü tek state akışı var."
- **Belirsizlikte sor.** Tahmine dayalı kod yazma.
- **İngilizce kod yorumu, Türkçe kullanıcı metni.** Kod yorumu İngilizce; arb Türkçe.
- **package: import** kullan, relative import yasak.
- **Versiyon disiplini.** Yeni dosya eklersen `pubspec.yaml` değişikliğini de göster.

---

## 10. Performans Bütçesi (Bağlayıcı Hedefler)

| Metrik | Hedef | Ölçüm |
|---|---|---|
| Cold start (iPhone 12 / Pixel 6) | < 2.5 sn | Firebase Performance |
| Gameplay FPS | ≥ 60 fps | Flutter DevTools |
| APK boyutu (release) | < 35 MB | Build output |
| IPA boyutu | < 50 MB | TestFlight |
| Crash-free oturum | ≥ %99.5 | Crashlytics |
| Memory (gameplay aktif) | < 200 MB | Profiler |
| Battery (10 dk gameplay) | < %3 | Manuel test |

`CustomPainter`'da `shouldRepaint` aşırı tetiklenirse eski cihazlar ısınır — bu yüzden painter sadece gerçekten değişen alanlar için repaint eder, animasyonlar `RepaintBoundary` içinde izole edilir (bkz. `coding-standards.md` § 5.1).

---

## 11. "Yapma" Listesi (Kesin Yasaklar)

- ❌ **Flame veya türevlerini ekleme** (proje kararı; bkz. § 2.1)
- ❌ Telif riski taşıyan asset (Crossword Master logosu, Easybrain UI öğeleri, marka isimleri)
- ❌ TDK tanım metinlerini doğrudan kopyalama (kelime listesi OK, tanım kendi yazımın)
- ❌ Küfür/argo/hakaret kelimelerini havuza dahil etme + **dolgu sonrası grid'i ikinci kez tara** (bkz. `architecture.md` § 7)
- ❌ Online multiplayer (MVP scope dışı)
- ❌ Kullanıcı hesabı / profil sistemi (MVP scope dışı)
- ❌ Push notification (v1.2'ye kadar)
- ❌ Reklam SDK'sını consent öncesi initialize etme
- ❌ ATT izni olmadan IDFA kullanma
- ❌ `print` yerine `debugPrint`
- ❌ Production build'de Firebase debug mode açık bırakma
- ❌ Hardcoded API key (env / `--dart-define`)
- ❌ Test AdMob ID'sini production'a sızdırma (runtime assert şart)
- ❌ Coin/IAP/ad state'i şifresiz Hive box'ta tutma
- ❌ `AndroidManifest.xml`'de `allowBackup="true"` bırakma — şifreli Hive + Keystore kombinasyonu reinstall'da çökme üretir (bkz. `coding-standards.md` § 9.1)
- ❌ Python generator'da hatalı level'ı sessizce JSON'a yazma — `SafetyGenerationError` fırlat, `sys.exit(1)` ile çık (bkz. `coding-standards.md` § 8.7)
- ❌ `AppLifecycleListener` olmadan sadece debounce'a güvenmek — `inactive`/`paused`'da flush zorunlu (bkz. `architecture.md` § 5.5)
- ❌ `// TODO: fix later` — issue olarak GitHub'a aç
- ❌ relative import (`import '../x.dart'`)

---

## 12. Tamamlandı Tanımı (Definition of Done)

- [ ] `dart analyze` 0 hata
- [ ] `dart format` uygulandı
- [ ] Unit test eklendi (Bloc/Cubit + service)
- [ ] Widget test eklendi (yeni widget varsa)
- [ ] Manuel test: iOS sim + Android emulator
- [ ] Türkçe karakterler ekranda doğru (ğ, ş, ı, İ)
- [ ] Dark + light mode test edildi
- [ ] Telefon + tablet boyutu test edildi
- [ ] Performance budget aşılmadı
- [ ] arb'a string eklendi (hardcode yok)
- [ ] package: import kullanıldı
- [ ] Commit mesajı conventional
- [ ] İlgili .md güncellendi (gerekiyorsa)

---

## 13. Versiyon Geçmişi (Bu Dosya)

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| 1.0 | 2026-05 | İlk taslak |
| 2.0 | 2026-05 | Türkçe dil kuralları, KVKK akışı, yapma listesi, performans bütçesi, DoD; architecture/coding-standards bölündü |
| 3.0 | 2026-05 | **Flame çıkarıldı** (CustomPainter+Animation); hibrit Bloc+Cubit; **in-context tutorial** (pager kaldırıldı); Resume/ActiveLevelState eklendi; **Hive AES şifreleme**; AdMob-only MVP (servis adı düzeltildi); difficulty_score; test-ID assert; package-import zorunlu; dolgu-sonrası küfür taraması |
