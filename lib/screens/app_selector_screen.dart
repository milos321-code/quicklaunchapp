import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quicklaunchapp/models/app_info.dart';
import 'package:quicklaunchapp/screens/home_screen.dart';


class AppSelector extends StatefulWidget {
  const AppSelector({super.key});

  @override
  State<AppSelector> createState() => _AppSelectorState();
}

class _AppSelectorState extends State<AppSelector> {
  static const _appsPlatform = MethodChannel('com.example.quicklaunchapp/android_apps');

  bool isLoading = false;

  List<AppInfo> apps = [];
  List<AppInfo> filteredApps = [];

  @override
  void initState() {
    super.initState();

    _getAllApps();
  }

  Future<void> _getAllApps() async {
    setState(() {
      isLoading = true;
    });
    try {
      final List<dynamic> result = await _appsPlatform.invokeMethod('getAllApps');
      setState(() {
        apps = result.map((app) {
          final Map<String, dynamic> appMap = Map<String, dynamic>.from(app);
          return AppInfo.fromMap(appMap);
        }).toList();

        final flashlightApp = AppInfo(
          packageName: "flashlight",
          appName: "Flashlight [Built-In App]",
          icon: Uint8List(0),
          special: true,
        );

        apps.add(flashlightApp);
        apps.sort((a, b) => a.appName.compareTo(b.appName));
        filteredApps = apps;
      });
    } on PlatformException catch (e) {
      print("Failed to get apps: '${e.message}'.");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _appSelected(int index) async {
    final packageName = filteredApps[index].packageName;
    final pref = await SharedPreferences.getInstance();
    await pref.setString("packageName", packageName);
  }

  final _textEditingController = TextEditingController();

  void _filterApps() {
    final query = _textEditingController.text.toLowerCase();
    if (query.isEmpty) {
      filteredApps = apps;
      return;
    }

    filteredApps = apps.where((app) {
      return app.appName.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();

    setState(() {});
  }

  ListTile _specialAppListTileBuilder(BuildContext context, int index, AppInfo app) {
    if (app.packageName == "flashlight") {
      return ListTile(
        leading: Icon(Icons.flashlight_on),
        title: Text(app.appName),
        subtitle: Text(app.packageName),
        onTap: () {
          _appSelected(index);
        },
      );
    }

    return ListTile(
      leading: Icon(Icons.question_mark),
      title: Text(app.appName),
      subtitle: Text(app.packageName),
      onTap: () {
        _appSelected(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          ),
        ),
        title: TextField(
          controller: _textEditingController,
          decoration: const InputDecoration(
            hintText: "Search apps...",
            border: InputBorder.none,
          ),
          onChanged: (_) {
            _filterApps();
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(),)
          : ListView.builder(
        itemCount: filteredApps.length,
        itemBuilder: (context, index) {
          final app = filteredApps[index];
          if (app.special) {
            return _specialAppListTileBuilder(context, index, app);
          }

          return ListTile(
            leading: Image.memory(app.icon),
            title: Text(app.appName),
            subtitle: Text(app.packageName),
            onTap: () {
              // print("Clicked on > ${filteredApps[index].packageName}");
              _appSelected(index);
            },
          );
        },
      ),
    );
  }
}