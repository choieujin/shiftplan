import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';

/// 화면 하단에 붙는 AdMob 배너. 광고를 지원하지 않는 플랫폼(웹 등)이나
/// 로드 실패 시에는 아무것도 표시하지 않는다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery(화면 폭)가 필요하므로 initState가 아닌 여기서 시작한다.
    if (AdBanner.supported && !_loadStarted) {
      _loadStarted = true;
      _load();
    }
  }

  Future<void> _load() async {
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.sizeOf(context).width.truncate(),
    );
    if (!mounted || size == null) return;

    final BannerAd ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (!AdBanner.supported || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
