# Local video_thumbnail compatibility patch

Source: https://pub.dev/packages/video_thumbnail/versions/0.5.6
Upstream: https://github.com/justsoft/video_thumbnail

Dart and platform implementation source is unchanged from version 0.5.6.
The Android build inherits the application Android Gradle plugin, removes
JCenter and the obsolete AGP 4.1 buildscript, uses compile SDK 36 / Java 17,
and declares the namespace in Gradle instead of AndroidManifest.xml.
The Dart SDK constraint permits the application's Dart 3 SDK.
The upstream MIT license is preserved in LICENSE. Remove this local dependency
when a compatible upstream release is available.
