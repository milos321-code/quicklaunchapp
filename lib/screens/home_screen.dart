import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quicklaunchapp/screens/app_selector_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _buttonsPlatform = MethodChannel('com.example.quicklaunchapp/android_buttons');
  static const _brightnessPlatform = MethodChannel('com.example.quicklaunchapp/android_brightness');
  static const _appsPlatform = MethodChannel('com.example.quicklaunchapp/android_apps');

  var _selectedApp = "No app selected";

  @override
  void initState() {
    super.initState();
    _buttonsPlatform.setMethodCallHandler(_handleButtonEvent);
    _setSelectedApp();
  }

  Future<void> _setSelectedApp() async {
    final pref = await SharedPreferences.getInstance();
    setState(() {
      _selectedApp = pref.getString("packageName") ?? "No app selected";
    });
  }

  Future<void> _launchApp(String packageName) async {
    try {
      final bool result = await _appsPlatform.invokeMethod('launchApp', {'packageName': packageName});
      if (!result) {
        print("Failed to launch app: $packageName");
      }
    } on PlatformException catch (e) {
      print("Failed to launch app: '${e.message}'.");
    }
  }

  Future<void> _setBrightness(double brightness) async {
    _brightnessPlatform.invokeMethod('setBrightness', brightness);
  }

  Future<double> _getCurrentBrightness() async {
    return await _brightnessPlatform.invokeMethod('getBrightness');
  }

  Future<void> _changeBrightnessBy(double amount) async {
    if (amount == 0.0) return;

    final currBrightness = await _getCurrentBrightness();

    var newBrightness = currBrightness + amount;
    if (newBrightness > 1.0) {
      newBrightness = 1.0;
    }
    else if (newBrightness < 0.0) {
      newBrightness = 0.0;
    }

    if (newBrightness == currBrightness) return;

    await _setBrightness(newBrightness);
  }

  Future<void> _handleButtonEvent(MethodCall call) async {
    switch (call.method) {
      case 'volumeUpPressed':
        _changeBrightnessBy(0.1);
        break;
      case 'volumeUpReleased':
        break;
      case 'volumeDownPressed':
        _changeBrightnessBy(-0.1);
        break;
      case 'volumeDownReleased':
        break;
      default:
        throw MissingPluginException('not implemented');
    }
  }

  static late bool _torchAvailable;
  static bool _torchAvailableInitialized = false;
  static bool _torchOn = false;

  Future<void> _toggleTorch() async {
    if (!_torchAvailableInitialized) {
      _torchAvailable = await TorchLight.isTorchAvailable();
      _torchAvailableInitialized = true;
    }

    if (!_torchAvailable) {
      return;
    }

    if (_torchOn) {
      TorchLight.disableTorch();
    }
    else {
      TorchLight.enableTorch();
    }
    _torchOn = !_torchOn;
  }

  bool _handleAppIfSpecial(String packageName) {
    if (packageName == "flashlight") {
      _toggleTorch();
      return true;
    }

    return false;
  }

  void _launchButton() {
    if (_handleAppIfSpecial(_selectedApp)) {
      return;
    }
    _launchApp(_selectedApp);
  }

  _settingsPageButton() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AppSelector()),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double popupWidth = screenWidth * (4.0 / 5.0);
    double popupHeight = screenHeight * (5.0 / 9.0);

    return TapRegion(
      onTapOutside: (tap) {
        SystemNavigator.pop();
      },
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(popupWidth / 10.0),
          child: Container(
            width: popupWidth,
            height: popupHeight,
            color: Colors.grey.shade900.withOpacity(0.9),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(15.0),
                    child: CircularButton(
                      child: Icon(Icons.settings),
                      color: Colors.white,
                      radius: 18.0,
                      onPressed: () {
                        _settingsPageButton();
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularButton(
                        child: const Icon(Icons.launch_outlined),
                        onPressed: () {
                          // _toggleTorch();
                          _launchButton();
                        },
                        color: Colors.white,
                        radius: popupWidth * 0.4
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget CircularButton({
  required Widget child,
  required VoidCallback onPressed,
  required Color color,
  required double radius,
}) {
  return SizedBox(
    width: radius * 2,
    height: radius * 2,
    child: RawMaterialButton(
      onPressed: onPressed,
      fillColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: SizedBox(
          width: radius * 2 * 0.7,
          height: radius * 2 * 0.7,
          child: FittedBox(
            fit: BoxFit.contain,
            child: child,
          ),
        ),
      ),
    ),
  );
}