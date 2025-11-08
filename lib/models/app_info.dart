import 'dart:typed_data';

class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List icon;
  final bool special;

  AppInfo({required this.packageName, required this.appName, required this.icon, this.special = false});

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      packageName: map['packageName'] as String,
      appName: map['appName'] as String,
      icon: map['icon'] as Uint8List,
    );
  }
}