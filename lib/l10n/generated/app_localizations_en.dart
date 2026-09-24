// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Word Summit';

  @override
  String get appNameStacked => 'Word\nSummit';

  @override
  String get homeTag => 'CROSSWORD DUEL AGAINST AN OPPONENT';

  @override
  String get now => 'Now';

  @override
  String get level => 'Level';

  @override
  String get streak => 'Today\'s streak';

  @override
  String get words => 'Words found';

  @override
  String get day => 'days';

  @override
  String get resume => 'Unfinished game';

  @override
  String get noSave => 'No saved game';

  @override
  String get noSaveSub => 'Tap below to start a new level';

  @override
  String get continueClimb => 'Continue the climb';

  @override
  String startLevel(int n) {
    return 'Start level $n';
  }

  @override
  String get map => 'Map';

  @override
  String get settings => 'Settings';

  @override
  String get you => 'You';

  @override
  String get bot => 'Opponent';

  @override
  String get vs => 'VS';

  @override
  String get turnYou => 'Your turn';

  @override
  String turnPending(int n) {
    return '$n letters pending · confirm';
  }

  @override
  String get turnTap => 'Tap an empty cell';

  @override
  String get turnBot => 'Opponent is thinking';

  @override
  String get botTurnBtn => 'Opponent\'s turn';

  @override
  String get confirm => 'Confirm';

  @override
  String get pass => 'Pass';

  @override
  String get addLetter => 'ADD LETTER';

  @override
  String get hint => 'GET HINT';

  @override
  String get ad => 'ad';

  @override
  String get swap => 'Swap letters';

  @override
  String wordDone(String w, int n) {
    return '$w · +$n points';
  }

  @override
  String get wrongLetter => 'This letter doesn\'t fit here';

  @override
  String get offline => 'No connection · ad failed to load';

  @override
  String get retry => 'Retry';

  @override
  String get clues => 'Clues';

  @override
  String get right => 'ACROSS';

  @override
  String get down => 'DOWN';

  @override
  String get letters => 'LETTERS';

  @override
  String get close => 'Close';

  @override
  String get swapLeft => 'Remaining';

  @override
  String get swapSub => 'Tap the letters you want to swap.';

  @override
  String get swapNow => 'Swap now';

  @override
  String get swapKeep => 'keep your turn';

  @override
  String get swapPass => 'Swap and pass';

  @override
  String get swapFree => 'free, turn goes to opponent';

  @override
  String get won => 'YOU WON';

  @override
  String get wonH => 'One step closer\nto the summit';

  @override
  String wonCta(int n) {
    return 'Level $n · keep climbing';
  }

  @override
  String get again => 'Play again';

  @override
  String get lost => 'YOU LOST';

  @override
  String get lostH => 'One more night\nat camp';

  @override
  String get lostSub =>
      'Your opponent took this round. Try again from the same spot; no altitude lost.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get backMap => 'Back to map';

  @override
  String get draw => 'DRAW';

  @override
  String get drawH => 'A draw ·\nneck and neck with your opponent';

  @override
  String get drawSub =>
      'Scores are tied. Try again from the same camp; no altitude lost.';

  @override
  String get diff => 'gap';

  @override
  String get climb => 'THE CLIMB';

  @override
  String get fogUp => 'the way up is in the mist…';

  @override
  String get camp => 'Camp · start';

  @override
  String get here => 'YOU ARE HERE';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onb1 => 'Read the clue, place a letter';

  @override
  String get onb1Sub =>
      'The arrow shows where the word goes. Pick a letter from the rack and tap an empty cell.';

  @override
  String get onbSteps1 => 'Clue';

  @override
  String get onbSteps2 => 'Place letter';

  @override
  String get onbSteps3 => 'Confirm';

  @override
  String get onbSteps4 => 'Opponent replies';

  @override
  String get consentTag => 'WELCOME';

  @override
  String get consentH => 'Before you start climbing';

  @override
  String get consentTitle => 'Ads and data';

  @override
  String get consentBody =>
      'Word Summit is free; boosters and extra letters unlock with short ads. No ads in the first 3 levels. Personalized ads need your consent; otherwise you see generic ads.';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get terms => 'Terms of use';

  @override
  String get accept => 'Accept and start';

  @override
  String get manage => 'Manage options';

  @override
  String get attTag => 'ONE MORE STEP';

  @override
  String get attH => 'About tracking permission';

  @override
  String get attBody =>
      'Next, iOS will ask for permission to track across apps. If you allow it, ads match your interests; if not, the game continues as is with generic ads.';

  @override
  String get attCta => 'Continue';

  @override
  String get attLater => 'Not now';

  @override
  String get appearance => 'Appearance';

  @override
  String get appLight => 'Light';

  @override
  String get appDark => 'Dark';

  @override
  String get appSystem => 'System';

  @override
  String get sound => 'Sound';

  @override
  String get soundSub => 'Letter and score sounds';

  @override
  String get haptic => 'Haptics';

  @override
  String get hapticSub => 'Light tap when a letter lands';

  @override
  String get sky => 'Sky';

  @override
  String get skySub => 'Background changes with progress';

  @override
  String get game => 'GAME';

  @override
  String get account => 'ACCOUNT';

  @override
  String get removeAds => 'Remove ads';

  @override
  String get shopLink => 'Shop →';

  @override
  String get adPrefs => 'Ad preferences';

  @override
  String get reset => 'Reset progress';

  @override
  String get del => 'Delete';

  @override
  String get version => 'Word Summit 1.0.0';

  @override
  String get shop => 'Camp shop';

  @override
  String get oneTime => 'ONE-TIME';

  @override
  String get adFree => 'Ad-free climb';

  @override
  String get adFreeSub =>
      'No end-of-level ads. Boosters use camp coins instead of ads.';

  @override
  String get coins => 'CAMP COINS';

  @override
  String unlockN(int n) {
    return '≈ $n letter unlocks';
  }

  @override
  String get mostBought => 'MOST POPULAR';

  @override
  String get free => 'FREE';

  @override
  String get daily => 'Daily campfire';

  @override
  String get dailySub => '20 coins every day';

  @override
  String get getReward => 'Claim';

  @override
  String get restore => 'Restore purchases';

  @override
  String get price1 => '\$4.99';

  @override
  String get price2 => '\$1.99';

  @override
  String get price3 => '\$3.99';

  @override
  String get legalUpdated => 'Last updated · Sep 20, 2026';

  @override
  String get legal1 => 'What we collect';

  @override
  String get legal2 => 'Ad partners';

  @override
  String get legal3 => 'Data stored on device';

  @override
  String get slogans1 => 'A crossword duel against an opponent';

  @override
  String get slogans2 => 'Climb the summit word by word';

  @override
  String get slogans3 => 'Every win is 40 metres higher';

  @override
  String get slogans4 => 'Hints are one tap away';

  @override
  String get slogans5 => 'The road to the summit never ends';

  @override
  String get clue => 'Clue';

  @override
  String get levels => 'Levels';

  @override
  String levelOfTotal(int n, int total) {
    return 'Level $n / $total';
  }

  @override
  String levelsProgress(int done, int total) {
    return '$done/$total levels completed';
  }

  @override
  String levelsAllDone(int total) {
    return 'All levels completed! ($total/$total)';
  }

  @override
  String get allLevelsDone => 'You finished every level! 🎉';

  @override
  String scoreGap(int d) {
    return 'gap $d';
  }

  @override
  String resumeScore(int n, int p, int b) {
    return 'Level $n · You $p – Opponent $b';
  }

  @override
  String swapLeftCount(int n) {
    return 'Remaining · $n letters';
  }

  @override
  String get revealConfirmTitle => 'Reveal this word?';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get sixthSlotTitle => '+1 letter booster';

  @override
  String get sixthSlotBody =>
      'Watch an ad to unlock a 6th rack slot? You play every hand with 6 letters for this match; empty the rack for a +6 bonus!';

  @override
  String levelDone(int n) {
    return 'Level $n, completed';
  }

  @override
  String levelCurrent(int n) {
    return 'Level $n, next up';
  }

  @override
  String levelLocked(int n) {
    return 'Level $n, locked';
  }

  @override
  String get botDescription => 'Your opponent on the way to the summit.';

  @override
  String get levelTag => 'LEVEL';
}
