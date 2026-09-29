# pstack-cc

[English](README.md) | 日本語

[pstack](https://github.com/cursor/plugins/tree/main/pstack)(Lauren Tan / poteto 作、Cursor 用プラグイン、MIT)を Claude Code で使えるようにしたプラグインの marketplace。

[souljazzfunk/lab](https://github.com/souljazzfunk/lab/tree/main/pstack-cc) の `pstack-cc/` を履歴ごと切り出したもの。

## 使う

Claude Code で:

```
/plugin marketplace add tochida-sc/pstack-cc
/plugin install pstack@lab
```

再起動は不要。インストール時に指示が出たら `/reload-plugins` を実行すると、今のセッションに読み込まれる。

使えるのは手元の Claude Code(CLI・デスクトップアプリ・IDE)。クラウドのセッション(Claude Code on the web)には `/plugin` コマンドがなく、手元で入れたプラグインもリポジトリの `.claude/settings.json` で有効にしたプラグインも読み込まれない。そこで `/pstack:*` を使うには、組織の管理者が managed settings で配布する必要がある。

スキルは `/pstack:<名前>` で呼ぶ(例: `/pstack:poteto-mode`、`/pstack:how`)。最初に `/pstack:setup-pstack` を一度実行すると、役割ごとのモデルを選べる。

使い方・仕組み・上流の取り込み方は [`pstack-cc/README.md`](pstack-cc/README.md)、チュートリアルは [`pstack-cc/docs/tutorial.ja.md`](pstack-cc/docs/tutorial.ja.md)、スキルの関係図は [`pstack-cc/docs/skill-map.ja.md`](pstack-cc/docs/skill-map.ja.md)。

## ライセンス

MIT。pstack 本体は `vendor/pstack/LICENSE`(Lauren Tan)、変換の仕組みは `LICENSE`(souljazzfunk)。
