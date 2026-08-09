# ユーザーレベル CLAUDE.md(全プロジェクト共通指示)

このファイルは `~/.claude/CLAUDE.md` にシンボリックリンクされており、すべてのセッションで読み込まれる。
重要な指示ほど先に置く。

---

## 1. 完了時の必須報告フォーマット

すべてのタスク完了時、以下を必ず出力すること。**このフォーマットを欠いた完了報告は無効**として扱う。

```
## 完了報告

### 作業範囲
- 編集したファイル: <list>
- 編集していない関連ファイル: <list>

### 検証結果
- [ ] lint: <output 抜粋 or N/A>
- [ ] typecheck: <output 抜粋 or N/A>
- [ ] test: <output 抜粋 or N/A>

### 自己確認
- [ ] 指定範囲外のファイルを「ついで」で編集していない(`git diff --stat` で確認)
- [ ] 機密情報をコミット対象に含めていない
- [ ] 保護対象(`~/ws/claude-settings/`、`*.backup-*`、`~/.claude/` の symlink 切替)に書き込んでいない
- [ ] 出力に本名・本人呼称・新規連絡先を含めていない(後述「出力衛生」参照)
```

未完了項目があるときは正直に "未実施" と明記する。型チェックや lint を**実行せずに**完了と書かない。

## 2. 出力衛生(個人情報・Public/Private 境界)

`meta/decisions/0001-anonymity-policy.md` および `0002-public-private-boundary.md` で確定した方針を、すべての出力(編集するファイル、コミットメッセージ、PR 本文、AI 生成テキスト)に常時適用する。

### 識別子レイヤ(ADR 0001 由来)

| 識別子 | 取り扱い |
|--------|----------|
| 本名・個人呼称 | **不許可**。リポジトリ内のいかなるファイル・コミットメッセージ・コード片にも含めない |
| GitHub handle | **literal は不許可**(ADR 0006)。例外: ① LICENSE Copyright holder ② `https://github.com/<handle>/<repo>` 形式の URL に含まれる自動参照 ③ 手順書中の `<your-handle>` のような明示的プレースホルダ |
| Personal email | **literal を書かない**(ADR 0006)。commit author は global `git config` で自動付与され、リポジトリ内ファイルに literal を書く必然性はない |
| 新規の連絡先・住所・電話番号 | **不許可** |

新規ファイル / 新規コミットメッセージ作成前に、本名・呼称・自分の handle / email が literal で混入していないか自己 grep で確認する(機械検出は `gitleaks` / forbidden-words / hooks で多層化済み)。**ローカル `git config` の `user.name` / `user.email` を override しない**(global を継承する設計)。

### 情報源レイヤ(ADR 0002 由来)

- Public な claude-system の出力から **Private リソースへの直接リンク**(URL / git remote)を作らない
- 旧設定の存在に言及するときは「別途 Private リポジトリにて永続保管」のような**事実のみ**にとどめ、URL / 具体名を書かない
- 旧設計から昇華した内容を新システム側で書くときは、出典は抽象的記述に留め、ローカルパス参照は最小限にする
- 旧設定との関係を語る記述は `meta/migration-from-claude-settings.md` 1 ファイルに集約する
- **`episodic-memory` の検索結果を Public 成果物へ転記しない**。同プラグインは全プロジェクト横断で会話を索引するため(除外設定なし)、Private プロジェクトの会話本文が検索でヒットしうる。検索は判断の材料として使ってよいが、ヒットした内容・プロジェクト名・パスを Public リポジトリのファイル / コミットメッセージ / PR 本文へ写さない([ADR 0023](../../../meta/decisions/0023-harness-sync-2.1.226.md) §4b)

## 3. 運用者プロファイル

- 個人開発者、日本拠点
- 複数のプロダクトを並行運用
- 主要スタック: TypeScript / Next.js / Supabase / Vercel(パッケージ管理は §5 に集約)
- 副次関心: 創作・ゲーム設計

## 4. 言語規約

- 対話: **日本語**
- コード / コメント / コミットメッセージ: **英語**(コード内で日英混在させない、迷ったら英語)
- 技術文書 / README: 日本語(個人プロジェクト)/ 英語(OSS)
- 絵文字禁止(明示要求がある場合のみ)
- 過剰な装飾・太字・称賛・謝罪を避ける

## 5. 共通の技術規約

- パッケージ管理: JS/TS は `bun` を最優先(→ `pnpm` → `npm`)、Python は `uv`
- 一度きりの操作はスクリプト化しない
- TypeScript: `strict` 必須、`as` 禁止(型ガード関数を除く)、Parse-don't-validate
- TDD: 新機能はテストから、バグ修正は再現テストから、リファクタはテスト緑から。1 テスト 1 アサーション、Arrange-Act-Assert
- Git: Conventional Commits(`<type>: <日本語説明>`、type は英語: feat / fix / docs / refactor / test / chore)、認証情報・API キーはコミットしない
- ドキュメント更新: コード変更時は同じコミットで関連 doc を更新する。後回しにしない

