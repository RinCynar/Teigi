import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 异步获取平台原生 PackageInfo
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return PackageInfo(
      appName: 'Teigi',
      packageName: 'com.example.teigi',
      version: const String.fromEnvironment('BUILD_VERSION', defaultValue: '1.0.1'),
      buildNumber: '2',
    );
  }
});

/// 应用版本号 Provider (从 PackageInfo 或环境变量中提取，避免硬编码)
final appVersionProvider = Provider<String>((ref) {
  final info = ref.watch(packageInfoProvider).valueOrNull;
  if (info != null && info.version.isNotEmpty) {
    return info.version;
  }
  return const String.fromEnvironment('BUILD_VERSION', defaultValue: '1.0.1');
});
