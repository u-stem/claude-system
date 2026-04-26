---
name: dependency-review
description: 依存パッケージの追加・更新時のレビュー
recommended_model: sonnet
---

# Dependency Review

`bun add` / `pnpm add` / `npm install` / `uv add` / `cargo add` / `go get` でパッケージを追加・更新するときの専用フロー。
抽象は [`practices/supply-chain-hygiene.md`](~/ws/claude-system/practices/supply-chain-hygiene.md)、機械検出は Phase 7b の `check-package-age.sh`。

## 目的

typosquatting・侵害バージョン・メンテ放棄パッケージを採用前に検出する。Phase 7b の hook(`PACKAGE_MIN_AGE_DAYS=7`)で機械防御するが、そこに頼らず人間レビューも通す。

## いつ発動するか

- 依存パッケージを新規追加するとき
- 既存依存をメジャー / マイナー / パッチ更新するとき
- ロックファイル(`bun.lockb` / `pnpm-lock.yaml` / `package-lock.json` / `uv.lock` / `Cargo.lock` / `go.sum`)が意図せず変わったと PostToolUse hook で通知されたとき
- `bun audit` / `npm audit` で High 以上の指摘が出たとき

## 手順

### 1. パッケージ名の精査

- スペルを 1 文字ずつ確認(typosquatting: `lodash` vs `lodahs` 等)
- 公式ドキュメント / GitHub の README で記載と一致するか
- スコープ付き(`@org/pkg`)とそうでない版が併存するパッケージは注意(`@types/foo` と `foo` は別物)

### 2. レジストリでのメタ情報確認

| レジストリ | 確認項目 |
|------------|----------|
| npm(`https://www.npmjs.com/package/<name>`) | 週間ダウンロード数 / 最終リリース日 / メンテナ / 依存数 |
| PyPI(`https://pypi.org/project/<name>`) | 月間ダウンロード数 / 最終リリース日 / 著者 |
| crates.io(`https://crates.io/crates/<name>`) | All-time downloads / 最終リリース / リバース依存数 |

採用基準:
- 週間ダウンロード 1000 以上(エコシステムに応じて調整)
- 過去 1 年以内にリリース or 安定版でメンテ継続している
- 既知の脆弱性(GitHub Advisory / Snyk)がない

### 3. バージョン固定

- `bun add foo@1.2.3`(`bun add foo` の floating range は使わない)
- 例外: dev tooling で固定が運用負荷を上回る場合のみ、判断理由をコメント
- `package.json` の `^` / `~` プレフィックスを意識(MINOR まで許容するか、PATCH のみか)
- monorepo では `workspace:^` / `workspace:*` を理解した上で使う

### 4. ロックファイル diff レビュー

- `git diff bun.lockb` 等で変更行を確認
- 自分が追加していないパッケージが追加されていないか(transitive dependency の混入確認)
- バージョンが意図したものになっているか
- 不審な hash 変更(同 version で hash が変わる)は侵害の兆候

### 5. 監査コマンド

```bash
bun audit                # bun
npm audit                # npm / pnpm 共用
uv pip audit             # uv(pip-audit を内部で利用)
cargo audit              # cargo(別途インストール)
go list -m all | nancy   # go(nancy を別途インストール)
```

High / Critical が出たら**マージ前に対処**(更新 / 別パッケージへ置換 / 不採用)。

### 6. PreToolUse hook との整合(Phase 7b)

- `PACKAGE_MIN_AGE_DAYS`(既定 7)以内のパッケージは hook で deny
- 例外的に若いパッケージを採用したい場合は環境変数で project ローカルに override(`.claude/settings.local.json` の `env`)、判断理由を README / ADR に記録

### 7. MCP サーバー / プラグイン

- `settings.json.template` の `mcpServers.*.args` でバージョン固定
- 更新は `/update-check` 系 skill で意図的に
- 自動更新を許容しない

## チェックリスト

- [ ] パッケージ名のスペルを 1 文字ずつ確認した(typosquatting でない)
- [ ] レジストリのダウンロード数 / 最終リリース日 / メンテ状況を確認した
- [ ] バージョンを `@x.y.z` で固定して追加した(例外なら理由をコメント)
- [ ] ロックファイル diff を確認、意図しない transitive 追加がないこと
- [ ] `bun audit` / `npm audit` / `pip-audit` で High 以上なし
- [ ] PostToolUse hook(Phase 7b)が「ロックファイル変更」を検出した場合、内容を確認済み
- [ ] PreToolUse hook で deny された場合、理由が「若すぎるパッケージ」と確認、必要ならプロジェクト override

## アンチパターン

- `bun add foo` で floating range のまま放置(いつ何が入るか予測不能)
- パッケージ名を一度入力したら以後コピペで増殖(typo が広がる)
- ロックファイル diff を見ずに `git add .`
- `bun audit` の指摘を「あとで」で放置
- メンテ放棄(2 年以上更新なし)パッケージを「動くから」で採用

## 関連

- [`practices/supply-chain-hygiene.md`](~/ws/claude-system/practices/supply-chain-hygiene.md) — 抽象戦略
- [`adapters/claude-code/user-level/skills/security-audit/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/security-audit/SKILL.md) — 4 軸チェック内の依存関係軸
- [`meta/TODO-for-phase-7b.md`](~/ws/claude-system/meta/TODO-for-phase-7b.md) — `check-package-age.sh` 取り込み計画
