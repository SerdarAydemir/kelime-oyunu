// lib/features/home/cubit/home_state.dart

import 'package:equatable/equatable.dart';

import 'package:kelime_oyunu/core/constants/game_constants.dart';
import 'package:kelime_oyunu/data/models/saved_session.dart';

/// What the home screen renders (README "Home").
class HomeState extends Equatable {
  const HomeState({
    this.nextLevel = 1,
    this.altitudeMeters = 0,
    this.dailyStreak = 0,
    this.wordsFound = 0,
    this.resume,
  });

  /// The level the player plays next ("Şu an · Bölüm n").
  final int nextLevel;

  /// Won levels × 40 m.
  final int altitudeMeters;

  final int dailyStreak;
  final int wordsFound;

  /// The half-played match, if any ("Yarım kalan oyun" card + CTA target).
  final ResumeSummary? resume;

  /// Climb fraction for the sky gradient (won levels / total).
  double get climbProgress => ((nextLevel - 1) / kLastLevelId).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [nextLevel, altitudeMeters, dailyStreak, wordsFound, resume];
}
