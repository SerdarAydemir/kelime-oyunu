import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In tr, this message translates to:
  /// **'Kelime Zirvesi'**
  String get appName;

  /// No description provided for @appNameStacked.
  ///
  /// In tr, this message translates to:
  /// **'Kelime\nZirvesi'**
  String get appNameStacked;

  /// No description provided for @homeTag.
  ///
  /// In tr, this message translates to:
  /// **'RAKİBE KARŞI ÇENGEL BULMACA'**
  String get homeTag;

  /// No description provided for @now.
  ///
  /// In tr, this message translates to:
  /// **'Şu an'**
  String get now;

  /// No description provided for @level.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm'**
  String get level;

  /// No description provided for @streak.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün serisi'**
  String get streak;

  /// No description provided for @words.
  ///
  /// In tr, this message translates to:
  /// **'Bulunan kelime'**
  String get words;

  /// No description provided for @day.
  ///
  /// In tr, this message translates to:
  /// **'gün'**
  String get day;

  /// No description provided for @resume.
  ///
  /// In tr, this message translates to:
  /// **'Yarım kalan oyun'**
  String get resume;

  /// No description provided for @noSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmiş oyun yok'**
  String get noSave;

  /// No description provided for @noSaveSub.
  ///
  /// In tr, this message translates to:
  /// **'Yeni bölüme başlamak için aşağıya dokun'**
  String get noSaveSub;

  /// No description provided for @continueClimb.
  ///
  /// In tr, this message translates to:
  /// **'Tırmanışa devam et'**
  String get continueClimb;

  /// No description provided for @startLevel.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n} ile başla'**
  String startLevel(int n);

  /// No description provided for @map.
  ///
  /// In tr, this message translates to:
  /// **'Harita'**
  String get map;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @you.
  ///
  /// In tr, this message translates to:
  /// **'Sen'**
  String get you;

  /// No description provided for @bot.
  ///
  /// In tr, this message translates to:
  /// **'Rakip'**
  String get bot;

  /// No description provided for @vs.
  ///
  /// In tr, this message translates to:
  /// **'VS'**
  String get vs;

  /// No description provided for @turnYou.
  ///
  /// In tr, this message translates to:
  /// **'Sıra sende'**
  String get turnYou;

  /// No description provided for @turnPending.
  ///
  /// In tr, this message translates to:
  /// **'{n} harf bekliyor · onayla'**
  String turnPending(int n);

  /// No description provided for @turnTap.
  ///
  /// In tr, this message translates to:
  /// **'Boş bir hücreye dokun'**
  String get turnTap;

  /// No description provided for @turnBot.
  ///
  /// In tr, this message translates to:
  /// **'Rakip düşünüyor'**
  String get turnBot;

  /// No description provided for @botTurnBtn.
  ///
  /// In tr, this message translates to:
  /// **'Sıra rakipte'**
  String get botTurnBtn;

  /// No description provided for @confirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get confirm;

  /// No description provided for @pass.
  ///
  /// In tr, this message translates to:
  /// **'Pas'**
  String get pass;

  /// No description provided for @addLetter.
  ///
  /// In tr, this message translates to:
  /// **'HARF EKLE'**
  String get addLetter;

  /// No description provided for @hint.
  ///
  /// In tr, this message translates to:
  /// **'İPUCU AL'**
  String get hint;

  /// No description provided for @ad.
  ///
  /// In tr, this message translates to:
  /// **'reklam'**
  String get ad;

  /// No description provided for @swap.
  ///
  /// In tr, this message translates to:
  /// **'Harf değiştir'**
  String get swap;

  /// No description provided for @wordDone.
  ///
  /// In tr, this message translates to:
  /// **'{w} · +{n} puan'**
  String wordDone(String w, int n);

  /// No description provided for @wrongLetter.
  ///
  /// In tr, this message translates to:
  /// **'Bu harf buraya uymuyor'**
  String get wrongLetter;

  /// No description provided for @offline.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok · reklam yüklenemedi'**
  String get offline;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get retry;

  /// No description provided for @clues.
  ///
  /// In tr, this message translates to:
  /// **'İpuçları'**
  String get clues;

  /// No description provided for @right.
  ///
  /// In tr, this message translates to:
  /// **'SAĞA'**
  String get right;

  /// No description provided for @down.
  ///
  /// In tr, this message translates to:
  /// **'AŞAĞI'**
  String get down;

  /// No description provided for @letters.
  ///
  /// In tr, this message translates to:
  /// **'HARF'**
  String get letters;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @swapLeft.
  ///
  /// In tr, this message translates to:
  /// **'Kalan hak'**
  String get swapLeft;

  /// No description provided for @swapSub.
  ///
  /// In tr, this message translates to:
  /// **'Değiştirmek istediğin harflere dokun.'**
  String get swapSub;

  /// No description provided for @swapNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi değiştir'**
  String get swapNow;

  /// No description provided for @swapKeep.
  ///
  /// In tr, this message translates to:
  /// **'sıra sende kalır'**
  String get swapKeep;

  /// No description provided for @swapPass.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir ve pas'**
  String get swapPass;

  /// No description provided for @swapFree.
  ///
  /// In tr, this message translates to:
  /// **'ücretsiz, sıra rakibe'**
  String get swapFree;

  /// No description provided for @won.
  ///
  /// In tr, this message translates to:
  /// **'KAZANDIN'**
  String get won;

  /// No description provided for @wonH.
  ///
  /// In tr, this message translates to:
  /// **'Bir adım daha\nzirveye'**
  String get wonH;

  /// No description provided for @wonCta.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n} · tırmanmaya devam'**
  String wonCta(int n);

  /// No description provided for @again.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar oyna'**
  String get again;

  /// No description provided for @lost.
  ///
  /// In tr, this message translates to:
  /// **'KAYBETTİN'**
  String get lost;

  /// No description provided for @lostH.
  ///
  /// In tr, this message translates to:
  /// **'Kampta\nbir gece daha'**
  String get lostH;

  /// No description provided for @lostSub.
  ///
  /// In tr, this message translates to:
  /// **'Rakip bu eli aldı. Aynı yerden yeniden dene; yükseklik kaybı yok.'**
  String get lostSub;

  /// No description provided for @tryAgain.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get tryAgain;

  /// No description provided for @backMap.
  ///
  /// In tr, this message translates to:
  /// **'Haritaya dön'**
  String get backMap;

  /// No description provided for @draw.
  ///
  /// In tr, this message translates to:
  /// **'BERABERE'**
  String get draw;

  /// No description provided for @drawH.
  ///
  /// In tr, this message translates to:
  /// **'Berabere ·\nRakiple başa baş'**
  String get drawH;

  /// No description provided for @drawSub.
  ///
  /// In tr, this message translates to:
  /// **'Puanlar eşit. Aynı kamptan yeniden dene; yükseklik kaybı yok.'**
  String get drawSub;

  /// No description provided for @diff.
  ///
  /// In tr, this message translates to:
  /// **'fark'**
  String get diff;

  /// No description provided for @climb.
  ///
  /// In tr, this message translates to:
  /// **'TIRMANIŞ'**
  String get climb;

  /// No description provided for @fogUp.
  ///
  /// In tr, this message translates to:
  /// **'yukarısı sisin içinde…'**
  String get fogUp;

  /// No description provided for @camp.
  ///
  /// In tr, this message translates to:
  /// **'Kamp · başlangıç'**
  String get camp;

  /// No description provided for @here.
  ///
  /// In tr, this message translates to:
  /// **'BURADASIN'**
  String get here;

  /// No description provided for @onbSkip.
  ///
  /// In tr, this message translates to:
  /// **'Atla'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get onbNext;

  /// No description provided for @onb1.
  ///
  /// In tr, this message translates to:
  /// **'İpucunu oku, harfi yerleştir'**
  String get onb1;

  /// No description provided for @onb1Sub.
  ///
  /// In tr, this message translates to:
  /// **'Ok hangi yöne gidiyorsa kelime o yöne yazılır. Tepsiden bir harf seç, boş hücreye dokun.'**
  String get onb1Sub;

  /// No description provided for @onbSteps1.
  ///
  /// In tr, this message translates to:
  /// **'İpucu'**
  String get onbSteps1;

  /// No description provided for @onbSteps2.
  ///
  /// In tr, this message translates to:
  /// **'Harf koy'**
  String get onbSteps2;

  /// No description provided for @onbSteps3.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get onbSteps3;

  /// No description provided for @onbSteps4.
  ///
  /// In tr, this message translates to:
  /// **'Rakip cevap verir'**
  String get onbSteps4;

  /// No description provided for @consentTag.
  ///
  /// In tr, this message translates to:
  /// **'HOŞ GELDİN'**
  String get consentTag;

  /// No description provided for @consentH.
  ///
  /// In tr, this message translates to:
  /// **'Tırmanışa başlamadan önce'**
  String get consentH;

  /// No description provided for @consentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Reklamlar ve veri'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In tr, this message translates to:
  /// **'Kelime Zirvesi ücretsiz; jokerler ve ekstra harfler kısa reklamlarla açılır. İlk 3 bölümde hiç reklam gösterilmez. Kişiselleştirilmiş reklam için onayın gerekir; onay vermezsen genel reklamlar gösterilir.'**
  String get consentBody;

  /// No description provided for @privacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik politikası'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım koşulları'**
  String get terms;

  /// No description provided for @accept.
  ///
  /// In tr, this message translates to:
  /// **'Kabul et ve başla'**
  String get accept;

  /// No description provided for @manage.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekleri yönet'**
  String get manage;

  /// No description provided for @attTag.
  ///
  /// In tr, this message translates to:
  /// **'BİR ADIM KALDI'**
  String get attTag;

  /// No description provided for @attH.
  ///
  /// In tr, this message translates to:
  /// **'Takip izni hakkında'**
  String get attH;

  /// No description provided for @attBody.
  ///
  /// In tr, this message translates to:
  /// **'Bir sonraki adımda iOS, uygulamalar arası takip için izin isteyecek. İzin verirsen reklamlar ilgi alanlarına göre seçilir; vermezsen oyun aynen devam eder, reklamlar genel olur.'**
  String get attBody;

  /// No description provided for @attCta.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get attCta;

  /// No description provided for @attLater.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi değil'**
  String get attLater;

  /// No description provided for @appearance.
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get appearance;

  /// No description provided for @appLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get appLight;

  /// No description provided for @appDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get appDark;

  /// No description provided for @appSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get appSystem;

  /// No description provided for @sound.
  ///
  /// In tr, this message translates to:
  /// **'Ses'**
  String get sound;

  /// No description provided for @soundSub.
  ///
  /// In tr, this message translates to:
  /// **'Harf ve puan sesleri'**
  String get soundSub;

  /// No description provided for @haptic.
  ///
  /// In tr, this message translates to:
  /// **'Titreşim'**
  String get haptic;

  /// No description provided for @hapticSub.
  ///
  /// In tr, this message translates to:
  /// **'Harf yerleşince hafif dokunuş'**
  String get hapticSub;

  /// No description provided for @sky.
  ///
  /// In tr, this message translates to:
  /// **'Gökyüzü'**
  String get sky;

  /// No description provided for @skySub.
  ///
  /// In tr, this message translates to:
  /// **'Arka plan ilerlemeyle değişir'**
  String get skySub;

  /// No description provided for @game.
  ///
  /// In tr, this message translates to:
  /// **'OYUN'**
  String get game;

  /// No description provided for @account.
  ///
  /// In tr, this message translates to:
  /// **'HESAP'**
  String get account;

  /// No description provided for @removeAds.
  ///
  /// In tr, this message translates to:
  /// **'Reklamları kaldır'**
  String get removeAds;

  /// No description provided for @shopLink.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza →'**
  String get shopLink;

  /// No description provided for @adPrefs.
  ///
  /// In tr, this message translates to:
  /// **'Reklam tercihleri'**
  String get adPrefs;

  /// No description provided for @reset.
  ///
  /// In tr, this message translates to:
  /// **'İlerlemeyi sıfırla'**
  String get reset;

  /// No description provided for @del.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get del;

  /// No description provided for @version.
  ///
  /// In tr, this message translates to:
  /// **'Kelime Zirvesi 1.0.0'**
  String get version;

  /// No description provided for @shop.
  ///
  /// In tr, this message translates to:
  /// **'Kamp dükkânı'**
  String get shop;

  /// No description provided for @oneTime.
  ///
  /// In tr, this message translates to:
  /// **'TEK SEFERLİK'**
  String get oneTime;

  /// No description provided for @adFree.
  ///
  /// In tr, this message translates to:
  /// **'Reklamsız tırmanış'**
  String get adFree;

  /// No description provided for @adFreeSub.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm sonu reklamları kalkar. Jokerlerdeki reklam yerine kamp parası kullanılır.'**
  String get adFreeSub;

  /// No description provided for @coins.
  ///
  /// In tr, this message translates to:
  /// **'KAMP PARASI'**
  String get coins;

  /// No description provided for @unlockN.
  ///
  /// In tr, this message translates to:
  /// **'≈ {n} harf açma'**
  String unlockN(int n);

  /// No description provided for @mostBought.
  ///
  /// In tr, this message translates to:
  /// **'EN ÇOK ALINAN'**
  String get mostBought;

  /// No description provided for @free.
  ///
  /// In tr, this message translates to:
  /// **'ÜCRETSİZ'**
  String get free;

  /// No description provided for @daily.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kamp ateşi'**
  String get daily;

  /// No description provided for @dailySub.
  ///
  /// In tr, this message translates to:
  /// **'Her gün 20 para'**
  String get dailySub;

  /// No description provided for @getReward.
  ///
  /// In tr, this message translates to:
  /// **'Al'**
  String get getReward;

  /// No description provided for @restore.
  ///
  /// In tr, this message translates to:
  /// **'Satın alımları geri yükle'**
  String get restore;

  /// No description provided for @price1.
  ///
  /// In tr, this message translates to:
  /// **'₺89,99'**
  String get price1;

  /// No description provided for @price2.
  ///
  /// In tr, this message translates to:
  /// **'₺29,99'**
  String get price2;

  /// No description provided for @price3.
  ///
  /// In tr, this message translates to:
  /// **'₺79,99'**
  String get price3;

  /// No description provided for @legalUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Son güncelleme · 20 Eylül 2026'**
  String get legalUpdated;

  /// No description provided for @legal1.
  ///
  /// In tr, this message translates to:
  /// **'Hangi verileri topluyoruz'**
  String get legal1;

  /// No description provided for @legal2.
  ///
  /// In tr, this message translates to:
  /// **'Reklam ortakları'**
  String get legal2;

  /// No description provided for @legal3.
  ///
  /// In tr, this message translates to:
  /// **'Cihazda saklanan veriler'**
  String get legal3;

  /// No description provided for @slogans1.
  ///
  /// In tr, this message translates to:
  /// **'rakibe karşı bulmaca düellosu'**
  String get slogans1;

  /// No description provided for @slogans2.
  ///
  /// In tr, this message translates to:
  /// **'Kelime kelime zirveye tırman'**
  String get slogans2;

  /// No description provided for @slogans3.
  ///
  /// In tr, this message translates to:
  /// **'Her galibiyet 40 metre daha yukarı'**
  String get slogans3;

  /// No description provided for @slogans4.
  ///
  /// In tr, this message translates to:
  /// **'İpuçları bir dokunuş uzakta'**
  String get slogans4;

  /// No description provided for @slogans5.
  ///
  /// In tr, this message translates to:
  /// **'Zirveye giden yol sonsuz'**
  String get slogans5;

  /// No description provided for @clue.
  ///
  /// In tr, this message translates to:
  /// **'İpucu'**
  String get clue;

  /// No description provided for @levels.
  ///
  /// In tr, this message translates to:
  /// **'Bölümler'**
  String get levels;

  /// No description provided for @levelOfTotal.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n} / {total}'**
  String levelOfTotal(int n, int total);

  /// No description provided for @levelsProgress.
  ///
  /// In tr, this message translates to:
  /// **'{done}/{total} bölüm tamamlandı'**
  String levelsProgress(int done, int total);

  /// No description provided for @levelsAllDone.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bölümler tamamlandı! ({total}/{total})'**
  String levelsAllDone(int total);

  /// No description provided for @allLevelsDone.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bölümleri bitirdin! 🎉'**
  String get allLevelsDone;

  /// No description provided for @scoreGap.
  ///
  /// In tr, this message translates to:
  /// **'fark {d}'**
  String scoreGap(int d);

  /// No description provided for @resumeScore.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n} · Sen {p} – Rakip {b}'**
  String resumeScore(int n, int p, int b);

  /// No description provided for @swapLeftCount.
  ///
  /// In tr, this message translates to:
  /// **'Kalan hak · {n} harf'**
  String swapLeftCount(int n);

  /// No description provided for @revealConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu kelimeyi açmak istediğinize emin misiniz?'**
  String get revealConfirmTitle;

  /// No description provided for @yes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get no;

  /// No description provided for @sixthSlotTitle.
  ///
  /// In tr, this message translates to:
  /// **'+1 harf jokeri'**
  String get sixthSlotTitle;

  /// No description provided for @sixthSlotBody.
  ///
  /// In tr, this message translates to:
  /// **'Reklam izleyerek 6. harf yuvasını açmak ister misin? Bu maç boyunca her el 6 harfle oynarsın; eli boşaltırsan +6 bonus!'**
  String get sixthSlotBody;

  /// No description provided for @levelDone.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n}, tamamlandı'**
  String levelDone(int n);

  /// No description provided for @levelCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n}, sıradaki bölüm'**
  String levelCurrent(int n);

  /// No description provided for @levelLocked.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm {n}, kilitli'**
  String levelLocked(int n);

  /// No description provided for @botDescription.
  ///
  /// In tr, this message translates to:
  /// **'Zirveye giden yolda rakibin.'**
  String get botDescription;

  /// No description provided for @levelTag.
  ///
  /// In tr, this message translates to:
  /// **'BÖLÜM'**
  String get levelTag;

  /// No description provided for @clueCellPosition.
  ///
  /// In tr, this message translates to:
  /// **'{row}. satır · {col}. sütun'**
  String clueCellPosition(int row, int col);

  /// No description provided for @clueCellPositionDouble.
  ///
  /// In tr, this message translates to:
  /// **'{row}. satır · {col}. sütun — bu hücre iki kelimeye açılıyor'**
  String clueCellPositionDouble(int row, int col);

  /// No description provided for @swapSelected.
  ///
  /// In tr, this message translates to:
  /// **'{n} harf seçildi'**
  String swapSelected(int n);

  /// No description provided for @swapNone.
  ///
  /// In tr, this message translates to:
  /// **'Henüz harf seçilmedi'**
  String get swapNone;

  /// No description provided for @meters.
  ///
  /// In tr, this message translates to:
  /// **'{m} m'**
  String meters(int m);

  /// No description provided for @resetConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlerlemeyi sıfırla?'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bölümler, irtifa, seri ve kamp parası silinir. Bu işlem geri alınamaz.'**
  String get resetConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @adPrefsDone.
  ///
  /// In tr, this message translates to:
  /// **'Reklam tercihleri güncellendi'**
  String get adPrefsDone;

  /// No description provided for @attBullet1.
  ///
  /// In tr, this message translates to:
  /// **'İzin verirsen reklamlar ilgi alanlarına göre seçilir'**
  String get attBullet1;

  /// No description provided for @attBullet2.
  ///
  /// In tr, this message translates to:
  /// **'Vermezsen oyun aynen devam eder, reklamlar genel olur'**
  String get attBullet2;

  /// No description provided for @onb2.
  ///
  /// In tr, this message translates to:
  /// **'Harfi koy, onayla'**
  String get onb2;

  /// No description provided for @onb2Sub.
  ///
  /// In tr, this message translates to:
  /// **'Doğru harf yerinde kalır ve puan getirir; yanlış harf tepsine geri döner.'**
  String get onb2Sub;

  /// No description provided for @onb3.
  ///
  /// In tr, this message translates to:
  /// **'Rakip cevap verir'**
  String get onb3;

  /// No description provided for @onb3Sub.
  ///
  /// In tr, this message translates to:
  /// **'Her hamlenden sonra Rakip kendi harflerini koyar; tahta dolunca puanı yüksek olan kazanır.'**
  String get onb3Sub;

  /// No description provided for @onbProgress.
  ///
  /// In tr, this message translates to:
  /// **'{n} / 3'**
  String onbProgress(int n);

  /// No description provided for @howToPlay.
  ///
  /// In tr, this message translates to:
  /// **'Nasıl oynanır?'**
  String get howToPlay;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
