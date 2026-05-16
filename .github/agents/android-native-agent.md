---
name: android-native-agent
description: "Specialized agent for Android native development, Kotlin code, homescreen widgets, and native platform integration. Use when: building Android widgets, writing Kotlin code, handling Android-specific features, managing native channels, or troubleshooting platform issues."
applyTo: "android/**/*.kt|android/**/*.kts|android_liquid_glass_view/**"
---

# Android Native Development Agent

## Responsibilities

You specialize in Android native development for IRIS. Focus on:
- Android homescreen widget development (AppWidget)
- Kotlin code quality and best practices
- Platform channel communication (Flutter ↔ Android)
- Native Android libraries integration
- Gradle configuration and builds
- Android performance optimization

## Project Structure

```
android/
  app/src/main/
    kotlin/com/iris/
      MainActivity.kt
      widgets/
        TimetableWidget.kt
        ClassReminderWidget.kt
      services/
        WidgetUpdateService.kt
        NotificationService.kt
      receivers/
        WidgetReceiver.kt
        BootReceiver.kt
    res/
      xml/
        timetable_widget_info.xml
        class_reminder_widget_info.xml
      drawable/
      layout/
        widget_timetable.xml
        widget_reminder.xml

android_liquid_glass_view/
  # Custom native view for liquid glass effects
```

## Android Widget (AppWidget) Development

### Widget Configuration XML
```xml
<!-- android/app/src/main/res/xml/timetable_widget_info.xml -->
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="110dp"
    android:updatePeriodMillis="1800000"
    android:previewImage="@drawable/widget_preview"
    android:initialLayout="@layout/widget_timetable"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:targetCellWidth="4"
    android:targetCellHeight="3" />
```

### Widget Implementation (Kotlin)
```kotlin
// android/app/src/main/kotlin/com/iris/widgets/TimetableWidget.kt
package com.iris.widgets

import android.appwidget.AppWidget
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.iris.R

class TimetableWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Schedule periodic updates
        super.onEnabled(context)
    }

    override fun onDisabled(context: Context) {
        // Cancel updates when last widget removed
        super.onDisabled(context)
    }

    companion object {
        private fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Fetch timetable data
            val timetable = fetchTodaysTimetable(context)
            
            // Create RemoteViews
            val views = RemoteViews(context.packageName, R.layout.widget_timetable)
            views.setTextViewText(R.id.widget_title, "Today's Classes")
            views.setTextViewText(R.id.widget_content, timetable)
            
            // Set click intent for full app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun fetchTodaysTimetable(context: Context): String {
            // Fetch from local database or shared preferences
            val prefs = context.getSharedPreferences("iris_widget", Context.MODE_PRIVATE)
            return prefs.getString("todays_schedule", "No classes") ?: "No classes"
        }
    }
}
```

### Widget Receiver (for updates)
```kotlin
// android/app/src/main/kotlin/com/iris/receivers/WidgetUpdateReceiver.kt
package com.iris.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import com.iris.widgets.TimetableWidget

class WidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.iris.UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, TimetableWidget::class.java)
            )
            
            for (appWidgetId in appWidgetIds) {
                TimetableWidget().onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
            }
        }
    }
}
```

## Platform Channels (Flutter ↔ Android)

### Android Side (Kotlin)
```kotlin
// android/app/src/main/kotlin/com/iris/MainActivity.kt
package com.iris

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.iris.native/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val data = call.argument<Map<String, Any>>("data")
                        updateWidget(data)
                        result.success(null)
                    }
                    "getWidgetData" -> {
                        val data = getWidgetData()
                        result.success(data)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun updateWidget(data: Map<String, Any>?) {
        val intent = Intent("com.iris.UPDATE_WIDGET").apply {
            putExtra("schedule", data?.get("schedule") as String?)
        }
        sendBroadcast(intent)
    }

    private fun getWidgetData(): Map<String, String> {
        val prefs = getSharedPreferences("iris_widget", MODE_PRIVATE)
        return mapOf(
            "schedule" to (prefs.getString("todays_schedule", "No classes") ?: "No classes"),
            "lastUpdate" to (prefs.getString("last_update", "") ?: "")
        )
    }
}
```

### Flutter Side (Dart)
```dart
// lib/services/android_widget_service.dart
import 'package:flutter/services.dart';

class AndroidWidgetService {
  static const platform = MethodChannel('com.iris.native/widget');

  Future<void> updateWidget(String schedule) async {
    try {
      await platform.invokeMethod('updateWidget', {
        'data': {
          'schedule': schedule,
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
    } catch (e) {
      print('Failed to update widget: $e');
    }
  }

  Future<Map<String, String>?> getWidgetData() async {
    try {
      final Map<dynamic, dynamic> result = 
        await platform.invokeMethod('getWidgetData');
      return result.cast<String, String>();
    } catch (e) {
      print('Failed to get widget data: $e');
      return null;
    }
  }
}
```

## AndroidManifest.xml Setup

```xml
<!-- Widget provider declaration -->
<receiver android:name="com.iris.widgets.TimetableWidget"
    android:label="IRIS - Today's Timetable"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="com.iris.UPDATE_WIDGET" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/timetable_widget_info" />
</receiver>

<!-- Widget update receiver -->
<receiver android:name="com.iris.receivers.WidgetUpdateReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="com.iris.UPDATE_WIDGET" />
    </intent-filter>
</receiver>
```

## Gradle Configuration

### build.gradle (app level)
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.iris"
        minSdkVersion 21
        targetSdkVersion 34
        
        resConfigs "en"  // Optimize APK size
    }
    
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
        }
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.work:work-runtime-ktx:2.8.1'
}
```

## Build & Deployment

### Local Testing
```bash
flutter run --verbose
# Or build APK
flutter build apk --split-per-abi

# Check native code
./gradlew :app:assembleDebug --info
```

### Optimization Tips
- Use ProGuard for release builds (already configured in template)
- Split APKs per ABI to reduce size
- Use Vector Drawables instead of PNGs where possible
- Lazy load native libraries

## Testing Checklist

- [ ] Widget displays correct data
- [ ] Widget updates when app data changes
- [ ] Widget handles missing data gracefully
- [ ] Platform channels work both directions
- [ ] Kotlin code follows Android style guide
- [ ] No memory leaks in broadcasts
- [ ] APK size is reasonable (~40-80MB)
- [ ] Works on min SDK version (API 21)

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Widget not updating | Check broadcast receiver in manifest, verify intent action |
| Platform channel errors | Ensure channel name matches both sides exactly |
| APK too large | Enable ProGuard, use split-per-abi, remove unused libraries |
| Memory leaks | Unregister receivers in onDestroy, avoid leaking Context |
| Widget crashes | Check log: `adb logcat \| grep iris` |
