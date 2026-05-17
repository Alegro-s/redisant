
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${ENGINE_ROOT}/.." && pwd)"
CLIENT_ROOT="${REPO_ROOT}/client"
JNI_LIBS="${CLIENT_ROOT}/android/app/src/main/jniLibs"

resolve_ndk() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
    echo "${ANDROID_NDK_HOME}"
    return
  fi
  local LP="${CLIENT_ROOT}/android/local.properties"
  [[ -f "${LP}" ]] || { echo ""; return; }
  local SDK_LINE
  SDK_LINE="$(grep -E '^sdk\.dir=' "${LP}" | tail -n1 || true)"
  [[ -n "${SDK_LINE}" ]] || { echo ""; return; }
  local SDK="${SDK_LINE#sdk.dir=}"
  SDK="${SDK//\\\\//}"
  local NDK_BASE="${SDK}/ndk"
  [[ -d "${NDK_BASE}" ]] || { echo ""; return; }
  ls -1d "${NDK_BASE}/"* 2>/dev/null | sort -V | tail -n1
}

NDK_HOME="$(resolve_ndk)"
if [[ -z "${NDK_HOME}" || ! -d "${NDK_HOME}" ]]; then
  echo "Не найден Android NDK. ANDROID_NDK_HOME или sdk.dir + NDK в SDK Manager." >&2
  exit 1
fi
export ANDROID_NDK_HOME="${NDK_HOME}"
echo "[engine] ANDROID_NDK_HOME=${ANDROID_NDK_HOME}"

echo "[engine] rustup target add aarch64-linux-android"
rustup target add aarch64-linux-android

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "[engine] cargo install cargo-ndk..."
  cargo install cargo-ndk --locked
fi

echo "[engine] cargo ndk build → jniLibs (arm64-v8a)..."
cd "${ENGINE_ROOT}"
cargo ndk -t arm64-v8a -P 24 -o "${JNI_LIBS}" build --release

echo "[engine] flutter build apk --release..."
cd "${CLIENT_ROOT}"
flutter pub get
flutter build apk --release

echo "[engine] готово: ${CLIENT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
