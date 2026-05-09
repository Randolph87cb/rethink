---
name: task-retrospective
description: 基于当前线程记录或项目内工作记录，对单次任务或一段协作过程做复盘，定位信息缺口、返工原因、协作改进点，并判断是否值得模板化、脚本化或 skill 化。适用于用户要求“复盘一下”“反思这次协作”“总结哪里该改进”“看看哪些信息一开始就该给”“判断是否该沉淀为模板或 skill”的场景。
---

# 任务复盘反思

## 目标

在任务完成后，基于事实记录做一次短而有用的复盘，优先帮助后续同类任务减少返工、补齐输入、明确哪些经验值得沉淀。

## 默认规则

- 先基于当前线程记录整理事实；如果记录不完整，再从当前对话、修改结果和验证结果补齐必要事实。
- 复盘重点放在改进下一次协作，不要把输出写成长篇聊天摘要。
- 优先区分三类内容：已经发生的事实、对返工原因的判断、下一次可执行的改进建议。
- 单次复盘默认不直接新建 skill；只有在模式重复稳定时，才建议更新 `skill-backlog.md` 或新增 skill。
- 如果项目内已经有 `AI工作记录/records/...` 记录，复盘结束后同步更新同一条记录。

## 复盘流程

1. 先读取当前线程记录；如果用户明确要求跨多个任务复盘，再补读相关历史记录。
2. 需要结构时读取 `references/retrospective-template.md`。
3. 优先回答四个固定问题：
   - 这次真正的目标是什么。
   - 哪些信息一开始就该给。
   - 哪些返工来自需求不清、约束遗漏或验收标准不完整。
   - 下次是否值得模板化、脚本化或 skill 化。
4. 如果只是一次性的改进建议，直接给结论并更新当前记录。
5. 如果发现同类问题已经重复出现三次以上，或明显属于稳定流程问题，再更新项目根目录 `skill-backlog.md`。

## 输出要求

- 默认输出简洁、可执行的复盘结论，不要先铺陈冗长背景。
- 优先给出“下次怎么做会更好”，而不是只复述“这次发生了什么”。
- 如果建议修改全局提示词、record skill、模板、脚本或 backlog，明确指出建议落点。
- 如果证据不足，明确标注“需要更多记录支撑”，不要把猜测写成结论。

## 与记录 Skill 的分工

- `$record-and-reflect-review` 负责过程记录、历史记录整理和 skill 候选沉淀。
- `$task-retrospective` 负责单次任务或一小段协作的复盘反思。
- 当用户只是要求“记录一下”“更新工作记录”“整理近期记录”，不要抢 record skill 的职责。

## 新环境安装

在 Windows PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1")))'
```

默认会同时安装 `record-and-reflect-review`、`task-retrospective` 和 `delegation-orchestrator`。如果只想单独安装反思 skill，可执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1"))) -SkillNames task-retrospective'
```

如果已经安装过，则再次运行同一条命令即可更新到最新版本。
