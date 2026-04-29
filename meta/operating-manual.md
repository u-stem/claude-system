# 運用マニュアル

claude-system の継続的な運用手順。日常運用は [`daily-routine.md`](./daily-routine.md) を参照。
本ファイルは「定例外」の運用(月次レトロ・四半期見直し・Claude Code バージョンアップ・廃止判断・誤検知対応)を扱う。

---

## 月次レトロ

毎月末(または翌月初)に実施。10〜15 分。

### 手順

1. `meta/retrospectives/_template.md` をコピーして `meta/retrospectives/YYYY-MM.md` を作成
2. 過去 1 ヶ月の以下を眺める:
   - `~/.claude/projects/<scope>/failure-log.jsonl`(プロジェクト毎に蓄積)
   - 各プロジェクトの `git log --since '1 month ago' --oneline`
   - episodic-memory プラグインで `claude` コマンド検索した会話履歴
3. 以下のテンプレートに沿って書き起こす:
   - `skill 化したいパターン`(同じ手順を 2 回以上やった)
   - `廃止したい skill`(過去 1 ヶ月で起動されなかった、または挙動が悪い)
   - `principles に追加したい原則`(複数文脈で妥当性が確認できた)
   - `ガードレールの誤検知`(発火したが正当な操作だったケース)
   - `次月までに着手する 1 つ`
4. 必要なら ADR 起票(`tools/new-adr.sh` で連番起票)
5. `git commit -m "chore(meta): YYYY-MM retrospective"`

### スキップ判断

- 「特に何もなかった」場合でも空ファイルを作って `## TL;DR\n変化なし` だけ書いて commit する(続けることが目的)

---

## 四半期 principles 見直し

3 ヶ月に 1 回(1 月 / 4 月 / 7 月 / 10 月の月初)。30〜60 分。

### 手順

1. `principles/00-meta.md` 〜 `06-evolution-strategy.md` を順に読み返す
2. 以下を判断:
   - 過去 3 ヶ月のレトロで「principles に追加したい」候補が複数文脈で妥当性確認できたか?
   - 既存原則のうち、もはや実態に合わないものがあるか?
   - 表現が古びている箇所はないか?
3. 改訂が必要なら:
   - **追加・改訂**: ADR 起票 → 該当ファイル改訂 → MAJOR バージョン bump 検討
   - **削除**: ADR 起票必須(なぜ削除するかの根拠を後から辿れるように)
4. `meta/CHANGELOG.md` の `## [Unreleased]` に記録

### 改訂しない判断

- 表現が古びていても、判断材料として現に機能しているなら改訂しない(過剰最適化を避ける)

---

## Claude Code バージョンアップ手順

Claude Code 本体の更新時に適用する。

### トリガー

- `tools/check-claude-version.sh` で diff が出る
- リリースノートに permissions / hooks / skill frontmatter / settings.json スキーマ変更がある
- 既存運用で挙動が変わったと感じる

### 手順

1. リリースノート(Claude Code changelog)を読む
2. [`adapters/claude-code/README.md`](../adapters/claude-code/README.md) の「Claude Code 仕様変更時の影響範囲マップ」を順に点検:
   - `permissions.deny` / `allow` の構文
   - `hooks.<event>` の matcher / フィールド
   - 利用可能な hook event 種別
   - skill / subagent の frontmatter 仕様
   - MCP server 設定スキーマ
   - `enabledPlugins` の挙動
   - env 変数(`CLAUDE_CODE_*`)
3. 影響を受けるファイルを更新
4. `tools/doctor.sh` で整合性確認
5. `meta/CHANGELOG.md` に「Why」を含めて記録
6. `adapters/claude-code/VERSION` を書き換え
7. 破壊的変更なら ADR 起票
8. 1 セッション動作確認してから commit

### 緊急ロールバック

`adapters/claude-code/VERSION` を前のバージョンに戻して revert commit。
ただし Claude Code 本体側のバージョンが変わってしまうとここでは制御できないので、
ローカル npm/brew キャッシュからの roll back は別途実施。

---

## 廃止 skill / subagent の扱い

### 廃止判断のトリガー

- 月次レトロで「廃止したい」に挙がった
- 過去 3 ヶ月で 1 度も起動されなかった
- 上位互換の skill が登場した
- メンテナンス困難(参照元が消えた、依存パッケージが消えた)

### 手順

1. `meta/CHANGELOG.md` に「廃止予定」と記録(1 ヶ月の猶予)
2. 1 ヶ月後、改めて廃止判断:
   - 復活希望がなければ削除
   - 削除前に `git log --follow <path>` で履歴を確認(再導入時に参照できる)
3. 削除後、`tools/doctor.sh` で参照切れがないか確認
4. ADR 起票(削除理由を残す)
5. CHANGELOG に削除完了を記録

### 廃止しない判断

- 「使っていないが将来必要かも」程度なら残す。判断は半年以上の観察を経てから

---

## ガードレールが誤検知したときの対処

### 即時対応

```bash
# hooks を一時無効化
~/ws/claude-system/tools/disable-guardrails.sh

# 作業を進める

# 復帰
~/ws/claude-system/tools/enable-guardrails.sh
```

