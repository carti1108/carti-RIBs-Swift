#!/usr/bin/env bash
# 공개 라이브러리 타깃의 API 덤프(api/*.json)를 다시 만들어 체크인된 덤프와 비교한다(ADR-0011).
# KMP의 checkKotlinAbi / updateKotlinAbi에 해당한다.
#
#   scripts/check-api.sh                     # 비교. 다르면 차이와 깨진 API를 출력하고 1로 끝난다
#   scripts/check-api.sh --update            # 의도적으로 API를 바꿨을 때 덤프 갱신
#   scripts/check-api.sh --baseline <treeish> # git 기준점이 생긴 뒤: SwiftPM diagnose-api-breaking-changes도 실행
#
# macOS + Xcode 전용이다(xcrun swift-api-digester, iOS 시뮬레이터 SDK).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/api"
MACOS_MODULES=(RIBs RIBsSwiftUI RIBsWeb RIBsAndroid)
IOS_MODULES=(RIBsUIKit)
MACOS_TARGET="arm64-apple-macosx14.0"
IOS_TARGET="arm64-apple-ios17.0-simulator"
IOS_SCRATCH="$ROOT/.build/api-ios"

mode="check"
baseline=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --update) mode="update"; shift ;;
        --baseline) baseline="${2:?--baseline에는 treeish가 필요합니다}"; shift 2 ;;
        -h|--help) sed -n 2,9p "$0"; exit 0 ;;
        *) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
    esac
done

if [[ "$(uname)" != "Darwin" ]]; then
    echo "check-api.sh는 macOS(Xcode)에서만 실행합니다." >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# CRIBsAndroid(C 타깃)는 RIBsAndroid의 swiftmodule이 참조하므로 digester가 찾을 수 있게 모듈 맵을 만든다.
mkdir -p "$work/modulemap"
cat > "$work/modulemap/module.modulemap" <<EOF
module CRIBsAndroid {
    umbrella header "$ROOT/Sources/CRIBsAndroid/include/CRIBsAndroid.h"
    export *
}
EOF

cd "$ROOT"
echo "==> macOS 빌드"
swift build
macos_bin="$(swift build --show-bin-path)"

ios_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
ios_flags=(--target RIBsUIKit --triple "$IOS_TARGET" --sdk "$ios_sdk" --scratch-path "$IOS_SCRATCH")
echo "==> iOS 시뮬레이터 빌드(RIBsUIKit)"
swift build "${ios_flags[@]}"
ios_bin="$(swift build "${ios_flags[@]}" --show-bin-path)"

macos_sdk="$(xcrun --sdk macosx --show-sdk-path)"

# digester가 모듈을 읽을 때 쓰는 인자. RIBsUIKit만 iOS 시뮬레이터 빌드에서 읽는다.
module_flags() { # module
    local bin="$macos_bin" sdk="$macos_sdk" target="$MACOS_TARGET" ios
    for ios in "${IOS_MODULES[@]}"; do
        if [[ "$1" == "$ios" ]]; then bin="$ios_bin" sdk="$ios_sdk" target="$IOS_TARGET"; fi
    done
    echo "-module $1 -I $bin -I $bin/Modules -I $work/modulemap -sdk $sdk -target $target -swift-only"
}

for module in "${MACOS_MODULES[@]}" "${IOS_MODULES[@]}"; do
    # shellcheck disable=SC2046 # 경로에 공백이 없는 빌드 디렉터리를 전제로 한다
    xcrun swift-api-digester -dump-sdk $(module_flags "$module") \
        -avoid-location -avoid-tool-args -abort-on-module-fail -o "$work/$module.json"
done

if [[ "$mode" == "update" ]]; then
    mkdir -p "$API_DIR"
    for module in "${MACOS_MODULES[@]}" "${IOS_MODULES[@]}"; do
        cp "$work/$module.json" "$API_DIR/$module.json"
    done
    echo "==> api/ 덤프를 갱신했습니다."
    exit 0
fi

failed=0
for module in "${MACOS_MODULES[@]}" "${IOS_MODULES[@]}"; do
    baseline_file="$API_DIR/$module.json"
    if [[ ! -f "$baseline_file" ]]; then
        echo "error: $baseline_file 이 없습니다. scripts/check-api.sh --update로 만드세요." >&2
        failed=1
        continue
    fi
    if cmp -s "$baseline_file" "$work/$module.json"; then
        echo "ok: $module"
        continue
    fi
    failed=1
    echo "error: $module 공개 API가 api/$module.json과 다릅니다." >&2
    # 깨지는 변경(삭제·시그니처 변경)을 사람이 읽을 수 있게 요약한다. 추가만 있으면 아래 diff로만 보인다.
    echo "--- $module: 기준 덤프 대비 깨지는 변경" >&2
    # shellcheck disable=SC2046
    xcrun swift-api-digester -diagnose-sdk $(module_flags "$module") -baseline-path "$baseline_file" 2>&1 \
        | grep -vE '^(/\*.*\*/)?$' >&2 || echo "(없음: 추가만 있음)" >&2
    diff -u "$baseline_file" "$work/$module.json" >&2 || true
done

if [[ -n "$baseline" ]]; then
    echo "==> swift package diagnose-api-breaking-changes $baseline"
    swift package diagnose-api-breaking-changes "$baseline" \
        --products RIBs RIBsSwiftUI RIBsUIKit RIBsWeb RIBsAndroid || failed=1
fi

if [[ "$failed" -ne 0 ]]; then
    echo "공개 API가 바뀌었습니다. 의도한 변경이면 scripts/check-api.sh --update 후 api/를 함께 커밋하세요." >&2
    exit 1
fi
echo "==> 공개 API가 덤프와 같습니다."
