---
name: delegation-orchestrator
description: 将交付型任务组织为“主线程编排、subagent 执行”的委派协作模式，并按任务难度选择模型与思考深度。适用于代码、脚本、文档、自动化等需要拆分任务、划分文件 ownership、并行处理或控制主线程职责边界的场景；当用户希望主线程主要讨论方向和规则、把具体实现交给 subagent 时使用。
---

# 委派编排器

## 目标

- 把主线程收敛为控制平面，优先负责目标确认、任务拆分、约束整理、模型选择、结果集成与风险复核。
- 把具体实现、局部排查、验证执行和可并行的代码任务尽量下放给 subagent。
- 在不能安全委派时，保留同一套拆分与验收框架，由主线程说明原因后继续执行。

## 默认模式

- 对代码、脚本、文档、自动化等交付型任务，默认先按委派模式组织，而不是直接在主线程里边想边改。
- 先确认五项输入：最终结果、现有素材、明确约束、完成标准、产出后动作。信息足够时直接进入拆分，不拉长来回确认。
- 不抢 `$record-and-reflect-review` 和 `$task-retrospective` 的职责。记录、复盘仍按原有 skill 分工处理。

## 编排流程

1. 先判断任务是否适合委派：
   - 需要跨文件实现、重复验证、局部排查或并行切片时，优先委派。
   - 只有在任务极小、没有清晰切片、或当前环境不适合委派时，主线程才直接执行。
2. 把任务拆成控制平面与执行平面：
   - 主线程负责范围、约束、依赖关系、验收方式、模型选择和最后集成。
   - subagent 负责明确 ownership 内的实现、验证和结果回报。
3. 先区分关键路径和并行支线：
   - 会阻塞下一个决定的工作，优先由主线程完成拆解或发起最小必要委派。
   - 不阻塞当前下一步的实现、探索或验证，优先并行下放。
4. 使用 `references/delegation-playbook.md` 的分级表为每个子任务选择 `agent_type`、模型和 `reasoning_effort`。
5. 下发任务时写清楚：
   - 目标和非目标；
   - 负责文件或模块；
   - 禁止改动范围；
   - 验证要求；
   - 回报格式；
   - “你不是唯一在代码库里的 agent，不要回滚他人改动”。
6. subagent 返回后，主线程快速复核改动、运行必要验证、处理集成冲突，再向用户汇总结果与风险。

## 任务分派规则

- 需要代码库事实、调用链、配置来源、影响范围时，优先派 `explorer`。
- 需要实现、修测试、改脚本或处理明确文件集合时，优先派 `worker`。
- 多个 `worker` 并行时，确保 write set 不重叠；如无法保证，收窄切片或改为串行。
- 不要为了“看起来用了 subagent”而委派一个高度耦合、立即阻塞、又无法清晰切片的任务。

## 模型与思考深度

- 使用 `references/delegation-playbook.md` 的 L1-L4 分级，不凭感觉选模型。
- 优先根据四个维度分级：改动范围、代码陌生度、失败代价、验证成本。
- 任务本身还在收敛、可能影响架构或难以回滚时，先由主线程讨论方案，再委派高强度 worker。

## 输出要求

- 默认先给出简洁的委派方案：拆分结果、ownership、模型选择理由、预期验证。
- 如果最终没有实际委派，也要说明为什么不委派，以及仍然沿用了哪些拆分与验收规则。
- 当需要固定措辞时，读取 `references/delegation-playbook.md` 中的 prompt 模板，而不是临场重新发明。

## 新环境安装

在 Windows PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1")))'
```

默认会同时安装 `record-and-reflect-review`、`task-retrospective` 和 `delegation-orchestrator`，并更新全局 `AGENTS.md`，让新线程默认进入委派协作模式。如果只想单独安装本 skill，可执行：

```powershell
powershell -ExecutionPolicy Bypass -Command '& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/Randolph87cb/rethink/main/install.ps1"))) -SkillNames delegation-orchestrator'
```

如果已经安装过，则再次运行同一条命令即可更新到最新版本。
