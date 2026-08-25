# Flutter embedding / engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Reflection / annotations used by plugins
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable

# WebView / JS bridge (webview_flutter)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Optional / transitive deps that may be missing at compile time
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Connectivity / network_info / device_info plugins — keep generated registrants
-keep class io.flutter.plugins.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class com.baseflow.** { *; }

# Aggressive optimization (safe with Flutter when minify is on)
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }
