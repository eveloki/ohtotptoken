# 云备份写入守护与备份失败可见性（未发布）

> 实现记录，不代表已发布或已通过真机验收。版本号未在本变更中调整。

## 简体中文

- 新增备份发布后一致性校验：备份发布到云端正式目录后立即重读该文件，校验备份头中的令牌数量与设备标识与本机快照一致；校验不通过判定本次备份失败，自动清理无效文件并随同步传播删除，不再更新"最近成功备份"时间。该守护确保"云端正式目录里的每个备份都完整可解析且与当前数据一致"，杜绝 0 字节损坏备份再次静默产生。
- 写入链路错误零容忍：暂存、加密、写入、关闭、回读校验、发布、发布后校验、同步提交任何阶段失败都使本次备份整体失败，正式目录不留半成品。
- 备份失败持久可见：华为云备份详情页新增"最近一次备份"失败状态行，展示失败阶段与原因，并提供"备份失败，请反馈开发者"问题反馈入口；失败状态在下次备份成功前持续保留，应用重启后仍可见。
- 备份轮换与清理归属守护：每设备 5 份轮换剪除只统计校验通过的本机备份，无法读取的记录（如历史事故残留）不再影响轮换判定；"清除本设备/同名设备云端备份"不再因存在来源不明的记录而整体失败，会跳过这些记录并明确提示保留数量。
- 云备份历史新增"来源未确认"记录的批量清理入口：逐条删除、二次确认，失败的条目保留并列出，便于清理历史遗留的无法识别记录。
- 图标包云备份发布改为暂存+校验+原子替换：发布失败或中断时云端既有的图标包备份保持完整可恢复，不再可能被截断损坏；目录收集失败的文件如实计入恢复结果，不再静默缺文件仍报成功。

## 繁體中文

- 新增備份發布後一致性校驗：備份發佈到雲端正式目錄後立即重讀該檔案，校驗備份標頭中的權杖數量與裝置識別與本機快照一致；校驗未通過判定本次備份失敗，自動清理無效檔案並隨同步傳播刪除，不再更新「最近成功備份」時間。該守護確保「雲端正式目錄裡的每個備份都完整可解析且與當前資料一致」，杜絕 0 位元組損壞備份再次靜默產生。
- 寫入鏈路錯誤零容忍：暫存、加密、寫入、關閉、回讀校驗、發佈、發布後校驗、同步提交任何階段失敗都使本次備份整體失敗，正式目錄不留半成品。
- 備份失敗持久可見：華為雲備份詳情頁新增「最近一次備份」失敗狀態列，顯示失敗階段與原因，並提供「備份失敗，請回報開發者」問題回饋入口；失敗狀態在下一次備份成功前持續保留，應用重啟後仍可見。
- 備份輪換與清理歸屬守護：每裝置 5 份輪換剪除只統計校驗通過的本機備份，無法讀取的記錄（如歷史事故殘留）不再影響輪換判定；「清除本裝置/同名裝置雲端備份」不再因存在來源不明的記錄而整體失敗，會跳過這些記錄並明確提示保留數量。
- 雲端備份歷史新增「來源未確認」記錄的批次清理入口：逐條刪除、二次確認，失敗的項目保留並列出，便於清理歷史遺留的無法識別記錄。
- 圖示包雲端備份發佈改為暫存+校驗+原子替換：發佈失敗或中斷時雲端既有的圖示包備份保持完整可還原，不再可能被截斷損壞；目錄收集失敗的檔案如實計入還原結果，不再靜默缺檔案仍報成功。

## English

- Add post-publish backup verification: after a backup is published to the cloud directory, the published file is re-read immediately and its header token count and device identifier are compared against the snapshot taken when the backup started. A failed check marks the backup as failed, removes the invalid file, and propagates the deletion through sync — the "last successful backup" time is not updated. This guard ensures every backup in the cloud directory is fully parseable and consistent with current data, preventing silent zero-byte corruption from recurring.
- Zero tolerance for write-pipeline errors: a failure at any stage (staging, encryption, write, close, read-back verification, publish, post-publish verification, sync submission) fails the entire backup and leaves no partial artifact under an official name.
- Persistent backup-failure visibility: the Huawei Cloud backup details page now shows a "last backup" failure row with the failing stage and reason, plus a "Backup failed — please report this" feedback entry. The failure state persists across restarts until the next successful backup clears it.
- Rotation and cleanup ownership guards: the per-device five-backup rotation only counts verified backups from this device; unreadable records (such as legacy incident leftovers) no longer affect rotation. "Clear this device / same-name device cloud backups" no longer fails entirely when records with unverified ownership exist — they are skipped and the kept count is reported.
- Add a bulk cleanup entry for "source unverified" records in the backup history: per-record deletion with an explicit confirmation; items that fail to delete are kept and listed.
- Icon-pack cloud backup publishing now uses staging + verification + atomic replacement: if publishing fails or is interrupted, the existing cloud icon-pack backup stays intact and recoverable instead of being truncated; files that fail during directory collection are honestly counted in restore results instead of silently reporting success.
