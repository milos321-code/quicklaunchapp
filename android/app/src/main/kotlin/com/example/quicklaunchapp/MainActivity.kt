package com.example.quicklaunchapp

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode.transparent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

import android.view.WindowManager
import android.view.Window

import android.view.KeyEvent
import io.flutter.plugin.common.MethodChannel

import android.provider.Settings
import android.provider.Settings.SettingNotFoundException

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import java.io.ByteArrayOutputStream


class MainActivity: FlutterActivity() {
    private val BUTTON_PRESS_CHANNEL = "com.example.quicklaunchapp/android_buttons"
    private val BRIGHTNESS_CHANNEL = "com.example.quicklaunchapp/android_brightness"
    private val APP_CHANNEL = "com.example.quicklaunchapp/android_apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BRIGHTNESS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    val brightness = call.arguments as Double
                    if (Settings.System.canWrite(this)) {
                        setScreenBrightness(brightness)
                        result.success("Brightness set to $brightness")
                    } else {
                        requestWriteSettingsPermission()
                        result.error("PERMISSION_DENIED", "Permission to write settings not granted", null)
                    }
                }
                "getBrightness" -> {
                    if (Settings.System.canWrite(this)) {
                        val brightness = getScreenBrightness()
                        result.success(brightness)
                    } else {
                        requestWriteSettingsPermission()
                        result.error("PERMISSION_DENIED", "Permission to read settings not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllApps" -> {
                    val apps = getAllApps()
                    result.success(apps)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val success = launchApp(packageName)
                        result.success(success)
                    } else {
                        result.error("INVALID_PACKAGE_NAME", "Package name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setScreenBrightness(brightness: Double) {
        val brightnessValue = (brightness * 255).toInt()
        Settings.System.putInt(
            contentResolver,
            Settings.System.SCREEN_BRIGHTNESS,
            brightnessValue
        )
    }

    private fun getScreenBrightness(): Double {
        return try {
            val brightnessValue = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS
            )
            brightnessValue / 255.0
        } catch (e: SettingNotFoundException) {
            e.printStackTrace()
            0.0
        }
    }

    private fun requestWriteSettingsPermission() {
        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        intent.putExtra("background_mode", transparent.toString())
        super.onCreate(savedInstanceState)
        val w: Window = window
        w.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    private var volumeUpPressed = false
    private var volumeDownPressed = false

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        return if (messenger != null) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    if (!volumeUpPressed) {
                        volumeUpPressed = true
                        MethodChannel(messenger, BUTTON_PRESS_CHANNEL).invokeMethod("volumeUpPressed", null)
                    }
                    true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    if (!volumeDownPressed) {
                        volumeDownPressed = true
                        MethodChannel(messenger, BUTTON_PRESS_CHANNEL).invokeMethod("volumeDownPressed", null)
                    }
                    true
                }
                else -> super.onKeyDown(keyCode, event)
            }
        } else {
            super.onKeyDown(keyCode, event)
        }
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        return if (messenger != null) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    if (volumeUpPressed) {
                        volumeUpPressed = false
                        MethodChannel(messenger, BUTTON_PRESS_CHANNEL).invokeMethod("volumeUpReleased", null)
                    }
                    true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    if (volumeDownPressed) {
                        volumeDownPressed = false
                        MethodChannel(messenger, BUTTON_PRESS_CHANNEL).invokeMethod("volumeDownReleased", null)
                    }
                    true
                }
                else -> super.onKeyUp(keyCode, event)
            }
        } else {
            super.onKeyUp(keyCode, event)
        }
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun getAllApps(): List<Map<String, Any>> {
        val packageManager = packageManager
        val apps = packageManager.getInstalledApplications(PackageManager.MATCH_ALL)
        val appList = mutableListOf<Map<String, Any>>()

        for (app in apps) {
            val packageName = app.packageName
            val appName = packageManager.getApplicationLabel(app).toString()
            val appIcon = packageManager.getApplicationIcon(app)
            val bitmap = getBitmapFromDrawable(appIcon)
            val byteArrayOutputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
            val iconBytes = byteArrayOutputStream.toByteArray()

            appList.add(
                mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "icon" to iconBytes
                )
            )
        }
        return appList
    }

    private fun getBitmapFromDrawable(drawable: Drawable): Bitmap {
        return if (drawable is BitmapDrawable) {
            drawable.bitmap
        }
        else {
            val bitmap = Bitmap.createBitmap(
                drawable.intrinsicWidth,
                drawable.intrinsicHeight,
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        }
    }
}