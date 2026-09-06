# ADR 0028: ワークフローエンジン(セルフホスト n8n)の切り分け・境界・配置

- **Status**: Accepted
- **Date**: 2026-09-06
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)
- **形式**: 決定索引方式(`practices/adr-workflow.md`)。経緯は `meta/CHANGELOG.md` の同日エントリ

## 決定

1. **切り分け**: セッション起点・対話中の自動化はハーネス(Workflow / loop / scheduled、いずれもオプトイン)。セッション外でイベント・時刻を起点に動く自動化と外部 SaaS 連携はワークフローエンジン(セルフホスト n8n)が担う。用語は `meta/glossary.md`。メインセッション(委譲の司令役)とは別物
2. **境界**(Private 側の CLAUDE.md と同文):
   - Claude Code → n8n は `http://localhost:5678/webhook/cc-*` への HTTP と `docker compose`(`up` / `restart` / `cp` / `exec … n8n import|export`)だけ。`cc-*` 以外の webhook は叩かない。`cc-*` は命名規則であって認可ではなく、副作用を持つ `cc-*` フローは Webhook ノードの Header Auth と Allowed Origins の限定を必須にする
   - Claude Code は `.env` と `backups/` を読まない・書かない。保証の実態は user-level の Read deny(cwd 相対)+ Private 側の project deny(`backups/**`、`docker compose config`、`docker inspect`)+ 指示。`docker compose exec … env`、cwd 外からの絶対パス Read、`bash -c '…'` とスクリプト経由の実行は機械保証しない(実測 2026-09-06。`Bash(bash -c *)` の deny は日常運用を壊すので入れない)
   - n8n → ホスト: コマンド実行しない。入力は個別ファイル単位の read-only bind mount に限り、集計はホスト側で行って結果 1 ファイルだけを渡す。ログを外部送信するフローは n8n 側で再 redaction する。Private repo の `workflows/`(n8n 自身の export 先)はこの制約の対象外
   - 外向き送信ノードを持つ `cc-*` フローを作る前に TODO 24 の deny を先に入れる。TODO 24 の carve-out は `localhost:5678/webhook/cc-*` への POST に限る
   - 資格情報の登録は運用者がブラウザで行う。Claude Code はフロー JSON(credential は名前参照)だけを扱う
3. **配置**: compose / 環境変数の雛形 / 手順書 / スクリプト / workflow export の真実源は Private repo 1 本。claude-system には本 ADR・索引の行・TODO・用語集だけを置き、Private repo への URL は書かない。インフラ選定(Mac ローカル OrbStack / Postgres 18 / external Task Runner / semver pin と公開 7 日の手動確認 / named volume / credentials export 不採用)は Private 側の決定索引が持つ
4. 本 ADR は基盤(サブプロジェクト 0)のみ扱う。用途別導入(運用ループ → プロダクト運用 → 個人)は TODO 26 として各々 brainstorming から始める。索引の行「観測は gating しない、昇格採否は人間」と「Workflow / loop / scheduled はオプトイン」は覆さない

## 根拠

- 公式 compose(`n8n-io/n8n-hosting` withPostgres)と CLI docs で、2.x の Task Runner 既定有効、`DB_TYPE=postgresdb`、`import:workflow --activeState=fromJson`、`update:workflow` の非推奨、Execute Command のコンテナ内実行を確認(https://github.com/n8n-io/n8n-hosting 、https://docs.n8n.io/deploy/host-n8n/configure-n8n/use-the-command-line)
- `settings.json.template` の実態: `Read(./.env)` は cwd 相対、`Bash(docker compose *)` は `up` / `exec` / `config` を含めて allow、`Bash(gh *)` allow、`pre-bash-guard.sh` は `git push` のみ。境界を「設計」と書くと嘘になる(反証レビュー 2026-09-06、`meta/CHANGELOG.md`)
- Sustainable Use License は自分のプロダクト運用の裏側で使う用途を許す(https://docs.n8n.io/sustainable-use-license/)

## 再評価トリガー

- TODO 10(レトロ連動の自動化、2026-10 判断)。24 時間稼働が要るフローの出現(VPS へ)。Server CLI の export / import が deprecated になったとき(`n8n-cli` へ)
- permissions で中間ワイルドカードの deny が仕様として確定したとき(境界の機械保証範囲を広げる)

## 不採用と理由

- MCP 経由の n8n 連携: HTTP と CLI で足りる(索引の MCP 不採用行を維持)
- claude-system 内に compose テンプレート: 実体と drift し検査機構が要る
- `docker.sock` mount / n8n からのホスト実行: 境界が消える
- 広い carve-out(`localhost:5678` 全体): 外向きノード経由のトランポリン
- 常駐バックアップ(launchd / n8n 自身のフロー): オプトイン原則。頻度は upgrade 前 + 月次レトロ
- ハーネスの `/schedule` / `/loop` のみで代替: セッション外・外部 SaaS 起点を持たない

## 覆す決定

なし。

## 代償(任意)

- 境界の一部は指示レベル(決定 2)。違反は会話ログと `subagent-log` で事後にしか分からない
- deny は直接コマンドにしか効かず、`bash -c` とスクリプト実行で迂回できる。`Bash(bash -c *)` の deny は日常運用を壊すので不採用
- Private repo が単一障害点。鍵はパスワードマネージャ、dump は Time Machine に依存する

## 影響ファイル

`meta/decisions/{0028-n8n-workflow-engine-boundary.md,README.md}`、`meta/{TODO-for-v0.2.md,glossary.md,CHANGELOG.md}`、`adapters/claude-code/user-level/settings.json.template`(docker の注記 1 行)
