---
name: record-and-reflect-review
description: 记录 AI 对话工作摘要，并在用户明确要求回顾历史记录、识别重复模式或整理 skill 候选时，提出新增或维护 Codex skill 的建议。适用于用户要求记录线程、总结近期 AI 工作、回顾历史工作、识别反复出现的任务模式、整理 skill 候选、根据历史工作新增 skill，或优化已有 skill 的场景。单次任务复盘优先交给已安装的 `$task-retrospective`。
---

# 记录以及反思回顾

## 目标

维护一套按项目分开的 AI 工作记录。每个线程默认保存为简洁的 Markdown 摘要；只有在用户明确要求回顾历史记录、整理重复模式或判断 skill 候选时，才进一步做模式级分析。

## 默认规则

- 默认只记录摘要，不保存完整对话原文，除非用户明确要求。
- 不记录密钥、令牌、账号密码、公司敏感原文、客户敏感数据和不必要的个人隐私。
- 记录要服务于未来复用，重点保留目标、关键决策、修改文件、使用命令、验证结果、可复用流程和后续事项。
- 默认先完成记录，不默认展开单次任务复盘。
- 当用户明确要求复盘单次任务、反思协作方式、总结返工原因或判断本次任务如何改进时，优先使用已安装的 `$task-retrospective`。
- 记录只保存在当前工作目录下，避免不同项目的记录混在一起。
- 遵守当前工作区的 `AGENTS.md` 和用户规则；修改文件、删除记录、更新 skill 或执行 Git 操作前，按当前规则确认。
- 更新本 skill 或其他 skill 时，使用 `skill-creator` 指南并运行校验。

## 项目内记录结构

默认在当前工作目录创建并维护：

```text
项目根目录/
├── AI工作记录/
│   └── records/YYYY/MM/*.md
└── skill-backlog.md
```

本 skill 自身只保存工作流程、脚本和模板，不保存各项目的实际工作记录。

## 记录线程

1. 在线程开始时，为本次工作准备一条项目内记录。
2. 对话过程中如果目标、方案、文件修改、验证结果或后续事项发生变化，持续更新同一条记录。
3. 需要结构时读取 `references/record-template.md`。
4. 使用 `scripts/new_record.ps1` 创建日期化记录文件；如果脚本不适合当前环境，可以手动创建 Markdown。
5. 如果本次工作暴露出可复用流程或已有 skill 的不足，同步更新项目根目录下的 `skill-backlog.md`。

PowerShell 示例：

```powershell
$summary = @'
<整理好的 Markdown 摘要>
'@
$summary | powershell -ExecutionPolicy Bypass -File "C:\Users\Administrator\.codex\skills\record-and-reflect-review\scripts\new_record.ps1" -Title "线程简短主题"
```

## 回顾历史

当用户要求回顾近期工作、总结历史记录、筛选重复流程或寻找 skill 候选时：

1. 使用 `scripts/collect_records.ps1` 收集当前工作目录下的近期记录。
2. 阅读相关记录文件，不要只依赖文件名判断。
3. 按触发话术、工作流程、文件类型、工具链、返工原因和错误模式分组。
4. 当同类模式出现三次以上、明显会复用，或曾造成明显返工时，视为 skill 候选。
5. 输出以下建议之一：
   - 新增一个 skill；
   - 优化已有 skill；
   - 给已有 skill 增加脚本、模板或参考文档；
   - 暂时只保留记录，因为模式还不稳定。

## 删减记录

记录过多时，先筛选低价值记录，再向用户说明删除依据并按规则确认。

优先删减：

- 临时测试记录；
- 内容重复且没有新增决策的记录；
- 只包含闲聊或无执行结果的记录；
- 已被阶段性总结完整覆盖的细碎过程记录；
- 不再适合保留的敏感摘要。

保留：

- 包含关键决策、踩坑过程、验证方法或复用流程的记录；
- 已经支撑 skill 候选或 skill 优化的记录；
- 用户明确要求保留的记录。

## 新增或优化 Skill

修改 skill 前：

1. 说明准备新增或优化什么，以及依据哪些历史记录。
2. 按当前工作区规则取得确认。
3. 保持 `SKILL.md` 简洁，把详细示例放入 `references/`。
4. 只有当重复操作需要稳定执行时才新增脚本。
5. 使用校验脚本验证：

```powershell
$env:PYTHONUTF8 = "1"
python "C:\Users\Administrator\.codex\skills\.system\skill-creator\scripts\quick_validate.py" "<skill-folder>"
```

## 同步

本 skill 通过 GitHub 在不同机器间同步。Git 命令必须串行执行；如果当前工作区要求中文提交信息，就使用中文提交信息。

全局 `AGENTS.md` 不是 skill 仓库的一部分。需要在新机器上启用“每个线程默认记录”时，读取 `references/global-agents-rules.md`，把其中规则加入那台机器的全局 `AGENTS.md`。安装脚本会维护一个带标记的受管规则块；如果发现旧版“记录以及反思回顾”规则，会替换为最新模板。

## 新环境安装

在 Windows PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1")))'
```

默认会同时安装 `record-and-reflect-review` 和 `task-retrospective`。安装脚本会先更新源码缓存，再把本 skill 导出到 `~\.codex\skills\record-and-reflect-review`。再次运行同一条命令即可更新到最新版本。脚本还会把 `references/global-agents-rules.md` 中的规则写入或更新到全局 `~\.codex\AGENTS.md`，让新线程默认启用本 skill，并同步 Windows 命令习惯和 Git 串行规则。

如果只想单独安装记录 skill，可执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1"))) -SkillNames record-and-reflect-review'
```

如果只想安装或更新 skill，不写入全局规则：

```powershell
powershell -ExecutionPolicy Bypass -Command '$script = irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1"; & ([scriptblock]::Create($script)) -SkillNames record-and-reflect-review -SkipGlobalAgents'
```

如果当前终端对引号处理不稳定，使用两步命令：

```powershell
irm https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1 -OutFile "$env:TEMP\rethink-install.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\rethink-install.ps1" -SkillNames record-and-reflect-review -SkipGlobalAgents
```
