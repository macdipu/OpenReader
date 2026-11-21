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
