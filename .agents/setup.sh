#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.50.0"
FLUTTER_SHA256="6ea2d806fd57269ae783e6788e2a81fc26eaad782f1e0d0ff38623bb765ff9f5"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

TOOLS_DIR="${HOME}/tools"
FLUTTER_DIR="${TOOLS_DIR}/flutter"
ANDROID_SDK_DIR="${TOOLS_DIR}/android-sdk"
BASHRC="${HOME}/.bashrc"

# Strip non-interactive early-return guard so non-interactive shells load PATH/env.
if [ -f "$BASHRC" ]; then
  sed -i '/case \$- in/,/esac/d' "$BASHRC" 2>/dev/null || true
else
  touch "$BASHRC"
fi

mkdir -p "$TOOLS_DIR"

if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ]; then
  if [ ! -x "${FLUTTER_DIR}/bin/flutter" ] && ! (command -v flutter >/dev/null 2>&1 && flutter --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION}"); then
    TMP_TAR="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
    curl -fSL "$FLUTTER_URL" -o "$TMP_TAR"
    echo "${FLUTTER_SHA256}  ${TMP_TAR}" | sha256sum -c -
    tar -xf "$TMP_TAR" -C "$TOOLS_DIR"
    rm -f "$TMP_TAR"
  fi

  if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
    grep -qxF 'export PATH="$HOME/tools/flutter/bin:$PATH"' "$BASHRC" || \
      grep -qxF 'export PATH="/home/antigravity/tools/flutter/bin:$PATH"' "$BASHRC" || \
      echo 'export PATH="$HOME/tools/flutter/bin:$PATH"' >> "$BASHRC"
    export PATH="${FLUTTER_DIR}/bin:${PATH}"
    git config --global --add safe.directory "$FLUTTER_DIR" || true
  fi

  # Build a user-space Java truststore when system Java cacerts is missing or
  # custom proxy CAs are present under /usr/local/share/ca-certificates.
  if command -v keytool >/dev/null 2>&1 && { [ ! -f /etc/ssl/certs/java/cacerts ] || ls /usr/local/share/ca-certificates/*.crt >/dev/null 2>&1; }; then
    JAVA_CACERTS="${TOOLS_DIR}/java-cacerts"
    if [ ! -f "$JAVA_CACERTS" ]; then
      JAVA_HOME_DIR="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
      SYS_CACERTS="${JAVA_HOME_DIR}/lib/security/cacerts"
      if [ -f "$SYS_CACERTS" ]; then
        cp "$SYS_CACERTS" "$JAVA_CACERTS"
        chmod 644 "$JAVA_CACERTS"
      fi
      if [ -f /etc/ssl/certs/ca-certificates.crt ] && command -v python3 >/dev/null 2>&1; then
        TMP_CERTS="/tmp/split-certs-$$"
        rm -rf "$TMP_CERTS"
        mkdir -p "$TMP_CERTS"
        python3 - "$TMP_CERTS" <<'PY'
import sys
from pathlib import Path

out_dir = Path(sys.argv[1])
data = Path('/etc/ssl/certs/ca-certificates.crt').read_text()
certs = [
    c.strip() + '\n-----END CERTIFICATE-----\n'
    for c in data.split('-----END CERTIFICATE-----')
    if '-----BEGIN CERTIFICATE-----' in c
]
for i, c in enumerate(certs):
    idx = c.index('-----BEGIN CERTIFICATE-----')
    (out_dir / f'sys_{i:04d}.pem').write_text(c[idx:])
PY
        for f in "$TMP_CERTS"/*.pem; do
          [ -e "$f" ] || continue
          keytool -importcert -noprompt -trustcacerts -alias "$(basename "$f" .pem)" \
            -file "$f" -keystore "$JAVA_CACERTS" -storepass changeit >/dev/null 2>&1 || true
        done
        rm -rf "$TMP_CERTS"
      fi
      for cert in /usr/local/share/ca-certificates/*.crt; do
        [ -e "$cert" ] || continue
        keytool -importcert -noprompt -trustcacerts -alias "local_$(basename "$cert" .crt)" \
          -file "$cert" -keystore "$JAVA_CACERTS" -storepass changeit >/dev/null 2>&1 || true
      done
    fi
    if [ -f "$JAVA_CACERTS" ]; then
      JTO="export JAVA_TOOL_OPTIONS=\"-Djavax.net.ssl.trustStore=${JAVA_CACERTS} -Djavax.net.ssl.trustStorePassword=changeit\""
      grep -qxF "$JTO" "$BASHRC" || echo "$JTO" >> "$BASHRC"
      export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=${JAVA_CACERTS} -Djavax.net.ssl.trustStorePassword=changeit"
    fi
  fi

  # Install Android SDK command-line tools and required SDK packages if not already configured.
  if [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/platforms/android-36" ]; then
    ANDROID_SDK_DIR="$ANDROID_HOME"
  else
    if [ ! -x "${ANDROID_SDK_DIR}/cmdline-tools/latest/bin/sdkmanager" ]; then
      mkdir -p "${ANDROID_SDK_DIR}/cmdline-tools"
      TMP_ZIP="/tmp/cmdline-tools-$$.zip"
      TMP_EXTRACT="/tmp/cmdline-extract-$$"
      curl -fSL "$CMDLINE_TOOLS_URL" -o "$TMP_ZIP"
      rm -rf "$TMP_EXTRACT"
      unzip -q "$TMP_ZIP" -d "$TMP_EXTRACT"
      rm -rf "${ANDROID_SDK_DIR}/cmdline-tools/latest"
      mv "${TMP_EXTRACT}/cmdline-tools" "${ANDROID_SDK_DIR}/cmdline-tools/latest"
      rm -rf "$TMP_ZIP" "$TMP_EXTRACT"
    fi

    grep -qxF 'export ANDROID_HOME="$HOME/tools/android-sdk"' "$BASHRC" || \
      grep -qxF 'export ANDROID_HOME="/home/antigravity/tools/android-sdk"' "$BASHRC" || \
      echo 'export ANDROID_HOME="$HOME/tools/android-sdk"' >> "$BASHRC"
    grep -qxF 'export ANDROID_SDK_ROOT="$HOME/tools/android-sdk"' "$BASHRC" || \
      grep -qxF 'export ANDROID_SDK_ROOT="/home/antigravity/tools/android-sdk"' "$BASHRC" || \
      echo 'export ANDROID_SDK_ROOT="$HOME/tools/android-sdk"' >> "$BASHRC"
    grep -qxF 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' "$BASHRC" || \
      echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> "$BASHRC"

    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
    export PATH="${ANDROID_SDK_DIR}/cmdline-tools/latest/bin:${ANDROID_SDK_DIR}/platform-tools:${PATH}"

    PROXY_ARGS=""
    if [ -n "${HTTP_PROXY:-}" ]; then
      PROXY_HOST="${HTTP_PROXY#http://}"
      PROXY_HOST="${PROXY_HOST#https://}"
      PROXY_PORT="${PROXY_HOST##*:}"
      PROXY_HOST="${PROXY_HOST%%:*}"
      PROXY_ARGS="--proxy=http --proxy_host=${PROXY_HOST} --proxy_port=${PROXY_PORT}"
    fi

    if [ ! -d "${ANDROID_SDK_DIR}/platforms/android-36" ] || [ ! -d "${ANDROID_SDK_DIR}/build-tools/36.0.0" ] || [ ! -d "${ANDROID_SDK_DIR}/platform-tools" ]; then
      yes | sdkmanager --sdk_root="$ANDROID_SDK_DIR" $PROXY_ARGS --licenses >/dev/null || true
      sdkmanager --sdk_root="$ANDROID_SDK_DIR" $PROXY_ARGS "platform-tools" "platforms;android-36" "build-tools;36.0.0"
    fi
  fi

  flutter config --android-sdk "$ANDROID_SDK_DIR" >/dev/null
fi

flutter --suppress-analytics --version
dart --disable-analytics || true

flutter pub get --enforce-lockfile
dart run tool/codegen.dart
