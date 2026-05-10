# Playwright 接入

## JavaScript / TypeScript

```javascript
import { execFileSync } from "node:child_process";
import { chromium } from "playwright";

const skillScript =
  `${process.env.USERPROFILE}\\.codex\\skills\\browser-session-manager\\scripts\\session_registry.ps1`;

function getSession() {
  const raw = execFileSync(
    "powershell",
    [
      "-ExecutionPolicy", "Bypass",
      "-File", skillScript,
      "get",
      "-Site", "shop-admin",
      "-Env", "prod",
      "-Account", "ops",
      "-Browser", "chromium"
    ],
    { encoding: "utf8" }
  );

  return JSON.parse(raw);
}

const session = getSession();

const browser = await chromium.launch();
const context = await browser.newContext(
  session.statePath ? { storageState: session.statePath } : {}
);
const page = await context.newPage();

await page.goto(session.checkUrl ?? session.baseUrl);

if (session.checkSelector) {
  await page.waitForSelector(session.checkSelector, { timeout: 5000 });
}

await page.click("button");
await page.mouse.move(400, 300, { steps: 20 });
await page.hover("[data-test='menu']");
await page.keyboard.press("Tab");
```

## Python

```python
import json
import subprocess
from playwright.sync_api import sync_playwright

skill_script = r"C:\Users\Administrator\.codex\skills\browser-session-manager\scripts\session_registry.ps1"

raw = subprocess.check_output(
    [
        "powershell",
        "-ExecutionPolicy", "Bypass",
        "-File", skill_script,
        "get",
        "-Site", "shop-admin",
        "-Env", "prod",
        "-Account", "ops",
        "-Browser", "chromium",
    ],
    text=True,
)
session = json.loads(raw)

with sync_playwright() as p:
    browser = p.chromium.launch()
    context = browser.new_context(storage_state=session["statePath"])
    page = context.new_page()
    page.goto(session.get("checkUrl") or session["baseUrl"])
    page.click("button")
    page.mouse.move(400, 300, steps=20)
```

## 推荐流程

如果只是想人工登录一次并更新登录态，优先直接调用：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\refresh_login.ps1" `
  -Site shop-admin `
  -Env prod `
  -Account ops `
  -Browser chromium `
  -BaseUrl https://admin.example.com
```

这会打开浏览器；你完成登录并关闭窗口后，脚本会自动保存 `storageState`。如果这条会话还不存在，脚本会用本次提供的 URL 自动建档。

如果要统一检查登录态，优先直接调用：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\verify_session.ps1" `
  -Site shop-admin `
  -Env prod `
  -Account ops `
  -Browser chromium
```

默认会访问 `checkUrl` 或 `baseUrl`，判断页面是否仍然出现登录入口；这适合把“主页是否还有登录选项”作为通用验收逻辑的站点。

1. 启动前先调用 `get` 读取会话元数据。
2. 如果 `statePath` 文件存在，则直接加载。
3. 如果加载后发现未登录，则走登录流程并在成功后重写 `storageState`：

```javascript
await context.storageState({ path: session.statePath });
```

4. 登录确认后调用：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\browser-session-manager\scripts\session_registry.ps1" mark-verified `
  -Site shop-admin `
  -Env prod `
  -Account ops `
  -Browser chromium
```

## 能力说明

- `storageState` 只决定“从什么登录态启动”，不限制自动化操作类型。
- Playwright 仍然支持：
  - `click`
  - `dblclick`
  - `hover`
  - `fill`
  - `press`
  - `dragAndDrop`
  - `mouse.move`
  - `mouse.down` / `mouse.up`
  - 滚动和等待
- 如果网站需要更像人的轨迹，可以增加：
  - 随机等待
  - 分段 `mouse.move`
  - 渐进式输入
  - 页面可见性检查

这些都属于站点脚本层，不属于会话注册表本身。
