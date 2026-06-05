# ADR 0014: Tool-Call Parse-Error Resilience

- **Status**: Accepted(層 A 実装済み / 層 B は Deferred)
- **Date**: 2026-06-05
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

`The model's tool call could not be parsed (retry also failed).` でアシスタントのターンが中断する事象が、実作業中に頻発している(依存更新・PR マージ等のツール呼び出しが密なタスクで顕著)。運用者から「完全に防げないか」「サブエージェントで sonnet/effort を下げる構図で緩和できないか」「止まった後に自動回復できないか」という三点の要望が出た。

調査(WebFetch による一次情報確認)で判明した事実:

- **上流(モデル配信側)のバグ**である。モデルが `stop_reason: tool_use` を返すのに本体に `tool_use` ブロックが無く、自動リトライも失敗するとターンが中断する。GitHub Issue [anthropics/claude-code#61133](https://github.com/anthropics/claude-code/issues/61133) のプロトバフ解析で、特定の内部配信版へのロールアウト時刻と発生開始が一致することが示されている([#63875](https://github.com/anthropics/claude-code/issues/63875) で `bug` / `area:model` / `duplicate` として triage 済み)。
- 誘発条件は **1M context の高占有 + 強い extended thinking + ツール呼び出し**の相互作用。同期間に Sonnet 系は当該失敗 0 件。
- **クライアント設定で根絶する手段は構造的に存在しない**。修正はサーバー側モデルサービングの差し替えで静かに行われる類で、外から進捗は追いにくい。

回復可能性の調査結果(公式 hooks ドキュメント記述ベース):

- このエラーは **API error 扱い**で、`Stop` フックは発火しない(`Stop` は正常終了時のみ。"API errors fire `StopFailure` instead")。
- 代わりに **`StopFailure` フックが発火するが、その出力と exit code は無視される**。よって `block`+`reason` による continue 注入は不可。**セッション内(in-band)での自動回復は不可能**と確定。
- `Notification` フックの matcher(`permission_prompt` / `idle_prompt` / `auth_*` 等)もこのエラー型を拾わない。

cmux(運用中のランナー)側の調査結果:

- 公式に watchdog / 出力監視トリガー機能は無い。
- ただし CLI(`cmux read-screen` で画面取得、`cmux send` / `send-key` で打鍵送出)が揃っており、**外部ポーリングで「文字列検知 → 続行送出」を自作可能**。制約として `read-screen` はフォアグラウンドでのみ安定(背景/スリープで失敗する既知 Issue あり)。

## Decision

parse-error abort を「**根絶できない上流事象**」と前提し、(1) 発生確率を下げる、(2) 発生を即時に可視化する、(3) 自動継続は条件付きに留める、の三本立てで対処する。

### 層 0(予防): 機械タスクを丈夫な経路へルーティングする

ツール密・低推論のタスク(依存更新・PR マージ・audit・列挙・整形)は、誘発条件(Opus 1M + 強 thinking)から外す。

- メインごと **Sonnet / 低 effort** で回す、または機械作業の塊を **`model: sonnet` のサブエージェントに委譲**する。
- これは新規方針ではなく **[ADR 0013](0013-role-based-effort-modulation.md)(ロール別 effort = 委譲 + model 選択)** の適用であり、本 ADR はそこに「parse-error 緩和」という動機を一本足す位置づけ。
- 既存の早期圧縮(`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70`、[ADR 0010](0010-opus-48-harness-settings-sync.md))も予防に寄与する。確率を下げるだけで保証ではない。

### 層 A(検知 / 採用): `StopFailure` 通知フック

`StopFailure` は出力が無視されるため制御には使えないが、**コマンド自体は実行される**ので副作用(通知)は有効。これを用いて「気づいたら止まっていた」を「止まった瞬間に通知が来る」に変える。

- フック: `adapters/claude-code/user-level/hooks/notify-stop-failure.sh`(macOS `osascript` でデスクトップ通知 + 音、非 macOS はログのみにフェイルオープン)。
- 配線: `settings.json.template` および live `~/.claude/settings.json` の `StopFailure` 枠。
- 副作用のみ・<1s・フェイルオープンというフック契約を厳守。

### 層 B(自動継続): cmux watchdog(Deferred)

外部ポーリングで該当文字列を検知し続行を送出する自動継続は **技術的に可能だが本 ADR では採用保留**。理由:

- **不可逆・外向き操作の途中**で中断した場合、状態未確認のまま continue を送ると半端な状態を悪化させ得る([ADR 0009](0009-opus-48-autonomy-tuning.md) の「不可逆操作は事前確認」と衝突)。
- `read-screen` のフォアグラウンド制約で運用が不安定。

採用するなら必須ガード: ①送出文言を「直前操作の成否を確認してから再開」固定、②連続再開回数の上限(例 3 回で人間に戻す)、③フォアグラウンド前提。層 A の運用実績を見てから再評価する。

## Consequences

- **得るもの**: 中断の即時可視化(張り付きコスト削減)、予防ルーティングの明文化、回復可能性の確定的な結論(in-band 不可)を記録として固定。
- **割り切り**: 発生自体はゼロにできない。上流修正はリリース待ちで、こちらは緩和と可視化に徹する。
- **将来の再評価トリガー**: 上流での恒久修正、ハーネスが `StopFailure` で制御出力を honor するようになった場合、または層 B の必要性が層 A の運用で裏付けられた場合。

## アンチパターン

- 「設定で完全に防げる」と称して根絶を約束する(原因が上流のため不可能)。
- `Stop` フックで自動回復を試みる(当該エラーでは発火しない。`StopFailure` も出力無視で制御不可)。
- 状態未確認のまま無制限に auto-continue を送る(不可逆操作を悪化させる)。

## 関連

- [ADR 0009](0009-opus-48-autonomy-tuning.md) — 不可逆操作の事前確認(層 B のガード根拠)
- [ADR 0010](0010-opus-48-harness-settings-sync.md) — autocompact 早期化(予防)
- [ADR 0013](0013-role-based-effort-modulation.md) — ロール別 effort = 委譲 + model 選択(層 0)
- [principles/02-decision-recording.md](../../principles/02-decision-recording.md) — 検証されていない仮定を残さない
- auto memory `avoid-tool-call-parse-errors` — 日々の振る舞いレベルの緩和策
