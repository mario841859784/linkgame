#!/bin/bash
# 一键发版：更新版本号 → 构建（正式签名）→ GitHub Release（APK 资产名含 +versionCode）
#
# App 的应用内自更新以 APK 资产文件名里的 +versionCode 判断是否需要升级，
# 因此版本号格式必须是 <major>.<minor>.<patch>+<code>，且 code 必须递增。
#
# 用法: ./scripts/release.sh <版本号> [发版说明]
# 示例: ./scripts/release.sh 1.1.0+2 "修复语速与放大镜"
#
# 注意: 发布不会自动 git commit，pubspec.yaml 的版本变更需要手动提交。
set -euo pipefail

VER="${1:?用法: release.sh <版本号，如 1.1.0+2> [发版说明]}"
NOTES="${2:-连连看 ${VER}}"
REPO="mario841859784/linkgame"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# 0. 前置检查：正式签名必须就绪（没有 keystore 就会发出无法覆盖安装的包）
if [ ! -f "android/key.jks" ] || [ ! -f "android/key.properties" ]; then
  echo "❌ 缺少 android/key.jks 或 android/key.properties，无法构建正式签名包" >&2
  exit 1
fi

# 1. 更新 pubspec 版本号
python3 - "${VER}" <<'PY'
import re, sys
ver = sys.argv[1]
with open('pubspec.yaml') as f:
    content = f.read()
content = re.sub(r'^version: .*$', f'version: {ver}', content, count=1, flags=re.M)
with open('pubspec.yaml', 'w') as f:
    f.write(content)
print(f'version -> {ver}')
PY

# 2. 构建正式签名 APK
flutter build apk --release

# 3. 复制为带版本号的资产名（App 依赖文件名里的 +versionCode）
TAG="v${VER%%+*}"
OUT="${ROOT}/build/app/outputs/flutter-apk/linkgame-${VER}.apk"
cp "build/app/outputs/flutter-apk/app-release.apk" "${OUT}"

# 4. 创建/复用 release 并上传
gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1 \
  || gh release create "${TAG}" -R "${REPO}" --title "连连看 ${VER}" --notes "${NOTES}"
gh release upload "${TAG}" -R "${REPO}" "${OUT}" --clobber

# 5. 生成 latest.json（写进仓库 hotfix/ 目录，jsDelivr 检查源从这里取）
#    并同步到 tag hotfix 的 release 资产
NAME_PART="${VER%%+*}"
CODE_PART="${VER##*+}"
LATEST_JSON="${ROOT}/hotfix/latest.json"
python3 - "${NAME_PART}" "${CODE_PART}" "${LATEST_JSON}" <<'PY'
import json, sys
name, code, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
meta = {
    "versionName": name,
    "versionCode": code,
    "apkAsset": f"linkgame-{name}+{code}.apk",
    "tag": f"v{name}",
}
with open(out, "w") as f:
    json.dump(meta, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
if gh release view hotfix -R "${REPO}" >/dev/null 2>&1; then
  gh release upload hotfix -R "${REPO}" "${LATEST_JSON}" --clobber
  echo "   latest.json 已同步到 tag hotfix"
else
  echo "⚠️ tag hotfix release 不存在，跳过 latest.json 同步（先跑 publish-hotfix.sh）" >&2
fi

# 6. 提交版本变更与 latest.json，刷新 jsDelivr 缓存
git add pubspec.yaml hotfix/latest.json
git commit -m "chore: release v${NAME_PART}+${CODE_PART}"
git push
curl -s --max-time 10 "https://purge.jsdelivr.net/gh/${REPO}@main/hotfix/latest.json" >/dev/null || true

echo "✅ ${VER} 已发布"
echo "   release: https://github.com/${REPO}/releases/tag/${TAG}"
