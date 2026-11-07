#!/bin/bash
# 发布内容热更包到 GitHub Releases（固定 tag: hotfix）
#
# 内容以 hotfix/hotfix-content.json 为唯一事实来源（rev 在这里手动递增），
# 脚本据此生成 hotfix-manifest.json 并上传到 tag `hotfix` 的 release。
# 应用启动时通过多源回退拉取，改完内容跑一次本脚本即全网生效。
#
# 用法: ./scripts/publish-hotfix.sh   （需要 gh 已登录）
set -euo pipefail

REPO="mario841859784/linkgame"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOTFIX_DIR="$ROOT/hotfix"

# 1. 读取 rev 并生成 manifest
REV=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['rev'])" "$HOTFIX_DIR/hotfix-content.json")
python3 - "${REV}" "$HOTFIX_DIR" <<'PY'
import json, sys
rev, out = int(sys.argv[1]), sys.argv[2]
manifest = {"app": "link_game", "rev": rev, "content": "hotfix-content.json"}
with open(out + "/hotfix-manifest.json", "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

# 2. 校验 JSON 合法性（发布前拦截）
python3 -c "import json,sys; json.load(open(sys.argv[1])); json.load(open(sys.argv[2]))" \
  "$HOTFIX_DIR/hotfix-manifest.json" "$HOTFIX_DIR/hotfix-content.json"

# 3. 创建或复用 tag `hotfix` 的 release，上传资产（--clobber 覆盖旧资产）
gh release view hotfix -R "$REPO" >/dev/null 2>&1 \
  || gh release create hotfix -R "$REPO" \
       --title "内容热更 r${REV}" \
       --notes "内容热更 rev ${REV}，应用启动时自动拉取，无需重装 APK"
gh release upload hotfix -R "$REPO" \
  "$HOTFIX_DIR/hotfix-manifest.json" "$HOTFIX_DIR/hotfix-content.json" --clobber

# 4. 提交仓库文件并刷新 jsDelivr 缓存（App 检查源首位走 jsDelivr）
if ! git diff --quiet HEAD -- "$HOTFIX_DIR" 2>/dev/null; then
  git add "$HOTFIX_DIR"
  git commit -m "chore: 内容热更 r${REV}"
  git push
fi
curl -s --max-time 10 "https://purge.jsdelivr.net/gh/${REPO}@main/hotfix/hotfix-manifest.json" >/dev/null || true
curl -s --max-time 10 "https://purge.jsdelivr.net/gh/${REPO}@main/hotfix/hotfix-content.json" >/dev/null || true

echo "✅ 内容热更 r${REV} 已发布"
echo "   manifest: https://github.com/${REPO}/releases/download/hotfix/hotfix-manifest.json"
