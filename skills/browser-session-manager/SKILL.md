---
name: browser-session-manager
description: 统一管理浏览器自动化脚本复用的登录态，默认以 Playwright `storageState` 为主，必要时补充独立 profile。适用于浏览器爬虫、自动化测试、站点登录脚本、跨项目复用 cookie/session、避免重复扫码或重复登录、为后续脚本建立统一会话目录和注册表的场景。
---

# 浏览器登录态管理

## 目标

- 在 repo 之外维护一套全局浏览器会话目录，避免把真实登录态提交到项目仓库或混进 skill 本身。
- 默认优先使用 `storageState`，只在目标站点强依赖完整浏览器环境时才切到 `profile` 或混合模式。
- 为后续脚本提供统一的会话命名、路径分配、注册表查询和刷新流程。

## 默认架构

- 默认全局目录为 `%LOCALAPPDATA%\Codex\browser-sessions`。
- 真实会话数据放在全局目录中；skill 目录只保存规则、脚本和参考文档。
- 使用 `scripts/session_registry.ps1` 维护注册表，避免每个脚本各自拼路径和 JSON。
- 使用 `scripts/refresh_login.ps1` 以“一条命令打开浏览器并刷新登录态”的方式维护常用站点。
- 使用 `scripts/verify_session.ps1` 统一检查会话是否仍有效；默认逻辑是打开 `checkUrl` 或主页，判断页面上是否还出现登录入口。
- 需要了解目录结构、字段含义和命名规范时，读取 `references/store-layout.md`。
- 需要把会话接入 Playwright 脚本时，读取 `references/playwright-integration.md`。

## 模式选择

- 默认使用 `storageState`：
  - 站点只依赖 cookie、localStorage 或常规前端会话恢复。
  - 需要轻量、可移植、易复用的登录态。
- 使用 `profile`：
  - 站点强依赖完整浏览器目录、IndexedDB、Service Worker 或更重的本地环境。
  - 脚本在本机串行执行，可接受目录更大、并发更差。
- 使用 `hybrid`：
  - 默认仍从 `storageState` 启动，但同时保留独立 profile 作为站点级 fallback。

## 工作流

1. 为站点选一个稳定的会话主键：
   - `site`
   - `env`
   - `account`
   - `browser`
2. 先初始化或获取会话槽位：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\session_registry.ps1" init

powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\session_registry.ps1" upsert `
  -Site example `
  -Env prod `
  -Account ops `
  -Browser chromium `
  -Mode storageState `
  -BaseUrl https://example.com `
  -CheckUrl https://example.com/account `
  -CheckSelector '[data-test="user-menu"]'
```

3. 在站点登录脚本中：
   - 先调用 `get` 读取会话元数据。
   - 如果 `statePath` 已存在，优先用它启动浏览器上下文。
   - 如果登录失效，则走人工或半自动登录流程，完成后重写 `storageState` 文件。
   - 成功验证后调用 `mark-verified` 更新时间。
4. 只有在 `storageState` 持续不稳定时，才把该站点切到 `profile` 或 `hybrid`。

## 快速刷新

- 优先用 `scripts/refresh_login.ps1` 做人工登录刷新：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\refresh_login.ps1" `
  -Site example `
  -Env prod `
  -Account ops `
  -Browser chromium `
  -BaseUrl https://example.com `
  -CheckUrl https://example.com/account `
  -CheckSelector '[data-test="user-menu"]'
```

- 这条命令会：
  - 自动创建或读取会话；
  - 打开 Playwright 浏览器；
  - 尝试加载现有 `storageState`；
  - 在你关闭浏览器后自动回写 `storageState`；
  - 成功保存后自动执行 `mark-verified`。
- 如果会话不存在，只要本次命令里提供了 `-Url` 或 `-BaseUrl`，脚本会自动创建这条会话，不需要额外区分“第一次”和“后续”。
- 新增站点时如果没有显式传 `-CheckUrl`，脚本会自动把 `checkUrl` 补成 `baseUrl`，方便后续直接复用统一的登录态检查命令。

## 会话检查

- 默认检查命令：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\verify_session.ps1" `
  -Site example `
  -Env prod `
  -Account ops `
  -Browser chromium
```

- 默认检查逻辑：
  - 优先访问注册表中的 `checkUrl`，没有则退回 `baseUrl`；
  - 如果页面上出现 `登录`、`注册`、`login`、`sign in` 一类入口，判定为未登录；
  - 如果配置了 `checkSelector` 且该元素可见，优先判定为已登录。

## 脚本约定

- 所有站点脚本都应优先调用注册表脚本，而不是硬编码会话目录。
- 人工维护登录态时，优先复用 `refresh_login.ps1`，不要为每个站点单独重复写“打开浏览器并保存状态”的壳脚本。
- 站点脚本负责“验证是否真的已登录”；注册表脚本只负责路径、索引和元数据，不负责站点级判断。
- 站点脚本保存登录态后，应回写注册表中的：
  - `mode`
  - `statePath` 或 `profilePath`
  - `baseUrl`
  - `checkUrl`
  - `checkSelector`
  - `lastVerifiedAt`

## 能力边界

- 本 skill 只解决“登录态如何统一保存和复用”，不限制浏览器自动化能力本身。
- 对于 Playwright 一类工具，点击、输入、悬停、拖拽、滚动、鼠标移动、键盘操作都仍然可用。
- 真正的限制通常来自目标站点的验证码、设备绑定、WebAuthn、反自动化脚本或浏览器指纹校验，而不是 `storageState`。

## 安全要求

- 不要把账号密码、OTP、令牌原文写入 repo、工作记录或 skill 文件。
- 默认只保留登录后的会话文件和最小必要元数据。
- 删除会话时，先确认是否只是从注册表移除，还是连同真实文件一起清理。

## 新环境安装

在 Windows PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1")))'
```

默认会同时安装 `record-and-reflect-review`、`task-retrospective`、`delegation-orchestrator` 和 `browser-session-manager`。如果只想单独安装本 skill，可执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1"))) -SkillNames browser-session-manager'
```
