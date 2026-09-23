# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep OkHttp (used by flutter_cache_manager / cached_network_image)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# Keep sqflite (used by flutter_cache_manager for cache DB)
-keep class com.tekartik.sqflite.** { *; }

# Keep Gson (sometimes used by plugins)
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }

# Keep AndroidX annotations
-keep class androidx.annotation.** { *; }

# Prevent R8 from stripping image-loading related classes
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Keep file_picker classes
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Ignore missing Google Play Core classes referenced by Flutter
-dontwarn com.google.android.play.core.**