## 6. 作業フロー

1. 仕様を明確にし、既存コードのパターンを確認
2. リスクが高い操作のみ事前確認を取る(Opus 4.8 期に確立し Fable 5 期も継続: 自律判断を尊重し確認プロンプトを抑制。可逆操作は自律実行、不可逆・外向き操作のみ事前確認。詳細は [`meta/decisions/0009-opus-48-autonomy-tuning.md`](../../../meta/decisions/0009-opus-48-autonomy-tuning.md) / [`0016-fable-5-harness-settings-sync.md`](../../../meta/decisions/0016-fable-5-harness-settings-sync.md))
3. Red → Green → Refactor
4. lint / typecheck / 必要なら test を実行
5. 上記「完了時の必須報告フォーマット」で報告

### 委譲ファースト(チーム連鎖)

実作業は**原則として対応する subagent に委譲**し、メインは分解・選定・統合・不可逆操作の判断に徹する([ADR 0015](../../../meta/decisions/0015-delegation-chain-and-mandatory-delegation.md) / [`practices/delegation-orchestration.md`](../../../practices/delegation-orchestration.md))。

- 探索 → `explorer`(内部)/ `research-summarizer`(外部)
- 計画 → `refactor-planner`、反証 → `devil-advocate`、実装 → `implementer`、レビュー → `code-reviewer`(反復は `/review-loop`)、最終ゲート → `security-auditor`、文書追従 → `doc-writer`
- 連鎖は**メイン主導の単層**(運用規約。ハーネスは v2.1.219 以降ネスト委譲を depth 3 まで許容するが、観測可能性と統制のため単層を維持する / ADR 0022)。固定順序で回すなら `/team` command を使う。
- **例外**: 軽微・可逆・1 点参照はメイン直接実行でよい(委譲の固定費が利得を上回るため。機械的に全作業を委譲しない)。

## 7. 「困ったら問い直す」

- 仕様が曖昧 → 問い返す
- 解釈が複数ある → 選択肢を提示
- 影響範囲が大きい / 破壊的操作 → 必ず確認を取る
- 「たぶん大丈夫」を確認なしで残さない([`principles/02-decision-recording.md`](../../../principles/02-decision-recording.md))

## 8. 禁止事項

- 認証情報・API キー・個人情報のコミット
- `~/ws/claude-settings/` への書き込み(アーカイブ、Read のみ可)
- `*.backup-*` への書き込み
- 指定外ファイルの「ついで」変更
- 存在確認なしのパッケージ・架空 API の使用
- `// TODO: あとで直す` の放置(今やるか Issue 化する)
- バグを認識しながら無断で放置する
- `--no-verify` の付与(settings.json で deny 済み)
- **subagent / バックグラウンドセッションからの `git push`**。ハーネス既定は v2.1.221 以降「作業保全のため commit して push する」だが、本システムでは **commit までに留める**。push は対話セッションで運用者の確認を経て行う(背景セッションには確認相手がいないため §6-2 の「事前確認」が成立しない。ローカルに commit してあれば作業は失われない)。**この規約は指示だけでは効かないことが実証済みのため `pre-bash-guard.sh` が機械的に deny する**(subagent の PreToolUse payload にのみ現れる `agent_type` で判定 / [ADR 0023](../../../meta/decisions/0023-harness-sync-2.1.226.md) §8)
- principles / practices 層への特定ツール用語の混入(`meta/forbidden-words.txt` で機械検出)

## 9. メモリ運用

- **auto memory**: ユーザー情報・設計判断・フィードバック等、明示的に記録すべき知識
- **episodic-memory**: 過去会話の自動インデックス + セマンティック検索
- 「覚えておいて」と言われたら auto memory、「前に話した X は?」は episodic-memory
- `Memory MCP` は採用しない(2 層に統一)
- episodic-memory は**プラグインの実インストールが必要**(`settings.json` の `enabledPlugins` は宣言にすぎない)。新規マシンでは `tools/setup-plugins.sh` を実行する。未導入なら `tools/doctor.sh` が WARN する([ADR 0023](../../../meta/decisions/0023-harness-sync-2.1.226.md))
- アーキテクチャの確定版は [`meta/decisions/0003-memory-architecture.md`](../../../meta/decisions/0003-memory-architecture.md) を参照

## 10. 思想的背景と関連参照

すべての指示は [`~/ws/claude-system/principles/`](../../../principles/) 配下の根本原則に基づく。判断のブレが生じたら principles を読み返す。
リポジトリ自体の編集ルールは [`~/ws/claude-system/CLAUDE.md`](../../../CLAUDE.md)、ADR は [`0001-anonymity-policy`](../../../meta/decisions/0001-anonymity-policy.md) / [`0002-public-private-boundary`](../../../meta/decisions/0002-public-private-boundary.md) を参照。
