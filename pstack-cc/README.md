# pstack-cc

[pstack](https://github.com/cursor/plugins/tree/main/pstack)(Lauren Tan / poteto 作、Cursor 用プラグイン、MIT)を Claude Code で使えるように変換する仕組み。

上流は無改造のまま `vendor/pstack/` に置き、Claude Code 向けの差分はこのディレクトリにだけ持つ。上流が更新されたら、取り込み直して build を再実行するだけで追従できる。

## 使う

Claude Code で:

```
/plugin marketplace add tochida-sc/pstack-cc
/plugin install pstack@lab
```

再起動は不要。インストール時に指示が出たら `/reload-plugins` を実行すると、今のセッションに読み込まれる。

使えるのは手元の Claude Code(CLI・デスクトップアプリ・IDE)。クラウドのセッション(Claude Code on the web)には `/plugin` コマンドがなく、手元で入れたプラグインもリポジトリの `.claude/settings.json` で有効にしたプラグインも読み込まれない。そこで `/pstack:*` を使うには、組織の管理者が managed settings で配布する必要がある。

スキルは `/pstack:<名前>` で呼ぶ(例: `/pstack:poteto-mode`、`/pstack:how`、`/pstack:architect`)。最初に `/pstack:setup-pstack` を一度実行すると、役割ごとのモデルを選べる(しなくても既定値で動く)。

pstack の作者による記事 2 本と講演の内容を、自分のリポジトリで手を動かしながらたどるチュートリアルが [`docs/tutorial.ja.md`](docs/tutorial.ja.md)(英語版 [`docs/tutorial.en.md`](docs/tutorial.en.md))にある。

## スキルの関係図

スキル同士の参照関係と、各スキルがサブエージェントをどう動かすかは [`docs/skill-map.ja.md`](docs/skill-map.ja.md)(英語版 [`docs/skill-map.en.md`](docs/skill-map.en.md))。

## 仕組み

```
vendor/pstack/            上流そのまま(手で編集しない)
pstack-cc/
├── UPSTREAM              取り込んだ上流のコミット
├── sync-upstream.sh      上流を vendor/pstack/ に取り込む
├── build.py              vendor/pstack/ → plugin/ に変換する(置き換えルールもここ)
├── claude-code.md        Cursor と Claude Code の対応表(plugin/ に同梱される)
├── docs/                 スキルの関係図(日本語・英語)
├── overrides/            丸ごと差し替えるファイル(今は setup-pstack だけ)
└── plugin/               生成物(手で編集しない)。marketplace はここを配る
.claude-plugin/marketplace.json
```

`build.py` がすること:

1. `vendor/pstack/` から `skills/`・`agents/`・`LICENSE` を写す(`automations/` と `docs/` は Cursor 専用か記事なので入れない)
2. `overrides/` のファイルで差し替える
3. 置き換えルールを当てる: `~/.cursor/...` のパス、`Task` → `Agent`、`generalPurpose` → `general-purpose`、モデル名(`claude-opus-5-5-xhigh` などの Opus → `opus`、`grok-4.7-xhigh-fast` などの Grok → `sonnet`)、会話ログの場所、`/swarm` のクラウド実行 → ローカルの worktree、など
4. frontmatter を Claude Code の形に揃える(スキル名をディレクトリ名に。Cursor 専用のキーを外す)
5. 各スキルの先頭に「`claude-code.md` を読んで」という一文を入れる
6. `plugin.json` と README を生成する。版は `<上流の版>-cc.<上流のコミット>.<変換側のハッシュ>`。変換側 (`build.py`、`overrides/`、`claude-code.md`) だけを直しても版が変わるので、`claude plugin update` が拾う

**安全装置**: ルールごとに「最低何回当たるはずか」を決めてある。上流の文章が変わってルールが当たらなくなったり、`~/.cursor/` などが変換されずに残ったりしたら、build は失敗して該当箇所を表示する。

## 上流の更新を取り込む

```bash
pstack-cc/sync-upstream.sh          # 既定は main。コミットやタグも指定できる
git diff --stat vendor/pstack       # 上流で何が変わったかを見る
python3 pstack-cc/build.py          # 変換し直す
claude plugin validate --strict pstack-cc/plugin
git add vendor/pstack pstack-cc && git commit
```

build が失敗したら、表示されたルール(`build.py` の `RULES`)を新しい文章に合わせて直す。`overrides/` にあるファイルの上流版が変わったときは、変更点を手で反映する。

### 自動の取り込み

`.github/workflows/sync-upstream.yml` が毎日 03:00 JST に `pstack-cc/auto-sync.sh` を実行する。上流に変更があり、build と `claude plugin validate --strict` が通れば、main にコミットして push する。次の場合は push せず、Issue「Upstream sync needs a manual fix」にログを載せる。

- build が失敗した (ルールが当たらなくなった、など)
- `overrides/` で差し替えているファイルの上流版が変わった

Issue が立ったら、上の手順で手で取り込む。手元では、マーケットプレイスの `autoUpdate` を有効にしておくと、Claude Code の起動時に新しい版が入る。

## 変換しきれないもの

Cursor にしかない機能(クラウドエージェント、automations、Custom Modes、`cursor-team-kit` のスキル)に頼る部分は、文章を残したまま `claude-code.md` で代わりのやり方を説明している。特に:

- `/swarm` などの並列実行は、Cursor のクラウドではなく手元の worktree で動く。同時に動かす数は少なめ(5 前後)にする。
- `/architect`・`/arena`・`/interrogate` の「別々のモデルで案を出させる」は、別会社のモデルではなく Claude 同士(opus / sonnet)になる。
- `/poteto-mode` は Cursor のように固定できない。新しいタスクのたびに呼び直す。

## ライセンス

pstack は MIT(`vendor/pstack/LICENSE`)。生成物にも同じ LICENSE を同梱している。
