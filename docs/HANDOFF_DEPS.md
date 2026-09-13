# HANDOFF — Bağımlılık yükseltme oturumu (2026-09-13)

Flutter 3.47.2 / Dart 3.13.2. Amaç: Flutter 3.47 ile gelen üç Android
uyarısını kapatmak (Java 8 obsolete, firebase KGP, Impeller opt-out deprecated).
Her adımda `flutter analyze` 0 hata ve `flutter test` 167 yeşil; adım 1, 3, 4
sonrası temiz `flutter build apk --debug` alındı.

## Commit listesi (sırayla)

| # | Commit | Başlık |
|---|---|---|
| 1 | `4d1ca4a` | build(deps): upgrade flutter_secure_storage 9 -> 11 |
| 2 | `3ac2520` | build(deps): drop unused get_it, upgrade go_router 14 -> 18 |
| 3 | `d4e3ebf` | build(deps): upgrade firebase plugins to the core 4 line |
| 3b | `a0d08c4` | build(android): enable built-in Kotlin (AGP 9) |
| 4 | `9baacac` | build(deps): upgrade google_mobile_ads 8 -> 9 |
| 5 | `238fac6` | build(android): drop deprecated Impeller opt-out |
| 6 | (bu commit) | docs: CLAUDE.md + bu HANDOFF |

## Adım adım: ne kırıldı, nasıl düzeltildi

