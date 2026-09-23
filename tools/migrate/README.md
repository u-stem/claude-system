# tools/migrate/

2026-05-04 の切替に使った `from-claude-settings.sh` と `rollback-from-claude-system.sh` は 2026-09-23 に退役(ADR 0030)。切替から 4.5 か月無事故で、復元元の複製も廃棄した。最後の安全網は旧 `~/ws/claude-settings/`(Read 専用)と `tools/setup.sh` の再実行。将来のハーネス移行スクリプトはここに置く(命名規則は定めない)。
