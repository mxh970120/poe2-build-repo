#!/usr/bin/env bash
# 把 poe2-build-cn 技能安装到本机的 Claude Code。
# 用法：
#   bash install.sh              # 装到个人目录，全局可用
#   bash install.sh --project    # 只装到当前仓库，随仓库走
#   bash install.sh --uninstall  # 卸载个人目录里的这一份
# Git Bash / WSL / macOS / Linux 通用。

set -euo pipefail

SKILL_NAME='poe2-build-cn'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SOURCE="$HERE/SKILL.md"

MODE='user'
for arg in "$@"; do
  case "$arg" in
    --project)   MODE='project' ;;
    --uninstall) MODE='uninstall' ;;
    *) echo "未知参数：$arg" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = 'project' ]; then
  BASE="$REPO_ROOT/.claude/skills"
else
  BASE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
fi
TARGET="$BASE/$SKILL_NAME"

if [ "$MODE" = 'uninstall' ]; then
  if [ -d "$TARGET" ]; then rm -rf "$TARGET"; echo "[已卸载] $TARGET"; else echo "[跳过] 未找到 $TARGET"; fi
  exit 0
fi

[ -f "$SOURCE" ] || { echo "找不到源文件：$SOURCE" >&2; exit 1; }

mkdir -p "$TARGET"
cp -f "$SOURCE" "$TARGET/SKILL.md"

echo
echo "[已安装] $TARGET/SKILL.md"
echo "         $(wc -c <"$TARGET/SKILL.md" | tr -d ' ') 字节 / $(wc -l <"$TARGET/SKILL.md" | tr -d ' ') 行"
echo
echo "校验前三行："
head -3 "$TARGET/SKILL.md" | sed 's/^/  /'
echo
echo "重启 Claude Code 后用 /doctor 或 /skills 确认 $SKILL_NAME 已出现。"
