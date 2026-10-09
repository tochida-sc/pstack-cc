#!/usr/bin/env bash
# 上流の pstack を取り込み、build と validate が通れば main にコミットする。push は呼び出し側 (GitHub Actions) がする。
# 終了コード: 0 = 更新してコミットした / 10 = 上流に変更なし / 20 = 手で直す必要がある (理由は auto-sync-report.md)
set -uo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$root"
report="$root/auto-sync-report.md"
python="${PYTHON:-python3}"
before="$(sed -n 's/^commit: //p' pstack-cc/UPSTREAM)"

pstack-cc/sync-upstream.sh main >/dev/null || exit 1
after="$(sed -n 's/^commit: //p' pstack-cc/UPSTREAM)"
if [ "$before" = "$after" ] && git diff --quiet -- vendor/pstack; then
	git checkout -q -- pstack-cc/UPSTREAM
	echo "上流に変更なし (${after:0:7})"
	exit 10
fi

fail() {
	{
		echo "上流 \`${before:0:7}\` → \`${after:0:7}\` の取り込みを止めました: $1"
		echo
		echo '```'
		cat "$2"
		echo '```'
		echo
		echo "手順は pstack-cc/README.md の「上流の更新を取り込む」。"
	} > "$report"
	echo "$1"
	exit 20
}

# overrides/ で丸ごと差し替えているファイルの上流版が変わったら、自動では取り込まない
drift="$(mktemp)"
(cd pstack-cc/overrides && find . -type f | sed 's|^\./||') | while read -r f; do
	git diff --quiet -- "vendor/pstack/$f" || git diff -- "vendor/pstack/$f"
done > "$drift"
[ -s "$drift" ] && fail "overrides/ にあるファイルの上流版が変わりました。変更点を overrides/ に手で反映してください。" "$drift"

log="$(mktemp)"
"$python" pstack-cc/build.py > "$log" 2>&1 || fail "build.py が失敗しました。表示されたルールを build.py の RULES で直してください。" "$log"
claude plugin validate --strict pstack-cc/plugin > "$log" 2>&1 || fail "claude plugin validate が失敗しました。" "$log"

version="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' pstack-cc/plugin/.claude-plugin/plugin.json)"
git add vendor/pstack pstack-cc
git commit -q -m "Sync upstream pstack ${after:0:7} ($version)" -m "Automated by .github/workflows/sync-upstream.yml."
echo "コミットしました: $version"
