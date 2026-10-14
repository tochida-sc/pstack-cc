#!/usr/bin/env bash
# 上流の取り込みに失敗した run を Slack に知らせる。sync-upstream.yml の失敗時にだけ呼ばれる
# 必要な環境変数: SLACK_WEBHOOK_URL (Slack の Incoming Webhook)、RUN_URL (失敗した run の URL)
set -euo pipefail
root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
	echo "::error::secret SLACK_WEBHOOK_URL is not set, so Slack was not notified. Add it in the repository settings."
	exit 1
fi

text="pstack-cc: upstream sync failed. Run: ${RUN_URL:-unknown}"
if [ -s "$root/auto-sync-report.md" ]; then
	text="$text
$(head -c 2500 "$root/auto-sync-report.md")"
fi

payload="$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1]}))' "$text")"
curl -fsS -X POST -H 'Content-Type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL"