`disable-guardrails.sh` は `.disabled` 拡張子をリネーム付与する想定(冪等)。

### 根本対応

1. どの hook がなぜ誤検知したかを `failure-log.jsonl` または stderr 出力から特定
2. ケース別:
   - `forbidden-words.txt` の誤検知: 禁止語そのものが過剰なら ADR 起票して削除を検討
   - `pre-bash-guard.sh` の誤検知: 該当パターンを除外する条件を追加(例外用 env 変数で opt-out)
   - `pre-edit-protect.sh` の誤検知: 保護パスに該当するが正当な編集の場合、`*.backup-*` 等のパターン定義を見直す
   - `gitleaks` の偽陽性: `.gitleaks.toml` の `allowlist.regexes` または `paths` に追加
3. 修正したら `tools/doctor.sh` で再確認
4. CHANGELOG に記録

### ガードレールが効かないとき(逆ケース)

- 守るべきところで阻止できなかった場合は重大事象。即 ADR 起票
- 該当 hook / permissions の論理を見直し、テスト的に再現させて修正

---

## hooks のメンテナンス

### 定期点検

- 月次レトロで `failure-log.jsonl` を眺めて、繰り返し失敗パターンが集中しているなら hook 追加検討
- 半年に 1 回、各 hook を `shellcheck` で再点検(`tools/doctor.sh` の一部として常時実行)

### 新規 hook 追加

1. `adapters/claude-code/user-level/hooks/<name>.sh` を作成
2. 設計指針を守る:
   - `#!/usr/bin/env bash` + `set -euo pipefail`
   - 成功時 silent / 失敗時 stderr + exit 2
   - 失敗ログは `${CLAUDE_PROJECT_DIR:-.}/.claude/failure-log.jsonl` に集約
   - macOS BSD コマンド前提、冪等
3. `shellcheck -S warning` で pass
4. `settings.json.template` に hook 結線を追加
5. `tools/doctor.sh` で確認
6. ADR 起票(新たな機械的防御を導入したため)
7. CHANGELOG に記録

### hook の削除・無効化

- 削除前に「過去 3 ヶ月一度も発火していない」かを確認(発火していたなら削除前に発火条件を再評価)
- ADR 起票
- `settings.json.template` から結線を外す
- スクリプト本体は git 履歴に残す(削除コミットで足跡)

---

## projects/ 配下のメンテナンス

`projects/<project>/` は gitignore 対象なので、運用は手動。

### 定期確認

- 半年に 1 回、各プロジェクトの `inventory.md` / `notes.md` が古びていないか確認
- `subagents-overlay/` / `skills-overlay/` で固有のものがあれば、共通化候補(2 プロジェクト以上で同じ → 共通基盤側へ昇格)を検討

### プロジェクトを廃止する場合

1. `tools/unadopt-project.sh <project>` で取り込み撤回(プロジェクト側の `CLAUDE.md` を元に戻す)
2. `~/ws/claude-system/projects/<project>/` を削除(ローカルのみ、リポジトリには元から無い)

---

## CI / GitHub Actions のメンテナンス

| ワークフロー | トリガー | 内容 | 対処 |
|------|------|------|------|
| `doctor.yml` | push, PR | `tools/doctor.sh` 実行 | red になったらローカルで再現 → 修正 |
| `secrets-scan.yml` | push, PR | `gitleaks detect --redact` | red になったら検出箇所を `.gitleaks.toml` の allowlist or 該当ファイル削除 |
| `shellcheck.yml` | push, PR | `shellcheck -S warning` | red になったらローカル `shellcheck` で再現 → 修正 |

### Actions が落ち続ける場合

- main ブランチが赤いまま放置しない
- 即時 fix が困難なら revert で main を緑に戻す → 別ブランチで修正

---

## バックアップ管理

### `~/.claude-system-backups/` の構造

```
~/.claude-system-backups/
├── README.md                            (運用ノート)
├── <project>-CLAUDE.md.<TIMESTAMP>      (adopt 時の CLAUDE.md バックアップ、30 日で自動削除)
├── migration-<TIMESTAMP>/                (Phase 10 切り替え時、永続保管)
│   ├── dot-claude-resolved/             (~/.claude/ が symlink だった場合の中身)
│   └── dot-claude-direct/                (~/.claude/ がディレクトリだった場合の中身)
└── hook-logs/                            (hooks の失敗ログ集計)
```

### 自動掃除

```bash
~/ws/claude-system/tools/cleanup-backups.sh           # 30 日経過分を削除
~/ws/claude-system/tools/cleanup-backups.sh --dry-run # 削除候補を表示のみ
```

`migration-*` は永続保管対象で削除されない(`cleanup-backups.sh` の対象外)。

---

## 関連

- [`daily-routine.md`](./daily-routine.md) — 朝・夕・週次の定例
- [`multi-device-setup.md`](./multi-device-setup.md) — 別マシンへの展開
- [`glossary.md`](./glossary.md) — 用語集
- [`decisions/`](./decisions/) — ADR
