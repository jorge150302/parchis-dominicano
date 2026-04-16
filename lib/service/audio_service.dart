import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _clickPlayer = AudioPlayer(); // Jugador dedicado para clics rápidos

  // Generador de tonos para otros efectos (se mantiene como fallback o para otros sonidos)
  static Uint8List _generateWav(double frequency, double durationSeconds) {
    const int sampleRate = 22050;
    final int numSamples = (durationSeconds * sampleRate).toInt();
    final int dataSize = numSamples * 2;
    final int fileSize = 44 + dataSize;
    final Uint8List bytes = Uint8List(fileSize);
    final ByteData bd = ByteData.view(bytes.buffer);
    bd.setUint8(0, 0x52); bd.setUint8(1, 0x49); bd.setUint8(2, 0x46); bd.setUint8(3, 0x46);
    bd.setUint32(4, fileSize - 8, Endian.little);
    bd.setUint8(8, 0x57); bd.setUint8(9, 0x41); bd.setUint8(10, 0x56); bd.setUint8(11, 0x45);
    bd.setUint8(12, 0x66); bd.setUint8(13, 0x6D); bd.setUint8(14, 0x74); bd.setUint8(15, 0x20);
    bd.setUint32(16, 16, Endian.little); 
    bd.setUint16(20, 1, Endian.little);  
    bd.setUint16(22, 1, Endian.little);  
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little); 
    bd.setUint16(32, 2, Endian.little);  
    bd.setUint16(34, 16, Endian.little); 
    bd.setUint8(36, 0x64); bd.setUint8(37, 0x61); bd.setUint8(38, 0x74); bd.setUint8(39, 0x61);
    bd.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      int sample = (sin(2 * pi * frequency * t) * 32767).toInt();
      bd.setInt16(44 + i * 2, sample, Endian.little);
    }
    return bytes;
  }

  static Future<void> _playTone(double freq, double duration) async {
    try {
      final bytes = _generateWav(freq, duration);
      await _player.stop();
      await _player.play(BytesSource(bytes));
    } catch (e) {
      HapticFeedback.mediumImpact();
    }
  }

  static void playDiceRoll() => _playTone(150, 0.05);
  static void playSendHome() => _playTone(300, 0.2);
  static void playVictory() => _playTone(880, 0.4);
  
  // 🖱️ SONIDO DE CLIC USANDO TAP_EFFECT.MP3
  static void playClick() async {
    HapticFeedback.lightImpact();
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(AssetSource('sounds/tap_effect.mp3'));
    } catch (e) {
      // Si falla el archivo, usamos el tono generado
      _playTone(440, 0.03);
    }
  }
}
