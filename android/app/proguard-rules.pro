# Room-generated database impls are instantiated reflectively; R8 full mode
# strips their no-arg constructors, crashing WorkManager init at startup.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