### 1. flutter_secure_storage 9.2.4 → 11.1.1
- **Kırılan:** `AndroidOptions(encryptedSharedPreferences: true)` parametresi v11'de
  yok (Jetpack EncryptedSharedPreferences backend'i kaldırıldı).
- **Düzeltme:** `lib/data/sources/secure_hive.dart` → `const FlutterSecureStorage()`
  (plugin default'ları: KeyStore ile sarılmış AES-GCM). Başka kullanım yeri yok.
- **Sonuç:** Temiz build'de `source value 8 is obsolete` uyarısı gitti; tek kaynak
  bu plugin'in `VERSION_1_8` Android modülüydü (v11 Java 17, minSdk 24).
- **Bilinçli kabul:** 9→11 doğrudan atlamada v9 verisi taşınmıyor (migrasyon v10'da).
  Mevcut emülatör kurulumunda AES anahtarı okunamaz → `SecureHive.openEncryptedBox`
  box'ları yeniden yaratır → o kurulumun ilerlemesi bir kez sıfırlanır. Uygulama
  yayında değil. Kural CLAUDE.md'ye eklendi: yayın sonrası major atlaması yok.

### 2. get_it kaldırıldı, go_router 14.8.1 → 18.0.1
- `get_it` lib/ ve test/ içinde hiç import edilmiyordu; bump yerine kaldırıldı
  (constructor injection; `docs/F7_PLAN.md` K7 zaten bunu söylüyor).
- go_router 15 (case-sensitive URL), 16 (`GoRouteData`), 17 (`ShellRoute`
  observer), 18 (`metadata`) breaking'lerinin hiçbiri bu uygulamaya dokunmuyor;
  `redirect` imzası aynı. **Kod değişikliği sıfır**, `level_select_screen_test`
  ve router testleri değişmeden geçti.

### 3. firebase_analytics 12 / crashlytics 5 / remote_config 6 (core 4 transitive)
- Dart API değişmedi; breaking'ler native SDK (Android BoM 34, iOS 12).
  Firebase init edilmediği için risk derleme düzeyinde; derleme temiz.
- `firebase_core` pubspec'te direct değil, transitive kaldı (init yazılınca eklenir).
- **KGP uyarısı bump ile gitmedi**, aksine core ve crashlytics de listeye girdi.

### 3b. Built-in Kotlin geçişi (`android/gradle.properties`)
- `android.builtInKotlin=false` (Flutter şablon default'u) → `true`. Yeni firebase
  build.gradle'ları `apply plugin: 'kotlin-android'` satırını yalnız bu property
  false iken çalıştırıyor; bizde false olduğu için gerçekten KGP uyguluyorlardı.
- `settings.gradle.kts`'teki `org.jetbrains.kotlin.android ... apply false`
  bırakıldı: `app/build.gradle.kts`'deki `kotlin { compilerOptions { jvmTarget } }`
  bloğu KGP sınıflarına classpath'te ihtiyaç duyuyor; Flutter rehberi de bu
  bloğu "sonrası" hâli olarak veriyor. App tarafında başka değişiklik gerekmedi.
- **Tuzak:** Android dosyaları CRLF; `sed 's/...$/'` eşleşmedi, `\r\?$` gerekti.
- **KGP uyarısı hâlâ görünüyor — YANLIŞ POZİTİF.** Flutter'ın tespiti
  (`flutter_tools/gradle/.../FlutterPluginUtils.kt`, `kgpRegexGroovy`) Gradle
  runtime'ına değil plugin `build.gradle` **metnine** regex ile bakıyor ve
  firebase'in `if (agpMajor < 9 || !builtInKotlin) { apply plugin: 'kotlin-android' }`
  bloğundaki girintili satırı yakalıyor. Plugin build sırasında uygulanmıyor.
  Flutter regex'i ya da firebase build script'leri değişene kadar kozmetik; geçildi.

### 4. google_mobile_ads 8.0.0 → 9.1.0
- lib/ içinde henüz import yok (AdService yazılmadı). Kod değişikliği sıfır.
- Plugin 8.0.0 kaynağına atfedilen `deprecated API` javac notu gitti (kalan
  "Some input files use or override a deprecated API" başka plugin'lerden, bizim değil).

### 5. Impeller opt-out kaldırıldı (`AndroidManifest.xml`)
- `EnableImpeller=false` meta-data'sı `931d11d` ("fix recall, bot visibility, grid
  layout, rack recall") commit'inde eklenmişti; commit gövdesinde geçmiyor, yalnız
  manifest yorumu: emülatör GLES Impeller backend'i kararsız, native crash.
- Bu uyarı derleme çıktısında değil **runtime/logcat**'te görünüyordu; kaldırıldı.
- Emülatörde gözle doğrulanmadı → aşağıdaki liste.

### 6. Son `flutter pub outdated`
Direct ve dev dependency'ler tamamen güncel. Kalanlar:

| Paket | Durum | Kim |
|---|---|---|
| `platform` 3.1.6 → 3.2.0, `synchronized` 3.4.1+2 → 3.4.2 | lockfile'da kilitli, `flutter pub upgrade` ile gelir | transitive, isteğe bağlı |
| `material_color_utilities`, `package_config` | Flutter SDK pin'liyor | transitive, dokunulmaz |
| `_fe_analyzer_shared`, `analyzer`, `test`, `test_api`, `test_core` | `flutter_test` pin'liyor | transitive dev, dokunulmaz |

"incompatible" satırı kalmadı. Bizim tarafta yükseltilecek paket yok.

## Emülatörde senin kontrol edeceklerin (Impeller, GridPainter)

Uygulamayı **kaldırıp** yeniden kur (secure_storage anahtarı zaten geçersiz;
temiz kurulum "box recreated" logunu da eler).

1. **Soğuk başlatma:** logcat'te `EnableImpeller` deprecated uyarısı yok; Impeller
   backend satırı (Vulkan/GLES) görünüyor; native crash yok.
2. **Level select `/levels`:** grid tile'ları, kilit ikonları, dark + light mode.
3. **Oyun ekranı çerçeve:** 9×7 tam çerçeve; satır 0 / sütun 0 ipucu hücreleri,
   (0,0) boş; ipucu metni auto-fit ve Türkçe karakterler (ğ, ş, ı, İ) doğru.
4. **Kenar okları / çift-ipucu** hücreleri: ok yönleri doğru, çizgi kalınlığı
   ve anti-alias bozulmamış (Impeller'da ince çizgi/stroke farkı olabilir).
5. **InteractiveViewer zoom/pan:** statik katman bulanıklaşmıyor, yeniden
   çizim takılmıyor.
6. **Harf yerleştirme:** tap ve drag&drop; uçan tile görsel merkezine hizalı
   (`feedbackOffset`), grid dışına bırakınca rack'e dönüş.
7. **Anlatım animasyonları:** bot harfleri avatardan uçuyor; yanlış harf hücreden
   rack'e uçarak dönüyor; kelime tamamlama altın çerçeve + ışıltı; skora uçan
   rozetler ve sayan sayaç; ekrana dokunma = 2× hız. Kare atlama / flicker var mı?
8. **Seçim/parıltı katmanı:** idle'da repaint yok (DevTools "Repaint Rainbow"
   ile bakılabilir); seçim vurgusu statik katmanın üstünde doğru konumda.
9. **Sheet/dialog:** ipucu sheet, swap sheet, sonuç dialog'u — şeffaflık ve
   blur Impeller'da doğru.
10. **Resume:** süreci öldür → yeniden aç → "Devam Et" banner'ı çıkıyor
    (secure_storage v11 anahtarı bu kez kalıcı).

Bir şey bozuksa: `flutter run --no-enable-impeller` ile aynı akışı tekrarla;
farkı gösteren ekran görüntüsünü ilet, Impeller'a özgü olup olmadığı böyle ayrılır.

## Sonraki adımlar
- Yukarıdaki emülatör doğrulaması.
- İsteğe bağlı: `flutter pub upgrade` ile `platform`/`synchronized` lockfile bump'ı.
- KGP yanlış pozitifi: Flutter upstream'de regex düzeltmesi çıkınca otomatik kapanır;
  takip için ayrı iş yok.
