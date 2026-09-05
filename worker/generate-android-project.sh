#!/usr/bin/env bash
# Generate a minimal Android project ready for `./gradlew assembleRelease`.
# Inputs (env): APP_NAME, PACKAGE_NAME. Output dir: $1.
set -euo pipefail

OUT="${1:-/tmp/android-app}"
APP_NAME="${APP_NAME:-Generated App}"
PACKAGE_NAME="${PACKAGE_NAME:-app.generated.demo}"
PACKAGE_NAME="$(APP_NAME="$APP_NAME" PACKAGE_NAME="$PACKAGE_NAME" python3 - <<'PY'
import os, re
raw = os.environ.get("PACKAGE_NAME", "")
parts = []
for part in raw.lower().split("."):
    clean = re.sub(r"[^a-z0-9_]", "", part)
    if re.match(r"^[a-z][a-z0-9_]*$", clean):
        parts.append(clean)
if len(parts) < 3:
    slug = re.sub(r"[^a-z0-9_]", "", os.environ.get("APP_NAME", "").lower())[:20]
    if not slug or not re.match(r"^[a-z]", slug):
        slug = "generated"
    parts = ["app", "ai", slug]
print(".".join(parts[:5]))
PY
)"
PKG_PATH="${PACKAGE_NAME//./\/}"
XML_APP_NAME="$(APP_NAME="$APP_NAME" python3 - <<'PY'
import html, os
print(html.escape(os.environ.get("APP_NAME", "Generated App"), quote=True))
PY
)"
JAVA_APP_NAME="$(APP_NAME="$APP_NAME" python3 - <<'PY'
import json, os
print(json.dumps(os.environ.get("APP_NAME", "Generated App"))[1:-1])
PY
)"

rm -rf "$OUT"
mkdir -p "$OUT/app/src/main/java/$PKG_PATH" \
         "$OUT/app/src/main/res/values" \
         "$OUT/app/src/main/res/mipmap-mdpi"

cat > "$OUT/settings.gradle" <<EOF
pluginManagement {
  repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories { google(); mavenCentral() }
}
rootProject.name = "app"
include ":app"
EOF

cat > "$OUT/build.gradle" <<'EOF'
plugins {
  id 'com.android.application' version '8.5.2' apply false
}
EOF

cat > "$OUT/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
android.nonTransitiveRClass=true
EOF

cat > "$OUT/app/build.gradle" <<EOF
plugins { id 'com.android.application' }
android {
  namespace '$PACKAGE_NAME'
  compileSdk 34
  defaultConfig {
    applicationId '$PACKAGE_NAME'
    minSdk 24
    targetSdk 34
    versionCode 1
    versionName "1.0.0"
  }
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
  buildTypes {
    release {
      minifyEnabled false
      signingConfig signingConfigs.debug
    }
  }
}
EOF

cat > "$OUT/app/src/main/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application
      android:label="@string/app_name"
      android:icon="@mipmap/ic_launcher"
      android:theme="@android:style/Theme.Material.Light">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF

cat > "$OUT/app/src/main/java/$PKG_PATH/MainActivity.java" <<EOF
package $PACKAGE_NAME;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.view.Gravity;

public class MainActivity extends Activity {
  @Override protected void onCreate(Bundle s) {
    super.onCreate(s);
    TextView t = new TextView(this);
    t.setText("Ласкаво просимо до $JAVA_APP_NAME!\n\nЗібрано через AI APK Builder.");
    t.setTextSize(20);
    t.setGravity(Gravity.CENTER);
    t.setPadding(48, 48, 48, 48);
    setContentView(t);
  }
}
EOF

cat > "$OUT/app/src/main/res/values/strings.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources><string name="app_name">$XML_APP_NAME</string></resources>
EOF

# Minimal placeholder launcher icon (1x1 transparent PNG)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' \
  > "$OUT/app/src/main/res/mipmap-mdpi/ic_launcher.png"

# Gradle wrapper
cd "$OUT"
gradle wrapper --gradle-version 8.7 --distribution-type bin >/dev/null 2>&1 || {
  # Fallback: use apt gradle if `gradle` missing
  sudo apt-get install -y gradle >/dev/null
  gradle wrapper --gradle-version 8.7 --distribution-type bin
}

echo "Android project generated at $OUT"
