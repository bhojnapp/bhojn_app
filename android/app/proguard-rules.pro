## Firebase aur Google Play Services ki classes ko obfuscation se bachane ke liye
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

## Flutter ke internals ko bachane ke liye
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Data loss aur crash se bachne ke liye attributes
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# 🚀 FIX: Missing Play Core classes error
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Safety ke liye Play Core classes ko bacha ke rakhna
-keep class com.google.android.play.core.** { *; }

# 🚀 NAYA ADDITION: Teri app ke data models ko jalebi banne se rokne ke liye
# (Iske bina Firebase data parsing fail ho sakti hai aur app crash ho sakti hai)
-keep class com.example.bhojn_app.** { *; }