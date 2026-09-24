// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Kelime Zirvesi';

  @override
  String get appNameStacked => 'Kelime\nZirvesi';

  @override
  String get homeTag => 'RAKİBE KARŞI ÇENGEL BULMACA';

  @override
  String get now => 'Şu an';

  @override
  String get level => 'Bölüm';

  @override
  String get streak => 'Bugünün serisi';

  @override
  String get words => 'Bulunan kelime';

  @override
  String get day => 'gün';

  @override
  String get resume => 'Yarım kalan oyun';

  @override
  String get noSave => 'Kaydedilmiş oyun yok';

  @override
  String get noSaveSub => 'Yeni bölüme başlamak için aşağıya dokun';

  @override
  String get continueClimb => 'Tırmanışa devam et';

  @override
  String startLevel(int n) {
    return 'Bölüm $n ile başla';
  }

  @override
  String get map => 'Harita';

  @override
  String get settings => 'Ayarlar';

  @override
  String get you => 'Sen';

  @override
  String get bot => 'Rakip';

  @override
  String get vs => 'VS';

  @override
  String get turnYou => 'Sıra sende';

  @override
  String turnPending(int n) {
    return '$n harf bekliyor · onayla';
  }

  @override
  String get turnTap => 'Boş bir hücreye dokun';

  @override
  String get turnBot => 'Rakip düşünüyor';

  @override
  String get botTurnBtn => 'Sıra rakipte';

  @override
  String get confirm => 'Onayla';

  @override
  String get pass => 'Pas';

  @override
  String get addLetter => 'HARF EKLE';

  @override
  String get hint => 'İPUCU AL';

  @override
  String get ad => 'reklam';

  @override
  String get swap => 'Harf değiştir';

  @override
  String wordDone(String w, int n) {
    return '$w · +$n puan';
  }

  @override
  String get wrongLetter => 'Bu harf buraya uymuyor';

  @override
  String get offline => 'Bağlantı yok · reklam yüklenemedi';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get clues => 'İpuçları';

  @override
  String get right => 'SAĞA';

  @override
  String get down => 'AŞAĞI';

  @override
  String get letters => 'HARF';

  @override
  String get close => 'Kapat';

  @override
  String get swapLeft => 'Kalan hak';

  @override
  String get swapSub => 'Değiştirmek istediğin harflere dokun.';

  @override
  String get swapNow => 'Şimdi değiştir';

  @override
  String get swapKeep => 'sıra sende kalır';

  @override
  String get swapPass => 'Değiştir ve pas';

  @override
  String get swapFree => 'ücretsiz, sıra rakibe';

  @override
  String get won => 'KAZANDIN';

  @override
  String get wonH => 'Bir adım daha\nzirveye';

  @override
  String wonCta(int n) {
    return 'Bölüm $n · tırmanmaya devam';
  }

  @override
  String get again => 'Tekrar oyna';

  @override
  String get lost => 'KAYBETTİN';

  @override
  String get lostH => 'Kampta\nbir gece daha';

  @override
  String get lostSub =>
      'Rakip bu eli aldı. Aynı yerden yeniden dene; yükseklik kaybı yok.';

  @override
  String get tryAgain => 'Tekrar dene';

  @override
  String get backMap => 'Haritaya dön';

  @override
  String get draw => 'BERABERE';

  @override
  String get drawH => 'Berabere ·\nRakiple başa baş';

  @override
  String get drawSub =>
      'Puanlar eşit. Aynı kamptan yeniden dene; yükseklik kaybı yok.';

  @override
  String get diff => 'fark';

  @override
  String get climb => 'TIRMANIŞ';

  @override
  String get fogUp => 'yukarısı sisin içinde…';

  @override
  String get camp => 'Kamp · başlangıç';

  @override
  String get here => 'BURADASIN';

  @override
  String get onbSkip => 'Atla';

  @override
  String get onbNext => 'Devam';

  @override
  String get onb1 => 'İpucunu oku, harfi yerleştir';

  @override
  String get onb1Sub =>
      'Ok hangi yöne gidiyorsa kelime o yöne yazılır. Tepsiden bir harf seç, boş hücreye dokun.';

  @override
  String get onbSteps1 => 'İpucu';

  @override
  String get onbSteps2 => 'Harf koy';

  @override
  String get onbSteps3 => 'Onayla';

  @override
  String get onbSteps4 => 'Rakip cevap verir';

  @override
  String get consentTag => 'HOŞ GELDİN';

  @override
  String get consentH => 'Tırmanışa başlamadan önce';

  @override
  String get consentTitle => 'Reklamlar ve veri';

  @override
  String get consentBody =>
      'Kelime Zirvesi ücretsiz; jokerler ve ekstra harfler kısa reklamlarla açılır. İlk 3 bölümde hiç reklam gösterilmez. Kişiselleştirilmiş reklam için onayın gerekir; onay vermezsen genel reklamlar gösterilir.';

  @override
  String get privacy => 'Gizlilik politikası';

  @override
  String get terms => 'Kullanım koşulları';

  @override
  String get accept => 'Kabul et ve başla';

  @override
  String get manage => 'Seçenekleri yönet';

  @override
  String get attTag => 'BİR ADIM KALDI';

  @override
  String get attH => 'Takip izni hakkında';

  @override
  String get attBody =>
      'Bir sonraki adımda iOS, uygulamalar arası takip için izin isteyecek. İzin verirsen reklamlar ilgi alanlarına göre seçilir; vermezsen oyun aynen devam eder, reklamlar genel olur.';

  @override
  String get attCta => 'Devam';

  @override
  String get attLater => 'Şimdi değil';

  @override
  String get appearance => 'Görünüm';

  @override
  String get appLight => 'Açık';

  @override
  String get appDark => 'Koyu';

  @override
  String get appSystem => 'Sistem';

  @override
  String get sound => 'Ses';

  @override
  String get soundSub => 'Harf ve puan sesleri';

  @override
  String get haptic => 'Titreşim';

  @override
  String get hapticSub => 'Harf yerleşince hafif dokunuş';

  @override
  String get sky => 'Gökyüzü';

  @override
  String get skySub => 'Arka plan ilerlemeyle değişir';

  @override
  String get game => 'OYUN';

  @override
  String get account => 'HESAP';

  @override
  String get removeAds => 'Reklamları kaldır';

  @override
  String get shopLink => 'Mağaza →';

  @override
  String get adPrefs => 'Reklam tercihleri';

  @override
  String get reset => 'İlerlemeyi sıfırla';

  @override
  String get del => 'Sil';

  @override
  String get version => 'Kelime Zirvesi 1.0.0';

  @override
  String get shop => 'Kamp dükkânı';

  @override
  String get oneTime => 'TEK SEFERLİK';

  @override
  String get adFree => 'Reklamsız tırmanış';

  @override
  String get adFreeSub =>
      'Bölüm sonu reklamları kalkar. Jokerlerdeki reklam yerine kamp parası kullanılır.';

  @override
  String get coins => 'KAMP PARASI';

  @override
  String unlockN(int n) {
    return '≈ $n harf açma';
  }

  @override
  String get mostBought => 'EN ÇOK ALINAN';

  @override
  String get free => 'ÜCRETSİZ';

  @override
  String get daily => 'Günlük kamp ateşi';

  @override
  String get dailySub => 'Her gün 20 para';

  @override
  String get getReward => 'Al';

  @override
  String get restore => 'Satın alımları geri yükle';

  @override
  String get price1 => '₺89,99';

  @override
  String get price2 => '₺29,99';

  @override
  String get price3 => '₺79,99';

  @override
  String get legalUpdated => 'Son güncelleme · 20 Eylül 2026';

  @override
  String get legal1 => 'Hangi verileri topluyoruz';

  @override
  String get legal2 => 'Reklam ortakları';

  @override
  String get legal3 => 'Cihazda saklanan veriler';

  @override
  String get slogans1 => 'rakibe karşı bulmaca düellosu';

  @override
  String get slogans2 => 'Kelime kelime zirveye tırman';

  @override
  String get slogans3 => 'Her galibiyet 40 metre daha yukarı';

  @override
  String get slogans4 => 'İpuçları bir dokunuş uzakta';

  @override
  String get slogans5 => 'Zirveye giden yol sonsuz';

  @override
  String get clue => 'İpucu';

  @override
  String get levels => 'Bölümler';

  @override
  String levelOfTotal(int n, int total) {
    return 'Bölüm $n / $total';
  }

  @override
  String levelsProgress(int done, int total) {
    return '$done/$total bölüm tamamlandı';
  }

  @override
  String levelsAllDone(int total) {
    return 'Tüm bölümler tamamlandı! ($total/$total)';
  }

  @override
  String get allLevelsDone => 'Tüm bölümleri bitirdin! 🎉';

  @override
  String scoreGap(int d) {
    return 'fark $d';
  }

  @override
  String resumeScore(int n, int p, int b) {
    return 'Bölüm $n · Sen $p – Rakip $b';
  }

  @override
  String swapLeftCount(int n) {
    return 'Kalan hak · $n harf';
  }

  @override
  String get revealConfirmTitle =>
      'Bu kelimeyi açmak istediğinize emin misiniz?';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get sixthSlotTitle => '+1 harf jokeri';

  @override
  String get sixthSlotBody =>
      'Reklam izleyerek 6. harf yuvasını açmak ister misin? Bu maç boyunca her el 6 harfle oynarsın; eli boşaltırsan +6 bonus!';

  @override
  String levelDone(int n) {
    return 'Bölüm $n, tamamlandı';
  }

  @override
  String levelCurrent(int n) {
    return 'Bölüm $n, sıradaki bölüm';
  }

  @override
  String levelLocked(int n) {
    return 'Bölüm $n, kilitli';
  }

  @override
  String get botDescription => 'Zirveye giden yolda rakibin.';

  @override
  String get levelTag => 'BÖLÜM';

  @override
  String clueCellPosition(int row, int col) {
    return '$row. satır · $col. sütun';
  }

  @override
  String clueCellPositionDouble(int row, int col) {
    return '$row. satır · $col. sütun — bu hücre iki kelimeye açılıyor';
  }

  @override
  String swapSelected(int n) {
    return '$n harf seçildi';
  }

  @override
  String get swapNone => 'Henüz harf seçilmedi';
}
