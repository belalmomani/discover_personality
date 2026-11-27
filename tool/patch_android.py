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
app_id = os.environ.get("STARTIO_APP_ID", "").strip() or "210411777"

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
print("patched", path, "(Start.io app id:", app_id + (" from secret" if os.environ.get("STARTIO_APP_ID", "").strip() else " (project default)"), ")")

# ---- Build tooling bump: startapp's native SDK (com.startapp:inapp-sdk 5.4.0) requires compileSdk 36,
# which needs a newer Android Gradle Plugin / Gradle than the Flutter template. Current androidx releases (core 1.18, activity 1.12,
# browser 1.9) require AGP >= 8.9.1, which needs Gradle >= 8.11.1.
def sub_file(p, pattern, repl, label):
    if not os.path.exists(p):
        print("skip (missing):", p); return
    t = open(p, encoding="utf-8").read()
    n, c = re.subn(pattern, repl, t)
    open(p, "w", encoding="utf-8").write(n)
    print(label, "->", "changed" if c else "no match (already ok?)", p)

for sf in ("android/settings.gradle", "android/settings.gradle.kts"):
    sub_file(sf, r'(com\.android\.application"\)?\s*version\s*"?)[0-9.]+', r'\g<1>8.9.1', "AGP 8.9.1")
sub_file("android/gradle/wrapper/gradle-wrapper.properties",
         r'gradle-[0-9.]+-(all|bin)\.zip', r'gradle-8.11.1-all.zip', "Gradle 8.11.1")
for bf in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    sub_file(bf, r'compileSdk(Version)?\s*=?\s*(flutter\.compileSdkVersion|\d+)', 'compileSdk = 36', "compileSdk 36")

# targetSdk 36: Google Play requires new apps/updates to target Android 16 (API 36) since 2026-08-31.
for bf in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    sub_file(bf, r'targetSdk(Version)?\s*=?\s*(flutter\.targetSdkVersion|\d+)', 'targetSdk = 36', "targetSdk 36")

# minSdk 23 (required by com.startapp:inapp-sdk 5.4.0) and NDK 27 (required by several plugins).
for bf in ("android/app/build.gradle", "android/app/build.gradle.kts"):
    sub_file(bf, r'minSdk(Version)?\s*=?\s*(flutter\.minSdkVersion|\d+)', 'minSdk = 23', "minSdk 23")
    sub_file(bf, r'ndkVersion\s*=?\s*(flutter\.ndkVersion|"[^"]*")', 'ndkVersion = "27.0.12077973"', "NDK 27")

# Kotlin Gradle plugin: the template's 1.8.22 cannot read kotlin-stdlib 2.4 pulled in by newer plugins.
for sf in ("android/settings.gradle", "android/settings.gradle.kts"):
    sub_file(sf, r'(org\.jetbrains\.kotlin\.android"\)?\s*version\s*"?)[0-9.]+', r'\g<1>2.3.0', "Kotlin 2.3.0")

