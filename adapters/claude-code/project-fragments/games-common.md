# ゲーム系プロジェクト共通指針

ゲーム系プロジェクト(2D / 3D、Web / native 問わず)の共通指針。
特定エンジン・特定ライブラリの作法は個別 skill / template で扱う。

## アーキテクチャ

- **描画とロジックを分離**: ゲームロジックは frame rate / 描画手段から独立に動かせる構造に
- **状態管理を 1 箇所に集約**: コンポーネント間で散らばらず、明示的な state(ECS / store / state machine)
- **副作用を境界に追い出す**: 入力 / 描画 / サウンド / 通信は外側、純粋ロジックは内側でテスト可能に
- **deterministic を優先**: 同じ入力で同じ結果が再現できるよう乱数のシード管理、time step を固定

## ゲームループ

- **fixed time step + variable render**: 物理 / ゲームロジックは固定時刻ステップ、描画は可変フレームレート
- 1 frame の処理予算を明示(60 FPS なら 16.6ms 以内)
- 重い処理は分散(1 フレーム内に詰めず、複数フレームに分割)
- pause / resume / accelerate を最初から想定して time 抽象を設計

## アセット管理

- 命名規約を最初に固定(例: `<category>_<name>_<variant>.png`)
- バージョン管理上は最終アセットのみコミット、中間ファイル(.psd / .blend)は別管理
- 容量大きいアセットは Git LFS / 外部ストレージ / CDN
- ロード戦略: 起動時 vs プレイ中 vs オンデマンドを明示
- ホットリロード可能にしておくと反復が早い

## 入力

- 入力イベントを抽象化(キーボード / コントローラ / タッチを共通インタフェース化)
- ボタン押下 / 押し続け / 離した瞬間を区別できる API
- リバインディング(キーマップ変更)を最初から想定
- マルチプラットフォーム対応なら入力方式の差を吸収

## デバッグ / プレイテスト

- frame 時間 / FPS / メモリ / draw call をオーバーレイ表示できるようにする
- リプレイ機能(入力ログ + 初期 state を保存して再現)があるとバグ調査が劇的に楽になる
- チートコード / フリーカメラ / 状態強制設定をデバッグビルドで提供
- バランス変数(ダメージ係数 / スポーン頻度 / 報酬等)はソース直書きせず外部 JSON / YAML / table で管理

## パフォーマンス

- 早すぎる最適化は避けるが、**プロファイラの導入は早期**に
- ボトルネック: draw call / GC / アセット解凍 / 物理計算 / ネットワーク
- 60 FPS が無理なら 30 FPS で割り切る、可変は避ける(プレイヤーが違和感を持つ)

## 推奨 skill / subagent(ゲーム系で頻出)

- 実装時: `typescript-strict`(Web ゲーム)、`rust-style` / `go-style`(native、現状は skeleton)
- レビュー時: `code-reviewer` subagent
- 探索: `explorer` subagent(ゲームコードは大きいことが多く委譲効果大)

## 関連

- [`principles/05-separation-of-concerns.md`](~/ws/claude-system/principles/05-separation-of-concerns.md) — 描画とロジックの分離は関心の分離原則
- [`adapters/claude-code/user-level/skills/typescript-strict/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/typescript-strict/SKILL.md)
