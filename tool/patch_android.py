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
