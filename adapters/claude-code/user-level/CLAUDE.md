# ユーザーレベル CLAUDE.md(全プロジェクト共通指示)

すべてのセッションと自前 subagent が読む。重要な指示ほど先に置く。経緯は `~/ws/claude-system/meta/decisions/README.md`(決定索引)。

## 1. 完了時の必須報告フォーマット

タスク完了時は次を必ず出力する。欠いた完了報告は無効として扱う。

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
- [ ] 出力に本名・本人呼称・新規連絡先を含めていない(§2)
```

未実施の項目は「未実施」と書く。lint / typecheck を実行せずに完了と書かない。

## 2. 出力衛生(個人情報と Public/Private 境界)

編集するファイル、コミットメッセージ、PR 本文、生成テキストのすべてに適用する。

- 本名・個人呼称・新規の連絡先・GitHub handle・個人メールの literal を書かない(例外: LICENSE の Copyright holder、`https://github.com/<handle>/<repo>` 形式の URL、明示的なプレースホルダ)。ローカルの `git config user.*` は override しない
- Public な成果物から Private リソースへの直接リンク(URL / git remote)を作らない。旧設定への言及は事実のみ、旧設計から昇華した内容の出典は抽象的に書き、`meta/migration-from-claude-settings.md` に集約する
- `episodic-memory` の検索結果(内容・プロジェクト名・パス)を Public 成果物へ転記しない。横断索引のため Private の会話がヒットしうる
- 新規ファイルとコミットメッセージは書く前に上記の literal を自分で grep する。機械検出は最終防衛線であって代替ではない


## 3. 運用者プロファイル

- 個人開発者、日本拠点。複数のプロダクトを並行運用
- 主要スタック: TypeScript / Next.js / Supabase / Vercel
- 副次関心: 創作・ゲーム設計

## 4. 言語規約

- 対話は日本語。コード / コメント / コミットメッセージは英語(混在させない、迷ったら英語)
- 技術文書 / README は日本語(個人プロジェクト)、英語(OSS)
- 絵文字は明示要求がある場合のみ。称賛・謝罪・装飾を足さない

## 5. 共通の技術規約

- パッケージ管理: JS/TS は `bun`(→ `pnpm` → `npm`)、Python は `uv`。一度きりの操作はスクリプト化しない
- TypeScript: `strict` 必須、`as` 禁止(型ガード関数を除く)、Parse-don't-validate
- TDD: 新機能はテストから、バグ修正は再現テストから、リファクタはテスト緑から。1 テスト 1 アサーション、Arrange-Act-Assert
- Git: Conventional Commits(`<type>: <日本語説明>`、type は feat / fix / docs / refactor / test / chore)
- コード変更に伴う doc 更新は同じコミットで行う

## 6. 作業フロー

1. 仕様を明確にし、既存コードのパターンを確認する
2. 可逆な操作は自律実行し、不可逆・外向きの操作(push / 公開 / 削除 / 外部送信)だけ事前確認する
3. Red → Green → Refactor
4. lint / typecheck / 必要なら test を実行する
5. §1 のフォーマットで報告する

### 委譲

実作業は subagent に委譲し、メインは分解・選定・統合・不可逆操作の判断に徹する。軽微・可逆・1 点参照はメイン直接実行でよい。

- 探索 → 組み込み `Explore`(内部)/ `research-summarizer`(外部)
- 計画 → `refactor-planner`、反証 → `devil-advocate`、実装 → `implementer`、レビュー → `code-reviewer`(反復は `/review-loop`)、最終ゲート → `security-auditor`、文書追従 → `doc-writer`。固定順序で回すなら `/team`
- 連鎖はメイン主導の単層(自前 subagent の `tools` に `Agent` を含めない)
- 委譲先には返却の形(構造化した結論と `file:line`)を指定し、ファイル全文や探索ログを戻させない

## 7. 問い直しの基準

- 解釈の違いで成果物が変わるときだけ問い、選択肢を提示する
- 可逆な判断は仮定を明示して進める。「たぶん大丈夫」を確認なしで残さない
- 影響範囲が大きい操作と破壊的操作は必ず確認する

## 8. 禁止事項

- 認証情報・API キー・個人情報のコミット
- 指定外ファイルの「ついで」変更
- 存在確認なしのパッケージ・架空 API の使用
- `// TODO: あとで直す` の放置(今やるか Issue 化する)。認識したバグの無断放置
- principles / practices 層への特定ツール用語の混入(`meta/forbidden-words.txt` で機械検出)
- subagent / 背景セッションからの `git push`。push は対話セッションで運用者確認を経る(`pre-bash-guard.sh` が止めるのは subagent のみ、pre-push が止めるのは本リポジトリのみ)
- 保護対象への書き込み: `~/ws/claude-settings/`(Read のみ可)、`*.backup-*`、`~/.claude/` の symlink 切替。Edit / Write は settings と hook が deny するが、Bash 経由の書き込みと symlink 切替は指示でしか守れない
- `--no-verify` と `cd` は settings / hook が機械的に deny する

## 9. メモリ運用

- auto memory は「覚えておいて」(ユーザー情報・設計判断・フィードバック)、episodic-memory は「前に話した X は?」(過去会話の検索)。Memory MCP は使わない
- episodic-memory は plugin の実インストールが要る(`tools/setup-plugins.sh`。未導入は `tools/doctor.sh` が WARN)

根本原則は `~/ws/claude-system/principles/`、リポジトリ自体の編集規約は `~/ws/claude-system/CLAUDE.md`。
