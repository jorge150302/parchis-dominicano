import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _clickPlayer = AudioPlayer(); 
  static final AudioPlayer _timerPlayer = AudioPlayer();
  static final AudioPlayer _effectPlayer = AudioPlayer();

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

  // ⏰ SONIDO DE ALERTA DE TIEMPO (Últimos segundos)
  static void playFinalTiming() async {
    try {
      await _timerPlayer.stop();
      await _timerPlayer.play(AssetSource('sounds/final_timing.mp3'));
    } catch (_) {
      // Ignorar errores de audio
    }
  }

  static void playVictory() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('sounds/fanfarreas.mp3'));
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  static void playSendHome() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource('sounds/send_to_home.mp3'));
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }
}
