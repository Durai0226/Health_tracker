# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Flutter wrapper classes
-keep class com.dlyminder.app.** { *; }

# Hive
-keep class hive.** { *; }
-keep class com.isar.** { *; }

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.android.AndroidExceptionPreHandler {
    <init>();
}

# Google Play Core (for deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep interface com.google.android.play.core.** { *; }

# flutter_gemma / MediaPipe GenAI (on-device LLM) references optional vision +
# protobuf classes that aren't bundled (we use TEXT-only inference). Keep the
# GenAI classes and suppress R8 warnings for the missing optional references.
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**

# ML Kit text recognition (OCR label scan) references optional script models —
# Chinese / Devanagari / Japanese / Korean — that aren't bundled (we ship the
# default Latin recognizer only). Keep the used MLKit classes and suppress R8
# errors for the missing optional script recognizers so the release build (R8)
# doesn't fail on them.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
