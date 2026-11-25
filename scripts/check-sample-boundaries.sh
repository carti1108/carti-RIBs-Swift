#!/usr/bin/env bash
# 샘플의 모듈 경계를 import 문으로 검사한다(ADR-0024, ADR-0027, ADR-0028, ADR-0032).
#   µFeature: 피처 Impl은 자기 Interface와 Package.swift에 선언한 자식 Interface만 import한다.
#   데이터 계층: Foundation은 TodoData만 import하고, 피처는 TodoData를 import하지 않는다.
#   순수 뷰: UI 프레임워크만 import하고 공유 코드·브리지 타입을 import하지 않는다.
# 빌드가 필요 없어 어느 호스트에서나 돈다. 위반이 있으면 목록을 출력하고 1로 끝난다.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
samples="$repo/Samples"
modular="$samples/TodoModular"
failures=0

report() {
    echo "$1"
    failures=$((failures + 1))
}

# allow_swift_imports <디렉터리> <검사할 모듈 이름 정규식> <허용 모듈...>
# 정규식에 맞는 import 가운데 허용 목록에 없는 것을 위반으로 본다.
allow_swift_imports() {
    local dir="$1" pattern="$2"
    shift 2
    [ -d "$dir" ] || { report "없는 디렉터리: ${dir#"$repo"/}"; return; }
    local file module allowed candidate
    while IFS=: read -r file _ module; do
        allowed=no
        for candidate in "$@"; do
            [ "$module" = "$candidate" ] && allowed=yes
        done
        [ "$allowed" = yes ] || report "${file#"$repo"/}: import $module"
    done < <(
        grep -rnE --include='*.swift' "^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+${pattern}([[:space:]]|\$)" "$dir" \
            | sed -E 's/^([^:]+):([0-9]+):[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+([A-Za-z0-9_]+).*/\1:\2:\4/' \
            || true
    )
}

# forbid_pattern <디렉터리> <파일 glob> <금지 정규식> <설명>
forbid_pattern() {
    local dir="$1" glob="$2" pattern="$3" label="$4"
    [ -d "$dir" ] || { report "없는 디렉터리: ${dir#"$repo"/}"; return; }
    local hit
    while IFS= read -r hit; do
        report "${hit#"$repo"/} ($label)"
    done < <(grep -rnE --include="$glob" "$pattern" "$dir" || true)
}

# Package.swift의 `feature("LoggedIn", interfaces: ["TodoList", "TodoDetail"])`에서 자식 피처 이름을 읽는다.
child_interfaces() {
    sed -nE "s/.*feature\\(\"$1\", interfaces: \\[([^]]*)\\].*/\\1/p" "$modular/Shared/Package.swift" \
        | tr -d '" ' | tr ',' '\n' | sed -E '/^$/d; s/^(.*)$/Feature\1Interface/'
}

any_feature='Feature[A-Za-z0-9_]*'
any_module='[A-Za-z0-9_]+'

for feature_dir in "$modular"/Shared/Features/*/; do
    feature_dir="${feature_dir%/}"
    feature="$(basename "$feature_dir")"
    own="Feature${feature}Interface"
    children=()
    while IFS= read -r child; do
        [ -n "$child" ] && children+=("$child")
    done < <(child_interfaces "$feature")

    # 공유 패키지: Impl과 Interface (ADR-0024)
    allow_swift_imports "$feature_dir/Sources" "$any_feature" "$own" ${children[@]+"${children[@]}"}
    allow_swift_imports "$feature_dir/Interface" "$any_feature" ${children[@]+"${children[@]}"}

    # 플랫폼 피처 타깃: 자기 Interface만 안다
    allow_swift_imports "$modular/Android/swift/Sources/Feature${feature}Android" "$any_feature" "$own"
    allow_swift_imports "$modular/Web/Sources/Feature${feature}Web" "$any_feature" "$own"
    allow_swift_imports "$modular/iOS/Features/$feature/Adapter" "$any_feature" "$own" "Feature${feature}UI"

    # 순수 뷰 (ADR-0027)
    allow_swift_imports "$modular/iOS/Features/$feature/UI" "$any_module" SwiftUI
done

# 데이터 계층 (ADR-0032): Foundation은 TodoData만 쓰고, 피처는 TodoData를 모른다.
for shared_dir in Core Features App; do
    forbid_pattern "$modular/Shared/$shared_dir" '*.swift' '^[[:space:]]*import[[:space:]]+Foundation' 'TodoData 밖에서 Foundation을 import'
done
forbid_pattern "$modular/Shared/Features" '*.swift' '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+TodoData([[:space:]]|$)' '피처가 데이터 계층 구현을 import'

allow_swift_imports "$samples/iOSLogin/Sources/Views" "$any_module" SwiftUI
for gradle in "$modular"/Android/feature/*/ui/build.gradle.kts; do
    grep -qE '^[^/]*project\(":bridge"\)' "$gradle" && report "${gradle#"$repo"/} (순수 뷰 모듈이 :bridge에 의존)"
done
forbid_pattern "$samples/AndroidLogin/app/src/main/kotlin/com/carti/ribs/samples/swiftandroid/views" '*.kt' \
    '^import (com\.carti\.ribs\.samples\.swiftandroid\.bridge|org\.swift)\.' '순수 뷰가 브리지 타입을 import'
forbid_pattern "$modular/Web/features" 'view.tsx' '^import .* from "(\.\./|\./adapter)' '순수 뷰가 React 밖을 import'
forbid_pattern "$samples/WebLogin/views" '*.js' '^import .* from "\.\./' '순수 뷰가 views/ 밖을 import'

if [ "$failures" -gt 0 ]; then
    echo "경계 위반 ${failures}건"
    exit 1
fi
echo "경계 위반 없음"
