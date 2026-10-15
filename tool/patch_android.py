#!/usr/bin/env python3
"""Patches the generated android/ scaffold (idempotent).

Run after `flutter create` generated android/. Adds: INTERNET permission, Arabic app label,
and Start.io manifest entries (App ID from env STARTIO_APP_ID; return/splash ads disabled).
"""
import os, re, sys

path = "android/app/src/main/AndroidManifest.xml"
if not os.path.exists(path):
    sys.exit("AndroidManifest.xml not found: run flutter create first")
s = open(path, encoding="utf-8").read()
app_id = os.environ.get("STARTIO_APP_ID", "").strip() or "YOUR_STARTIO_APP_ID"

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)

s = re.sub(r'android:label="[^"]*"', 'android:label="اكتشف شخصيتك"', s, count=1)

if "com.startapp.sdk.APPLICATION_ID" not in s:
    block = f'''
        <!-- Start.io: App ID comes from STARTIO_APP_ID (placeholder until you set it). Ads stay OFF via ADS_ENABLED=false. -->
        <meta-data android:name="com.startapp.sdk.APPLICATION_ID" android:value="{app_id}" />
        <meta-data android:name="com.startapp.sdk.RETURN_ADS_ENABLED" android:value="false" />
        <provider
            android:authorities="com.startapp.flutter.sdk.${{applicationId}}"
            android:name="com.startapp.flutter.sdk.StartAppFlutterHelper"
            android:exported="false">
            <meta-data android:name="com.startapp.sdk.SPLASH_ADS_ENABLED" android:value="false" />
        </provider>
    '''
    s = s.replace("</application>", block + "</application>", 1)

open(path, "w", encoding="utf-8").write(s)
print("patched", path, "(Start.io app id:", "set" if app_id != "YOUR_STARTIO_APP_ID" else "PLACEHOLDER", ")")

# ---- Build tooling bump: startapp's native SDK (com.startapp:inapp-sdk 5.4.0) requires compileSdk 36,
# which needs a newer Android Gradle Plugin / Gradle than the Flutter 3.27.4 template (AGP 8.1.0, Gradle 8.3).
def sub_file(p, pattern, repl, label):
    if not os.path.exists(p):
        print("skip (missing):", p); return
    t = open(p, encoding="utf-8").read()
    n, c = re.subn(pattern, repl, t)
    open(p, "w", encoding="utf-8").write(n)
    print(label, "->", "changed" if c else "no match (already ok?)", p)

for sf in ("android/settings.gradle", "android/settings.gradle.kts"):
    sub_file(sf, r'(com\.android\.application"\)?\s*version\s*"?)[0-9.]+', r'\g<1>8.7.3', "AGP 8.7.3")
sub_file("android/gradle/wrapper/gradle-wrapper.properties",
         r'gradle-[0-9.]+-(all|bin)\.zip', r'gradle-8.9-all.zip', "Gradle 8.9")
for bf in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    sub_file(bf, r'compileSdk(Version)?\s*=?\s*(flutter\.compileSdkVersion|\d+)', 'compileSdk = 36', "compileSdk 36")

# minSdk 23 (required by com.startapp:inapp-sdk 5.4.0) and NDK 27 (required by several plugins).
for bf in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    sub_file(bf, r'minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)', 'minSdk = 23', "minSdk 23")
    sub_file(bf, r'ndkVersion\s*=?\s*(flutter\.ndkVersion|"[^"]*")', 'ndkVersion = "27.0.12077973"', "NDK 27")
