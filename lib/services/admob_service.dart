import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  Future<InitializationStatus>? _initializeFuture;

  // Production IDs can be injected by --dart-define.
  static const String _androidBannerProdId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: '',
  );
  static const String _iosBannerProdId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: '',
  );

  // Official Google test ad unit IDs.
  static const String _androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2934735716';

  Future<InitializationStatus> initialize() {
    return _initializeFuture ??= MobileAds.instance.initialize();
  }

  String get bannerAdUnitId {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('AdMob is only supported on Android/iOS.');
    }

    if (kDebugMode) {
      return Platform.isAndroid ? _androidBannerTestId : _iosBannerTestId;
    }

    final configuredProdId =
        Platform.isAndroid ? _androidBannerProdId : _iosBannerProdId;

    if (configuredProdId.isEmpty || configuredProdId.contains('YOUR_')) {
      // Safety fallback so release builds won't crash while IDs are being set.
      return Platform.isAndroid ? _androidBannerTestId : _iosBannerTestId;
    }

    return configuredProdId;
  }
}
