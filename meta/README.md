# meta

このリポジトリ自体に関するメタ情報を格納する。

## 履歴 / 索引

| ファイル | 内容 |
|----------|------|
| `CHANGELOG.md` | 変更履歴(全 Phase の完了報告を時系列で集約) |
| `claude-version-log.md` | 利用 Claude モデルの履歴 |
| `migration-from-claude-settings.md` | 旧 claude-settings からの移行記録 |
| `migration-inventory.md` | Phase 0.5 で実施した旧資産の取り込み判断台帳 |
| `glossary.md` | 用語集(層 / 抽象 / Claude Code 関連 / 運用 / ガードレール / メモリ) |
| `forbidden-words.txt` | principles / practices に混入してはならない語(機械検出の唯一の真実源) |
| `integration-trace.md` | Phase 9 で実施した統合テストシミュレーション(セッション起動時のロード対象を整理) |

## 運用ドキュメント

| ファイル | 内容 |
|----------|------|
| `operating-manual.md` | 月次レトロ / 四半期 principles 見直し / Claude Code バージョンアップ / 廃止判断 / hooks メンテナンスの手順 |
| `daily-routine.md` | 朝・退勤前・週次の定例 |
| `multi-device-setup.md` | 別 macOS マシンへの展開手順(chezmoi 連携含む) |

## TODO

| ファイル | 内容 |
|----------|------|
| `TODO-for-v0.2.md` | Phase 9 で消化しきれなかった項目 / v0.2 以降に持ち越した検討事項 |

過去の Phase 別 TODO ファイル(`TODO-for-phase-N.md`)は当該 Phase の完了とともに retire 済み。経緯は `git log` で追える。

## サブディレクトリ

| ディレクトリ | 内容 |
|----------|------|
| `decisions/` | 設計決定記録(ADR)。連番ルールと運用は [`decisions/README.md`](./decisions/README.md) を参照 |
| `retrospectives/` | 月次・四半期の振り返り記録。テンプレートは [`retrospectives/_template.md`](./retrospectives/_template.md) |

## 関連

- ルート [`README.md`](../README.md) — システム概要
- ルート [`CLAUDE.md`](../CLAUDE.md) — claude-system 自身の編集者向け指示
- [`adapters/claude-code/user-level/CLAUDE.md`](../adapters/claude-code/user-level/CLAUDE.md) — 全プロジェクト共通の利用者向け指示
