# Skill 候选与优化队列

记录从 AI 工作历史中观察到的可复用流程。只有当模式足够稳定、重复出现，或明显能减少返工时，才推进为新 skill 或现有 skill 优化。

## 候选

| 日期 | 模式 | 证据记录 | 建议动作 | 状态 |
| --- | --- | --- | --- | --- |
| 2026-05-10 | 多个浏览器爬虫脚本重复维护登录态，希望统一管理 cookie / session / profile | `AI工作记录/records/2026/05/2026-05-10-讨论-浏览器登录态全局skill设计.md` | 评估新增全局 skill，统一会话存储、命名、校验与刷新流程 | 讨论中 |

## 已处理

| 日期 | 模式 | 处理结果 | 相关 skill |
| --- | --- | --- | --- |
| 2026-05-09 | 任务入口与复盘模板偏弱 | 已在全局规则模板中补充“任务输入与交付”小节；已将 `record-and-reflect-review` 收敛为记录优先；已新增独立复盘 skill `task-retrospective` 承接单次任务复盘；记录模板保留任务输入摘要，复盘模板移入新 skill | record-and-reflect-review, task-retrospective |
| 2026-05-09 | backlog 路径约定不一致 | 已统一为项目根目录 `skill-backlog.md`，并同步修正全局规则模板和 `SKILL.md` 文案 | record-and-reflect-review |
| 2026-05-09 | 单次任务复盘需要独立触发，不应继续挤在 record skill 中 | 已新增 `skills/task-retrospective/`，并扩展安装脚本支持其全局安装与更新；全局规则新增“任务完成后的复盘”小节，record skill 同步让出复盘职责 | task-retrospective |
| 2026-05-09 | 两个 skill 的目录层级和安装方式不一致 | 已将 `record-and-reflect-review` 迁移到 `skills/record-and-reflect-review/`；安装脚本改为对两个 skill 都使用“源码缓存 + 导出安装/更新”的统一模式 | record-and-reflect-review, task-retrospective |
| 2026-05-09 | 默认运行 install 脚本后未安装全局反思 skill | 已将 `install.ps1` 的默认 `SkillNames` 改为同时安装 `record-and-reflect-review` 与 `task-retrospective`，并补充旧版安装目录清理逻辑；已在用户本机执行默认安装并验证成功 | record-and-reflect-review, task-retrospective |
| 2026-05-09 | 主线程只讨论方向和规则，具体实现优先交给 subagent | 已新增全局 skill `delegation-orchestrator`，默认安装时一并导出；全局规则模板新增“委派协作模式”小节，使交付型任务默认按委派模式组织 | delegation-orchestrator, record-and-reflect-review |
