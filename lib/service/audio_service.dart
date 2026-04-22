import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _clickPlayer = AudioPlayer(); 

  // ✅ VIBRACIÓN PARA MOVIMIENTO (Sin sonido para máxima fluidez)
  static void playMoveStep() {
    HapticFeedback.selectionClick();
  }

  // 🖱️ SONIDO DE CLIC (Para botones y menús)
  static void playClick() async {
    HapticFeedback.lightImpact();
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(AssetSource('sounds/tap_effect.mp3'));
    } catch (e) {
      // Fallback a vibración si falla el audio
      HapticFeedback.selectionClick();
    }
  }

  static final AudioPlayer _effectPlayer = AudioPlayer();

  static void playVictory() async {
    try {
      await _effectPlayer.play(AssetSource('sounds/fanfarreas.mp3'));
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  static void playSendHome() async {
    try {
      await _effectPlayer.play(AssetSource('sounds/send_to_home.mp3'));
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }
}
