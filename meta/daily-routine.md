# 日常運用ルーチン

朝・夕・週次の定例。月次以上の定例は [`operating-manual.md`](./operating-manual.md) を参照。

無理のない範囲で。「やらない日があってもよい」。続けることが目的。

---

## 朝のセットアップ確認(任意)

5 分以内。気が向いたときだけでよい。

### 手順

```bash
# 1. claude-system の整合性
~/ws/claude-system/tools/doctor.sh

# 2. 直近の CI 状態(push 後)
gh run list --limit 3 --repo u-stem/claude-system

# 3. その日触るプロジェクトに移動して状態確認
cd ~/ws/<today-project>
git status
```

### 確認ポイント

- doctor.sh が clean(error 0、warn が許容範囲)
- CI が直近 green
- プロジェクト側に意図しない変更が残っていない

何か赤い項目があれば、その日の最初のタスクとして対処。

---

## 開発中(自動的に発火するもの)

明示的なオペレーションは不要。以下が裏で動く:

- `permissions.deny`: 危険操作の物理ブロック
- PreToolUse hooks: `--no-verify` / `git push --force` / typosquatting 検出
- PostToolUse hooks: 失敗を `failure-log.jsonl` に集約
- Stop hooks: 未解決 lint/type error を残したまま終了するのを阻止

エラーが連続するときだけ `~/.claude/projects/<scope>/failure-log.jsonl` を眺める。

---

## 退勤前のクリーンアップ(任意)

3 分。

### 手順

```bash
# 1. 触ったプロジェクトの git status 確認
cd ~/ws/<today-project>
git status

# 2. 中途半端なコミットがあれば push か WIP commit
git log --oneline origin/main..HEAD

# 3. failure-log.jsonl を一瞥(任意)
cat ~/.claude/projects/<scope>/failure-log.jsonl 2>/dev/null | tail -10
```

### 確認ポイント

- untracked / unstaged を放置しない(必要なら WIP commit でも残す)
- 翌朝の自分が文脈を思い出せるか

---

## 週次の振り返り(任意)

15 分。週末または金曜の夕方。

### 手順

1. 過去 1 週間の git log 振り返り:
   ```bash
   for repo in claude-system kairous sugara; do
     cd ~/ws/$repo && echo "=== $repo ===" && git log --since '1 week ago' --oneline
   done
   ```
2. 以下を頭の中で整理:
   - 同じ手順を 2 回以上やったか?(skill 化候補)
   - ガードレールが誤検知して進行を妨げたか?(調整候補)
   - 進行中のタスクで blocking なものは?
   - 来週の最優先 1 件は何か?
3. メモが必要なら `meta/retrospectives/<weekly-or-month>.md` に追記(月次レトロと統合してよい)

### スキップ判断

- 週次で書き起こすほどの蓄積がなければ月次に集約してよい
- 「特に何もない週」が続くなら頻度を下げる

---

## バックアップの整理(月 1 程度)

```bash
# 30 日経過したバックアップを削除(migration-* は対象外で永続保管)
~/ws/claude-system/tools/cleanup-backups.sh

# 何が削除されるか先に見る
~/ws/claude-system/tools/cleanup-backups.sh --dry-run
```

---

## ガードレールに引っかかったとき

### 軽微な誤検知

- `.gitleaks.toml` の `allowlist` に追加 → commit
- 該当 hook の例外条件を追加 → commit

### 進行が止まった

```bash
# 一時無効化
~/ws/claude-system/tools/disable-guardrails.sh

# 作業を進める

# 復帰(忘れずに)
~/ws/claude-system/tools/enable-guardrails.sh
```

[operating-manual.md](./operating-manual.md) の「ガードレールが誤検知したときの対処」も参照。

---

## 関連

- [`operating-manual.md`](./operating-manual.md) — 月次・四半期・バージョンアップ手順
- [`retrospectives/_template.md`](./retrospectives/_template.md) — レトロのテンプレート
