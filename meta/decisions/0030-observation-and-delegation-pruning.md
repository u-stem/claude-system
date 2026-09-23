# ADR 0030: 観測と委譲の剪定(doctor の SessionStart 移行・refactor-planner 廃止・ロールバック経路の退役)

- **Status**: Accepted
- **Date**: 2026-09-23
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## 決定

1. Stop 毎ターンの `doctor.sh --fast` を SessionStart 1 回に移し、前回結果の WARN / ERROR 行を SessionStart の stdout(文脈)へ注入する。hook は `session-start-doctor.sh`、`stop-session-doctor.sh` は撤去
2. `refactor-planner` subagent を廃止し、計画役を組み込み `Plan` に。委譲チェーンは 探索(`Explore`)→計画(`Plan`)→反証→実装→レビュー→最終ゲート→文書追従。`doc-writer` は 2026-12 の `/skill-doctor` 判定と同時に再評価
3. ロールバック経路を退役: `tools/migrate/{from-claude-settings,rollback-from-claude-system}.sh` を削除し、復元元 `~/.claude-system-backups/migration-20260504-162515/`(1.4 GB)を廃棄。最後の安全網は旧 `~/ws/claude-settings/`(Read 専用)+ `tools/setup.sh`
4. 同時に行った注記(決定ではない): テスト 4 本の実ログ汚染修正、`agent_def` の記録と重複除去、failure-log の `probe` 区分(集計側)、`subagent-stop-audit` の誤検知修正、settings バックアップの 5 本回転、CLAUDE.md 2 本の縮約とコミット言語の日本語説明への統一、矛盾 3 件の修正

## 根拠

- `last-doctor.log` に読み手が無く毎ターン約 1 秒・150 fork・betterleaks 走査(`meta/CHANGELOG.md` 2026-09-23)
- 使用実績: refactor-planner 全期間 1 回・直近 30 日 0、組み込み Plan 19 回、`subagent-log.jsonl` を meta.json の定義名で解決。meta.json 無し 49 件は解決不能(残余不確実性)(同 CHANGELOG)
- 切替(2026-05-04)から 4.5 か月無事故、旧設定ディレクトリが残存(`tools/migrate/README.md`)

## 再評価トリガー

SessionStart 注入が拾えなかった drift が実害になったとき(Stop 側の軽量検知を再検討)/ `doc-writer` の 2026-12 判定 / 別マシン導入で rollback 相当が要るとき(`tools/setup.sh` の再実行で足りるか検証)

## 不採用と理由

- mtime 間引き: 読み手不在は変わらない
- `pre-bash-guard` の `[[ =~ ]]` 化: 多行コマンドで `^` の意味が変わり deny を取りこぼす(既存テストは単行のみ)
- doctor の検査を tests スクリプト呼び出しへ委譲: fork 増、未計測
- CLAUDE.md の大幅縮約: 安定 prefix はキャッシュ読みで実効 1/10、規則脱落のリスクが上回る
- superpowers 撤去: 5 skill 現役
- rework hook 撤去: 2026-10 判断を待つ
- 凍結記録のアーカイブ: コンテキストに載らない
- `doc-writer` 同時廃止: 5 回、判定は 2026-12 に揃える
- 探索ノイズを記録側で落とす: `grep -q && next` のスキップ事実や `test -f` 失敗を失う

## 覆す決定

索引「ガードレール」の doctor 2 ティア行(0024: fast は毎ターン Stop hook)、索引「委譲とモデル」の単層連鎖行(0027 / 0022 / 0015: 計画→refactor-planner)。ADR 0025 L50 の「移行複製は永続保管」は索引行の注記で上書きする。旧 ADR は編集しない。

## 影響ファイル

`adapters/claude-code/user-level/{CLAUDE.md,settings.json.template,hooks/,commands/}`、`adapters/claude-code/subagents/`、`adapters/claude-code/project-templates/`、`adapters/claude-code/project-fragments/`、`CLAUDE.md`、`README.md`、`tools/{migrate/,cleanup-backups.sh,sync-settings.sh,loop-report.sh,unadopt-project.sh,_lib.sh}`、`tests/`、`.github/workflows/.gitkeep`、`meta/{decisions/README.md,CHANGELOG.md,TODO-for-v0.2.md}`
