import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'prefs_service.dart';

class AudioService {
  static final AudioPlayer _clickPlayer = AudioPlayer();
  static final AudioPlayer _timerPlayer = AudioPlayer();
  static final AudioPlayer _effectPlayer = AudioPlayer();

  static void playMoveStep() {
    if (PrefsService.vibrationEnabled) HapticFeedback.selectionClick();
  }

  static void playClick() async {
    if (PrefsService.vibrationEnabled) HapticFeedback.lightImpact();
    if (!PrefsService.soundEnabled) return;
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(AssetSource('sounds/tap_effect.mp3'));
    } catch (_) {}
  }

  static void playFinalTiming() async {
    if (!PrefsService.soundEnabled) return;
    try {
      await _timerPlayer.stop();
      await _timerPlayer.play(AssetSource('sounds/final_timing.mp3'));
    } catch (_) {}
  }

  static void stopFinalTiming() async {
    try {
      await _timerPlayer.stop();
    } catch (_) {}
  }

  static void playVictory() async {
    if (!PrefsService.soundEnabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('sounds/fanfarreas.mp3'));
    } catch (_) {
      if (PrefsService.vibrationEnabled) HapticFeedback.heavyImpact();
    }
  }

  static void playSendHome() async {
    if (!PrefsService.soundEnabled) return;
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('sounds/send_to_home.mp3'));
    } catch (_) {
      if (PrefsService.vibrationEnabled) HapticFeedback.mediumImpact();
    }
  }
}
