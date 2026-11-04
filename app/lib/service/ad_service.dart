import 'package:flutter/material.dart';
import 'config_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    // Aquí se inicializaría Google Mobile Ads
    // MobileAds.instance.initialize();
    _isInitialized = true;
  }

  /// Muestra un anuncio de video recompensado.
  /// Retorna true si el usuario completó el video.
  Future<bool> showRewardedAd() async {
    if (!ConfigService().adsEnabled) return false;

    // Mock de visualización de anuncio
    // En producción, aquí se cargaría y mostraría el anuncio real de AdMob
    debugPrint('Mostrando anuncio recompensado (Mock)...');
    
    // Simulamos un delay de "ver el video"
    await Future.delayed(const Duration(seconds: 2));
    
    return true; // El usuario completó el video
  }

  /// Muestra un anuncio intercalado (Interstitial).
  Future<void> showInterstitialAd() async {
    if (!ConfigService().adsEnabled) return;
    debugPrint('Mostrando anuncio intercalado (Mock)...');
  }
}
