# Room-generated database impls are instantiated reflectively; R8 full mode
# strips their no-arg constructors, crashing WorkManager init at startup.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }

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
