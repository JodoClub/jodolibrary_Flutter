# Flutter embedding & plugins ship their own consumer rules; keep extra rules minimal.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
# Google Play Core (deferred components) is referenced by Flutter but not bundled.
-dontwarn com.google.android.play.core.**
