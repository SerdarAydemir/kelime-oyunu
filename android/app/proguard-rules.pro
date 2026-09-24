# android/app/proguard-rules.pro — R8 keep rules for the release build.
#
# Room / WorkManager (WorkManager is pulled in by google_mobile_ads and the
# Firebase libraries and initialised at process start via
# androidx.startup.InitializationProvider). Room instantiates its generated
# `<Database>_Impl` class reflectively with a no-arg constructor. room-runtime
# 2.2.5's consumer rule is only `-keep class * extends androidx.room.RoomDatabase`;
# under R8 full mode (AGP 8+/9 default) a class-only keep no longer keeps the
# default constructor, so `WorkDatabase_Impl.<init>()` was stripped and the app
# died before MainActivity with "Failed to create an instance of
# androidx.work.impl.WorkDatabase". Keep the constructor explicitly.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