# ---- Release signing (only when android/key.properties exists; otherwise the debug key is kept)
if os.path.exists("android/key.properties"):
    for bf in ("android/app/build.gradle",):
        if not os.path.exists(bf):
            continue
        g = open(bf, encoding="utf-8").read()
        if "keystoreProperties" not in g:
            loader = (
                "def keystoreProperties = new Properties()\n"
                "def keystorePropertiesFile = rootProject.file('key.properties')\n"
                "if (keystorePropertiesFile.exists()) {\n"
                "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
                "}\n\n"
            )
            g = g.replace("android {", loader + "android {", 1)
            signing = (
                "    signingConfigs {\n"
                "        release {\n"
                "            keyAlias keystoreProperties['keyAlias']\n"
                "            keyPassword keystoreProperties['keyPassword']\n"
                "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
                "            storePassword keystoreProperties['storePassword']\n"
                "        }\n"
                "    }\n\n"
            )
            g = g.replace("    buildTypes {", signing + "    buildTypes {", 1)
            g = re.sub(r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig = signingConfigs.release", g)
            open(bf, "w", encoding="utf-8").write(g)
            print("release signing configured in", bf)
        else:
            print("release signing already configured")

# ---- Launcher icons: generated by tool/make_android_icons.py into assets/icon/android/res (legacy + adaptive)
import shutil
_icons = "assets/icon/android/res"
if os.path.isdir(_icons) and os.path.isdir("android/app/src/main/res"):
    shutil.copytree(_icons, "android/app/src/main/res", dirs_exist_ok=True)
    print("launcher icons installed (legacy + adaptive)")
else:
    print("no custom launcher icons found: default Flutter icon stays")

# ---- Kotlin DSL (Flutter >= 3.29 scaffolds android/app/build.gradle.kts): release signing + kotlinOptions migration
kts = "android/app/build.gradle.kts"
if os.path.exists(kts):
    g = open(kts, encoding="utf-8").read()
    if os.path.exists("android/key.properties") and "keystoreProperties" not in g:
        if "import java.util.Properties" not in g:
            g = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + g
        loader = (
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\n'
        )
        g = re.sub(r'^android \{', lambda m: loader + 'android {', g, count=1, flags=re.M)
        signing = (
            '    signingConfigs {\n'
            '        create("release") {\n'
            '            keyAlias = keystoreProperties["keyAlias"] as String\n'
            '            keyPassword = keystoreProperties["keyPassword"] as String\n'
            '            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }\n'
            '            storePassword = keystoreProperties["storePassword"] as String\n'
            '        }\n'
            '    }\n\n'
        )
        g = g.replace("    buildTypes {", signing + "    buildTypes {", 1)
        g, c = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")', g)
        print("release signing configured in", kts, "(release config switched:", bool(c), ")")
    # kotlinOptions{} is an error in newer Kotlin Gradle plugins (we force 2.3.0): move it to compilerOptions.
    m = re.search(r'\n[ \t]*kotlinOptions\s*\{[^}]*\}[ \t]*\n', g)
    if m:
        jv = re.search(r'JavaVersion\.VERSION_(\d+)', g)
        target = jv.group(1) if jv else "11"
        g = g.replace(m.group(0), "\n", 1)
        g += ('\nkotlin {\n    compilerOptions {\n'
              '        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_%s)\n    }\n}\n' % target)
        print("kotlinOptions migrated to compilerOptions (JVM", target, ")")
    open(kts, "w", encoding="utf-8").write(g)

# ---- Push notifications: POST_NOTIFICATIONS permission (Android 13+) and, only if a Firebase config file exists,
#      the Google Services Gradle plugin. Without google-services.json the app builds and runs; push is "unsupported".
mp = "android/app/src/main/AndroidManifest.xml"
m = open(mp, encoding="utf-8").read()
if "android.permission.POST_NOTIFICATIONS" not in m:
    m = m.replace("<application", '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
    open(mp, "w", encoding="utf-8").write(m)
    print("POST_NOTIFICATIONS added")

if os.path.exists("android/app/google-services.json"):
    sf = "android/settings.gradle"
    if os.path.exists(sf):
        t = open(sf, encoding="utf-8").read()
        if "com.google.gms.google-services" not in t:
            t = re.sub(r'(id "org\.jetbrains\.kotlin\.android" version "[^"]+" apply false)',
                       r'\1\n    id "com.google.gms.google-services" version "4.4.2" apply false', t, count=1)
            open(sf, "w", encoding="utf-8").write(t)
            print("google-services plugin declared in settings.gradle")
    bf = "android/app/build.gradle"
    if os.path.exists(bf):
        t = open(bf, encoding="utf-8").read()
        if 'id "com.google.gms.google-services"' not in t:
            t = re.sub(r'(id "com\.android\.application")', r'\1\n    id "com.google.gms.google-services"', t, count=1)
            open(bf, "w", encoding="utf-8").write(t)
            print("google-services plugin applied in app/build.gradle")
    sk = "android/settings.gradle.kts"
    if os.path.exists(sk):
        t = open(sk, encoding="utf-8").read()
        if "com.google.gms.google-services" not in t:
            t = re.sub(r'(id\("org\.jetbrains\.kotlin\.android"\) version "[^"]+" apply false)',
                       r'\1\n    id("com.google.gms.google-services") version "4.4.2" apply false', t, count=1)
            open(sk, "w", encoding="utf-8").write(t)
            print("google-services plugin declared in settings.gradle.kts")
    bk = "android/app/build.gradle.kts"
    if os.path.exists(bk):
        t = open(bk, encoding="utf-8").read()
        if 'id("com.google.gms.google-services")' not in t:
            t = re.sub(r'(id\("com\.android\.application"\))', r'\1\n    id("com.google.gms.google-services")', t, count=1)
            open(bk, "w", encoding="utf-8").write(t)
            print("google-services plugin applied in app/build.gradle.kts")
else:
    print("no google-services.json: push notifications stay disabled in this build")
