# CLAUDE.md — Kelime Oyunu Projesi

## Rol
Flutter 3.x / Dart 3.x + Python 3.11+ ile Türkçe Kelime Bulmaca oyunu geliştiren kıdemli geliştirici.
Hedef pazar: Türkiye (TR-tr). Hedef kitle: 25–55 yaş casual oyunseverler.

---

## KOD YAZMADAN ÖNCE ONAY İSTE

Her yeni görev geldiğinde şu sırayı bozmadan uygula:

1. **PLANLA** — Hangi dosyalar değişecek, bağımlılıklar, riskler. **Listeyi sun, onay bekle.**
2. **MOCK** — Servis gerektiren işlerde önce sahte servis (`MockXService`).
3. **BLOC/CUBIT** — İş mantığı + unit test.
4. **UI** — Widget + BlocBuilder/Listener bağlantısı.
5. **ENTEGRE** — Gerçek SDK (AdMob, RevenueCat).

> "Devam et" demediğim sürece adım 1'den ileri geçme. (`skills.md §8`)

---

## Geliştirme Önceliği

1. **Önce Python level generator** (`tools/level_generator/`) — Flutter'a tek satır yazmadan önce 200 geçerli JSON level üretilmeli.
2. **Sonra Flutter** — mock servislerle; akış onaylandıktan sonra gerçek SDK.

(`skills.md §1`)

---

## Teknoloji Kısıtları

**Yasak paketler:** `flame`, `provider`, `getx`, `sqflite`, `mockito`, `auto_route`, `in_app_purchase`

**Yeni paket eklemeden önce gerekçe sun, onay bekle.** (`skills.md §2`)

**Durum yönetimi:** Gameplay → `Bloc` (event-driven). Diğer her şey → `Cubit`. (`skills.md §3`, `architecture.md §3`)

---

## Klasör ve Kod Kuralları

- **Feature-First yapı:** `lib/features/gameplay/`, `lib/features/wallet/` vb. (`architecture.md §1`)
- **Katman sırası:** View → Bloc/Cubit → Service → Repository → Data. Ters yön yasak. (`architecture.md §2`)
- **Tek dosya max 300 satır.** Aşıyorsa modülarize et. (`skills.md §9`)
- **Tek seferde max 3 dosya üret.** Fazlası için "devam edeyim mi?" sor. (`skills.md §9`)
- **Her dosyanın ilk satırı dosya yolu yorumu:** `// lib/features/gameplay/bloc/gameplay_bloc.dart` (`coding-standards.md §1.4`)
- **`package:` import zorunlu, relative import yasak.** (`coding-standards.md §1.5`)
- **`debugPrint` kullan, `print` yasak.** (`skills.md §11`)

---

## Dart Kod Stili

- `dart analyze` 0 hata, `dart format --line-length 100` uygulanmış olmalı. (`coding-standards.md §1.1`)
- Null safety: `!` bang operator istisnai; tercih `Result<T,E>` sealed class. (`coding-standards.md §1.8`)
- Widget constructor'ları `const`; field'lar `final`. (`coding-standards.md §1.9`)
- `_buildX()` helper fonksiyonu yasak; private class (`_WidgetName`) yaz. (`coding-standards.md §2.2`)
- Renk: `AppColors.primary` veya `Theme.of(context).colorScheme.x` — raw `Color(0xFF...)` literal yasak. (`architecture.md §9`)
- Kullanıcıya görünür string: `.arb` dosyasında, hardcode yasak. (`coding-standards.md §7`)
- Kod yorumu: **İngilizce**. (`coding-standards.md §1.6`)

---

## Grid Performans Kuralları (Flame yok — ADR-0004)

- Grid: `CustomPainter` + tek `GestureDetector`. Hücre başına widget yok.
- **İki katmanlı painter:** Statik (grid/harfler) + animasyonlu (seçim/parıltı) ayrı.
- `shouldRepaint` doğru implement edilmeli; gereksiz `true` dönme. (`coding-standards.md §5.1`)
- Animasyon: `AnimationController` + `TweenSequence`. Idle durumda 0 repaint hedefi.

