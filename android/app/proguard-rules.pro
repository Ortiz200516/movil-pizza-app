# android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firestore
-keep class com.google.firestore.** { *; }

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*

# Gson (si usas JSON)
-keepattributes EnclosingMethod
-keep class sun.misc.Unsafe { *; }

# Google Maps
-keep class com.google.maps.** { *; }
-keep class com.google.android.libraries.maps.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Evitar warnings innecesarios
-dontwarn com.google.**
-dontwarn io.flutter.**