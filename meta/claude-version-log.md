# モデル世代とハーネス版の年表

運用モデルとハーネス(Claude Code)の版を、切り替えた順に 1 行ずつ記録する。判断の根拠は各行の出典(ADR 番号)に置き、ここには事実だけを書く。モデル選択の指針は [`practices/model-selection.md`](../practices/model-selection.md)。

| 日付 | 運用モデル | ハーネス pin | 出典 | メモ |
|------|-----------|-------------|------|------|
| 2026-04-26 | claude-opus-4-7(1M) | — | ADR 0001 / 0002 | 初期構築 Phase 0〜9。xhigh effort、auto mode |
| 2026-05-29 | claude-opus-4-8(1M) | 2.1.156 | ADR 0009 / 0010 | 自律性チューニング。マルチエージェント / 背景実行 / 並列ファンアウト前提 |
| 2026-06-10 | claude-fable-5(1M) | 2.1.170 | ADR 0016 | Fable 5 GA(2026-06-09)。subagent tier は据え置き |
| 2026-07-25 | claude-opus-5[1m] | 2.1.220 | ADR 0022 | Opus 5 へ乗り換え(性能と価格)。effort xhigh が初めて実効化 |
| 2026-08-13 | claude-opus-5[1m] | 2.1.229 | ADR 0026 | ハーネス同期のみ |
| 2026-09-06 | claude-fable-5-1[1m] | 2.1.263 | ADR 0027 | Fable 5.1 GA(2026-09-01)。反証役と最終ゲートの subagent も fable。fallback は claude-opus-5[1m] |

`git log` の author / committer は global git config を継承する設計のため、モデル情報は含まれない。ハーネス pin と実インストール版の差は `tools/check-claude-version.sh` が検出する。
