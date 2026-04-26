---
name: project-tech-stack-decision
description: 新規プロジェクトの技術スタックを選定する
recommended_model: opus
---

# Project Tech Stack Decision

新規プロジェクトの技術スタック選定を、要件言語化 → 候補列挙 → 比較 → 選定 → ADR 化の流れで支援する skill。
原子性とアーキテクチャ判断を要するため `recommended_model: opus`。
根拠抽象は [`practices/project-bootstrap.md`](~/ws/claude-system/practices/project-bootstrap.md)、判断軸の構造は [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) を参照。

## 目的

新規プロジェクト立ち上げ時の技術スタック選定をサポートし、「テンプレートにあるから選ぶ」「主要スタックだから選ぶ」という形骸化を防ぐ。
選定理由を ADR に残し、後から「なぜこのスタックを選んだか」を辿れる状態にする。

## いつ発動するか

- 新規プロジェクトのアイデアが出たとき(ハッカソン規模を含む)
- 既存プロジェクトの大規模リプラットフォーム検討時
- **「とりあえず Next.js で」と無意識に選びそうになった時**(これが最重要トリガー)
- 既存テンプレートをコピーする直前(コピー前にこの skill を通す)

逆に、既存プロジェクト内の機能追加・小規模実験・PoC では発動しない。

## 手順

### ステップ 1: 要件の言語化

以下を 5 項目以上で書き出す。曖昧なまま進めない。

- **目的**: 何を解決するか / 誰が使うか
- **想定規模**: 個人 / 小規模チーム / 大規模(同時接続数・データ量の桁感を含む)
- **想定寿命**: ハッカソン(数日)/ 数ヶ月 / 数年
- **制約**: 予算、運用コスト、ホスティング場所(自社 / Cloud / Edge)、既存資産
- **主要な非機能要件**: レイテンシ、スループット、可用性、データ量、セキュリティ要件

要件が曖昧なら無理に進めず、ユーザに問い直す([`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) の「未検証の仮定を残さない」)。

### ステップ 2: 候補スタック列挙

候補を網羅的に出す。1 つだけで決め打ちしない。**最低 3 候補**。
領域別チェックリスト:

| 領域 | 候補例 |
|------|--------|
| Web フロント | Next.js / Astro / Remix / SvelteKit / Vue + Nuxt / SolidStart / Hono + JSX / 静的 HTML |
| バックエンド | Supabase / Hono + D1 / Bun + Postgres / Convex / Express / Fastify / 自前 |
| モバイル | React Native + Expo / Flutter / SwiftUI / Tauri Mobile / Capacitor |
| ゲーム(Web) | PixiJS / Phaser / Three.js / Babylon.js |
| ゲーム(ネイティブ) | Godot / Unity / Bevy(Rust)|
| デスクトップ | Tauri / Electron / native(Swift / Kotlin)|
| 板ゲー | 物理プロトタイプ / Tabletopia / Tabletop Simulator / 自前デジタル化 |
| データ・CLI | Python + uv / Rust + clap / Go + cobra / Bun script |

このリストはあくまで起点。プロジェクト要件によっては別の領域(IoT / 組込 / ML 推論等)を追加する。

### ステップ 3: 候補の絞り込み

各候補に対して 2-3 行で評価。比較軸:

- **学習コスト**: 既存知識との距離
- **運用コスト**: ホスティング・モニタリング・スケーリングの手間
- **エコシステム成熟度**: ライブラリ・ドキュメント・コミュニティの厚み
- **過去経験**: ユーザの実戦経験の有無(`~/ws/claude-system/projects/` で実プロジェクト履歴を確認)
- **プロジェクト要件適合度**: ステップ 1 の要件をどれだけ満たすか
- **撤退コスト**: 後で別スタックに乗り換える際の痛み

評価後、**上位 2-3 候補に絞る**。トレードオフを明文化する。

### ステップ 4: 最終選定と理由の言語化

以下を文章にする:

- **選んだスタック**(具体名 + バージョン目安)
- **選定理由**: 要件のうち何を最優先したか
- **不採用にした候補**: なぜ他候補を選ばなかったか(各候補ごとに 1-2 行)
- **想定リスクと回避策**: 選んだスタックの弱点と、それが顕在化した時の対策

「主要スタックだから」「テンプレートにあるから」だけを理由にしない。

### ステップ 5: ADR の起票

[`adr-writing`](~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md) skill を呼び出し、プロジェクト側の `docs/adr/0001-tech-stack.md` として記録する。

- **Status**: `Accepted`(議論を残したい場合のみ `Proposed`)
- **Context**: ステップ 1 の要件
- **Decision**: ステップ 4 の選定結果
- **Alternatives Considered**: ステップ 3 で評価した他候補と不採用理由
- **Consequences**: Positive / Negative / Neutral

プロジェクト初期化前なら、後から `docs/adr/` を作成して 0001 として配置する。

## チェックリスト

- [ ] 要件を **5 項目以上**で言語化したか(目的・規模・寿命・制約・非機能要件)
- [ ] 候補を **3 つ以上**列挙したか(1 つだけで決め打ちしていない)
- [ ] 各候補のトレードオフを 2-3 行で評価したか
- [ ] 「主要スタックだから」「テンプレートにあるから」だけで選んでいないか
- [ ] 上位 2-3 候補に絞り込んだか
- [ ] 不採用候補の理由を文章化したか
- [ ] 想定リスクと回避策を書いたか
- [ ] ADR(`docs/adr/0001-tech-stack.md`)として記録したか

## アンチパターン

- 候補列挙をスキップして即決する(Next.js しか考えない / 慣れているから即決)
- ADR を書かず口頭判断や記憶のみで進める(後で「なぜこれを選んだか」が辿れない)
- 「とりあえず慣れてるから」だけで選ぶ(要件適合度の検証なし)
- `~/ws/claude-system/adapters/claude-code/project-templates/` 配下の 3 つのテンプレートに思考を制約する(あくまで一例)
- 要件が曖昧なまま選定を進める(後から要件が固まった時に手戻り)
- 「上位モデルなら正しく選べる」と過信する(モデルの推奨は判断材料の 1 つ、決定責任はユーザ側)

## 関連

- [`practices/project-bootstrap.md`](~/ws/claude-system/practices/project-bootstrap.md) — 立ち上げ手順の抽象、層構造の運用
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — 候補比較の構造的類似(複雑度ベース判断)
- [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) — 意思決定記録の根拠原則
- [`principles/06-evolution-strategy.md`](~/ws/claude-system/principles/06-evolution-strategy.md) — 不変層への依存を一方向に保つ、固定銘柄ルールを書かない
- [`adapters/claude-code/user-level/skills/adr-writing/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md) — ADR 起票手順(ステップ 5 で連動)
- [`adapters/claude-code/project-templates/_README.md`](~/ws/claude-system/adapters/claude-code/project-templates/_README.md) — テンプレート一覧と成熟度(候補比較時に参照)
- `~/ws/claude-system/tools/new-project.sh`(Phase 7a で作成予定)— 本 skill との連携設計、選定後の初期化を担う
