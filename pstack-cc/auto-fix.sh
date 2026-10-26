#!/usr/bin/env bash
# auto-sync.sh が 20 (手で直す必要がある) で止まったあとに呼ぶ。Claude Code に build.py の RULES と overrides/ を直させ、
# build と validate が通れば main にコミットする。push は呼び出し側 (GitHub Actions) がする。
# 終了コード: 0 = 直してコミットした / 1 = 直せなかった (作業ツリーは auto-sync.sh が止まった状態に戻す)
# 前提: auto-sync.sh を実行した直後の作業ツリー (vendor/pstack は上流の新しい版、未コミット)。auto-sync-report.md がある。
set -uo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$root"
report="$root/auto-sync-report.md"
log="$root/auto-fix-log.md"
python="${PYTHON:-python3}"
[ -f "$report" ] || { echo "auto-sync-report.md がありません"; exit 1; }

# Claude が触ってよいのは build.py と overrides/ だけ。vendor/pstack は上流のまま残す
vendor_before="$(git diff -- vendor/pstack | sha256sum)"
changed() { git status --porcelain --untracked-files=all | cut -c4- | sort; }
status_before="$(changed)"
backup="$(mktemp -d)"
cp pstack-cc/build.py "$backup/build.py"
cp -R pstack-cc/overrides "$backup/overrides"

give_up() {
	echo "$1"
	echo "$1" >> "$log"
	cp "$backup/build.py" pstack-cc/build.py
	rm -rf pstack-cc/overrides && cp -R "$backup/overrides" pstack-cc/overrides
	git checkout -q -- pstack-cc/plugin 2>/dev/null
	git clean -qfd -- pstack-cc/plugin pstack-cc/overrides
	exit 1
}

prompt="$(cat <<EOF
あなたは GitHub Actions の中で、上流 pstack (cursor/plugins の pstack/) の取り込みが止まった原因を直します。
リポジトリの説明は pstack-cc/README.md にあります。vendor/pstack は上流の新しい版で、git diff -- vendor/pstack で上流の変更が見えます。

止まった理由 (auto-sync-report.md):
$(cat "$report")

やること:
- build.py が「当たらなくなったルール」を出したときは、vendor/pstack の新しい文章を読み、pstack-cc/build.py の RULES の pattern を新しい文章に合わせる。repl も同じ変更 (番号の付け替えなど) を反映する。ルールの意図 (Cursor 専用の説明を Claude Code 向けに書き換える) は変えない。
- overrides/ にあるファイルの上流版が変わったときは、git diff -- vendor/pstack/<file> の変更点を pstack-cc/overrides/<file> に反映する。Claude Code 向けに書き換えてある部分は残す。
- 直したら python3 pstack-cc/build.py を実行して通ることを確かめる。
- 変更してよいのは pstack-cc/build.py と pstack-cc/overrides/ の中だけ。vendor/pstack は変えない。ルールを消したり min_hits を 0 にしたりして失敗を隠さない。
- 意図が読み取れず安全に直せないときは、何も変えずに理由を書いて終える。
最後に、何をどう直したかを 3 行以内で書く。
EOF
)"

echo "## Claude による自動修正" > "$log"
echo >> "$log"
claude -p "$prompt" \
	--max-turns 60 \
	--allowedTools "Read,Grep,Glob,Edit(pstack-cc/build.py),Edit(pstack-cc/overrides/**),Write(pstack-cc/overrides/**),Bash(python3 pstack-cc/build.py),Bash(python3 pstack-cc/build.py --check),Bash(git diff:*),Bash(git status:*)" \
	>> "$log" 2>&1 || give_up "claude の実行が失敗しました。"
summary="$(sed -n '3,$p' "$log" | tail -n 20)"

# 触ってはいけない場所を変えていないか
[ "$(git diff -- vendor/pstack | sha256sum)" = "$vendor_before" ] || { git checkout -q -- vendor/pstack; give_up "Claude が vendor/pstack を変えたので取り消しました。"; }
outside="$(comm -13 <(echo "$status_before") <(changed) |
	grep -v -E '^(pstack-cc/build\.py$|pstack-cc/overrides/|pstack-cc/plugin/|auto-fix-log\.md$)')"
[ -z "$outside" ] || give_up "Claude が許可外のファイルを変えました: $outside"
git diff --quiet -- pstack-cc/build.py pstack-cc/overrides && [ -z "$(git ls-files --others --exclude-standard pstack-cc/overrides)" ] &&
	give_up "Claude は何も変えませんでした。"
grep -q 'min_hits=0' <(git diff -- pstack-cc/build.py | grep '^+') && give_up "Claude が min_hits=0 でルールを無効にしたので取り消しました。"

# auto-sync.sh と同じ確認をやり直す
out="$(mktemp)"
"$python" pstack-cc/build.py > "$out" 2>&1 || { cat "$out" >> "$log"; give_up "直したあとも build.py が失敗しました。"; }
claude plugin validate --strict pstack-cc/plugin > "$out" 2>&1 || { cat "$out" >> "$log"; give_up "直したあとも claude plugin validate が失敗しました。"; }

after="$(sed -n 's/^commit: //p' pstack-cc/UPSTREAM)"
version="$(sed -n 's/.*"version": "\(.*\)".*/\1/p' pstack-cc/plugin/.claude-plugin/plugin.json)"
git add vendor/pstack pstack-cc
git commit -q -m "Sync upstream pstack ${after:0:7} ($version)" \
	-m "Auto-fixed by Claude Code in .github/workflows/sync-upstream.yml after: $(sed -n '1p' "$report" | sed 's/^.*止めました: //')" \
	-m "$summary"
echo "直してコミットしました: $version"
