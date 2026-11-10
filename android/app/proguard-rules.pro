# Flutter ProGuard / R8 Rules for SuperXSecret

# Flutter engine and plugin bindings
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Native Rust FFI and C++ methods
-keep class com.superxlab.** { *; }
-keep class com.superxsecret.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Security and storage
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Play Core deferred components suppression (offline vault)
-dontwarn com.google.android.play.core.**
