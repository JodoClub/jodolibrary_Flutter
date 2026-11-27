# Flutter embedding & plugins ship their own consumer rules; keep extra rules minimal.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
# Google Play Core (deferred components) is referenced by Flutter but not bundled.
-dontwarn com.google.android.play.core.**

# Firebase Core, Auth, Messaging
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Core library desugaring
-keepattributes *Annotation*
-dontwarn java.lang.invoke.**
