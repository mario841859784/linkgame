#!/bin/bash
# 一键发版：更新版本号 → 构建（arm64 正式签名）→ GitHub Release → 增量补丁 → latest.json
#
# App 的应用内自更新以 APK 资产文件名里的 +versionCode 判断是否需要升级，
# 因此版本号格式必须是 <major>.<minor>.<patch>+<code>，且 code 必须递增。
#
# 体积策略：
# - 只打 arm64（真机全是 arm64；GitHub 上保留本包供手动下载）
# - 自动为最近 3 个历史版本生成 bsdiff 增量补丁，App 优先下载补丁、失败回退全量
#
# 用法: ./scripts/release.sh <版本号> [发版说明]
# 示例: ./scripts/release.sh 1.2.0+8 "增量更新 + 瘦身"
set -euo pipefail

VER="${1:?用法: release.sh <版本号，如 1.2.0+8> [发版说明]}"
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

# 2. 构建正式签名 APK（仅 arm64：体积减半；flutter 产物已是确定性布局）
flutter build apk --release --target-platform android-arm64

# 3. 复制为带版本号的资产名（App 依赖文件名里的 +versionCode）
TAG="v${VER%%+*}"
NAME_PART="${VER%%+*}"
CODE_PART="${VER##*+}"
OUT="${ROOT}/build/app/outputs/flutter-apk/linkgame-${VER}.apk"
cp "build/app/outputs/flutter-apk/app-release.apk" "${OUT}"
NEW_SHA=$(shasum -a 256 "${OUT}" | cut -d' ' -f1)
echo "新包: $(du -h "${OUT}" | cut -f1)  sha256=${NEW_SHA:0:12}..."

# 4. 创建/复用 release 并上传
gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1 \
  || gh release create "${TAG}" -R "${REPO}" --title "连连看 ${VER}" --notes "${NOTES}"
gh release upload "${TAG}" -R "${REPO}" "${OUT}" --clobber

# 5. 为最近 3 个历史版本生成 bsdiff 增量补丁
#    补丁资产命名: linkgame-<新ver>-from-<旧ver>.patch
TMPDIR_PATCH="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_PATCH}"' EXIT
PATCH_ENTRIES="[]"
OLD_TAGS=$(gh release list -R "${REPO}" --limit 8 --json tagName \
  | python3 -c "import json,sys; [print(r['tagName']) for r in json.load(sys.stdin) if r['tagName'].startswith('v') and r['tagName'] != '${TAG}']" \
  | head -3 || true)
for OLD_TAG in ${OLD_TAGS}; do
  OLD_ASSET=$(gh release view "${OLD_TAG}" -R "${REPO}" --json assets \
    | python3 -c "import json,sys; assets=json.load(sys.stdin)['assets']; print(next((a['name'] for a in assets if a['name'].endswith('.apk')), ''))" || true)
  [ -z "${OLD_ASSET}" ] && continue
  OLD_CODE=$(python3 -c "import re,sys; m=re.search(r'\+(\d+)\.apk$', sys.argv[1]); print(m.group(1) if m else '')" "${OLD_ASSET}")
  [ -z "${OLD_CODE}" ] && continue
  echo "生成补丁 ${OLD_TAG}(${OLD_CODE}) -> ${VER} ..."
  gh release download "${OLD_TAG}" -R "${REPO}" -p "${OLD_ASSET}" -O "${TMPDIR_PATCH}/old.apk" >/dev/null 2>&1 \
    || { echo "⚠️ ${OLD_TAG} 旧包下载失败，跳过"; continue; }
  OLD_NAME="${OLD_TAG#v}"
  PATCH_FILE="${ROOT}/build/app/outputs/flutter-apk/linkgame-${VER}-from-${OLD_NAME}+${OLD_CODE}.patch"
  python3 - "${TMPDIR_PATCH}/old.apk" "${OUT}" "${PATCH_FILE}" <<'PY'
import sys
import bsdiff4
bsdiff4.file_diff(sys.argv[1], sys.argv[2], sys.argv[3])
PY
  PATCH_SIZE=$(stat -f "%z" "${PATCH_FILE}")
  OLD_SIZE=$(stat -f "%z" "${TMPDIR_PATCH}/old.apk")
  OLD_SHA=$(shasum -a 256 "${TMPDIR_PATCH}/old.apk" | cut -d' ' -f1)
  PATCH_SHA=$(shasum -a 256 "${PATCH_FILE}" | cut -d' ' -f1)
  gh release upload "${TAG}" -R "${REPO}" "${PATCH_FILE}" --clobber
  PATCH_ENTRIES=$(python3 - "${OLD_CODE}" "${OLD_SHA}" "$(basename "${PATCH_FILE}")" "${PATCH_SIZE}" "${PATCH_SHA}" "${OLD_SIZE}" "${NEW_SHA}" <<'PY'
import json, sys
from_code, from_sha, asset, size, sha, out_size, out_sha = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]), sys.argv[7]
print(json.dumps([{"fromCode": int(from_code), "fromSha256": from_sha, "asset": asset,
                   "size": size, "sha256": sha, "outSize": out_size, "outSha256": out_sha}]))
PY
)
  echo "   补丁 $(du -h "${PATCH_FILE}" | cut -f1)（原全量 $(du -h "${OUT}" | cut -f1)）"
done

# 6. 生成 latest.json（含补丁清单），写进仓库 hotfix/ 目录并同步到 tag hotfix
LATEST_JSON="${ROOT}/hotfix/latest.json"
python3 - "${NAME_PART}" "${CODE_PART}" "${LATEST_JSON}" "${PATCH_ENTRIES}" <<'PY'
import json, sys
name, code, out, patches = sys.argv[1], int(sys.argv[2]), sys.argv[3], json.loads(sys.argv[4])
meta = {
    "versionName": name,
    "versionCode": code,
    "apkAsset": f"linkgame-{name}+{code}.apk",
    "tag": f"v{name}",
    "patches": patches,
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

# 7. 提交版本变更与 latest.json，刷新 jsDelivr 缓存
git add pubspec.yaml hotfix/latest.json
git commit -m "chore: release v${NAME_PART}+${CODE_PART}"
git push
curl -s --max-time 10 "https://purge.jsdelivr.net/gh/${REPO}@main/hotfix/latest.json" >/dev/null || true

echo "✅ ${VER} 已发布"
echo "   release: https://github.com/${REPO}/releases/tag/${TAG}"
