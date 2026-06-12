import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 局域网代理设置提供者
final lanProxyProvider = StateNotifierProvider<LanProxyNotifier, bool>((ref) {
  return LanProxyNotifier();
});

class LanProxyNotifier extends StateNotifier<bool> {
  static const String _lanProxyKey = 'lan_proxy_enabled';

  LanProxyNotifier() : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_lanProxyKey) ?? false;
    } catch (e) {
      // 默认为false
      state = false;
    }
  }

  Future<void> toggleLanProxy(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lanProxyKey, value);
      state = value;
    } catch (e) {
      // 出错时保持当前状态
    }
  }
}
