# --- Hardening / size ---
# Strip android.util.Log debug/verbose/info calls from release.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
# Flatten packages and drop source/line info to hinder reverse engineering.
-repackageclasses ''
-allowaccessmodification
-renamesourcefileattribute SourceFile
-optimizationpasses 5

# Readable Crashlytics stack traces.
-keepattributes SourceFile,LineNumberTable

# OCR (google_mlkit_text_recognition) bundles the Latin model only. The plugin also refers to the
# Chinese, Devanagari, Japanese and Korean recognizer options, which are separate artifacts that are
# not included; it uses them only when one of those scripts is asked for, and the app never does.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