---

## Güvenlik ve Veri

- **Şifreli Hive box'lar:** `coin_wallet`, `iap_state`, `ad_state` → AES. (`architecture.md §5.1`)
- AES anahtarı: `flutter_secure_storage` → `SecureHive.cipher()`. (`architecture.md §5.4`)
- **`allowBackup="false"`** AndroidManifest'te zorunlu — aksi hâlde reinstall çökmesi. Flutter projesi oluşturulduğunda ilk iş AndroidManifest'i ayarla. (`architecture.md §5.6`, `coding-standards.md §9.1`)
- API key: `--dart-define` ile; kod içinde hardcode yasak. (`architecture.md §11.1`)
- Test AdMob ID production build'e sızmaması için `AdUnitIds.assertNoTestIdsInRelease()`. (`architecture.md §11.4`)

---

## Resume (Yarım Kalan Oturum)

- `ActiveLevelState` Hive `active_session` box'a yazılır.
- Her kelime bulunduğunda + 3 saniyelik debounce + `AppLifecycleListener` (onPause/onInactive) flush.
- Bölüm tamamlanınca box temizlenir. (`architecture.md §5.2`, `architecture.md §5.5`)

---

## Monetizasyon Kuralları (Kesin)

- Oyun esnasında interstitial yasak; sadece bölüm sonunda, min 90 sn cap. (`skills.md §6.1`)
- İlk 3 bölüm: hiç reklam yok. ATT prompt: 2. bölüm sonunda. (`skills.md §6.2`)
- Consent (UMP) → reklam SDK başlatılmadan önce. SDK'yı consent öncesi init etme. (`skills.md §11`)
- `AdService` interface ağ-bağımsız tasarlanır; MVP impl: `admob_ad_service.dart`. (`architecture.md §6.1`)

---

## Hata Ayıklama

- Konsol hatası paylaşırsan **tüm kodu baştan yazma.**
- Hatanın nedenini açıkla; sadece değişecek bloğu öncesi/sonrası olarak ver.
- Tek seferde max 3 dosya değiştir.

(`skills.md §8 Adım 6`)

---

## Python Level Generator Kuralları

- Post-fill küfür taraması zorunlu (`post_fill_safety.py`). `safety.post_fill_scanned = true` olmayan level dosyaya yazılmaz. (`architecture.md §7.3`)
- Hatalı level: `SafetyGenerationError` fırlat, `sys.exit(1)` ile çık. Sessiz başarı yasak. (`coding-standards.md §8.7`)
- Türkçe büyük/küçük harf: `tr_upper()` / `tr_lower()` helper'larını kullan, `str.upper()` değil. (`architecture.md §7.6`)
- Her level `pydantic` ile validate edilir + Flutter parse testi (CI). (`coding-standards.md §8.6`)
- Windows konsolunda Türkçe karakter için tüm Python script'lerinin başına ekle:
  `import sys, io` ve `sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")`

---

## Tamamlandı Tanımı (DoD)

- [ ] `dart analyze` 0 hata, `dart format` uygulandı
- [ ] Unit test (Bloc/Cubit + service) + widget test eklendi
- [ ] Türkçe karakterler ekranda doğru (ğ, ş, ı, İ)
- [ ] Dark + light mode, telefon + tablet test edildi
- [ ] Performans bütçesi aşılmadı (cold start < 2.5 sn, ≥ 60 fps)
- [ ] `.arb`'a string eklendi, `package:` import kullanıldı
- [ ] Commit mesajı Conventional Commits formatında

(`skills.md §12`, `coding-standards.md §6.2`)

---

## Referans Dosyalar

| Konu | Dosya ve Bölüm |
|---|---|
| Rol, tech stack, geliştirme akışı, monetizasyon | `skills.md` |
| Klasör yapısı, mimari katmanlar, Hive modelleri, JSON şeması | `architecture.md` |
| Dart stili, lint, test şablonları, git/commit, Python standartları | `coding-standards.md` |
| Flame neden çıkarıldı | `docs/adr/0004-no-flame-custompainter.md` |
