# 会话存储结构

## 目录结构

默认根目录：

```text
%LOCALAPPDATA%\Codex\browser-sessions\
├── registry.json
├── states\
│   └── <site>--<env>--<account>--<browser>.json
└── profiles\
    └── <site>--<env>--<account>--<browser>\
```

- `registry.json`：统一记录会话元数据。
- `states/`：存放 Playwright `storageState` 文件。
- `profiles/`：存放少数站点需要的独立 profile 目录。

## 会话主键

统一用以下四元组识别一个会话：

- `site`：站点短名，例如 `github`、`shop-admin`
- `env`：环境，例如 `prod`、`staging`
- `account`：账号别名，例如 `ops`、`seller-a`
- `browser`：浏览器，例如 `chromium`、`firefox`

注册表里的 `key` 固定拼成：

```text
site|env|account|browser
```

文件名固定拼成：

```text
site--env--account--browser
```

## 注册表字段

`registry.json` 采用如下结构：

```json
{
  "version": 1,
  "updatedAt": "2026-05-10T22:30:00+08:00",
  "sessions": [
    {
      "key": "shop-admin|prod|ops|chromium",
      "site": "shop-admin",
      "env": "prod",
      "account": "ops",
      "browser": "chromium",
      "mode": "storageState",
      "statePath": "C:\\Users\\me\\AppData\\Local\\Codex\\browser-sessions\\states\\shop-admin--prod--ops--chromium.json",
      "profilePath": null,
      "baseUrl": "https://admin.example.com",
      "checkUrl": "https://admin.example.com/dashboard",
      "checkSelector": "[data-test='avatar']",
      "tags": [
        "seller",
        "manual-login"
      ],
      "notes": "首次登录需要短信验证码",
      "createdAt": "2026-05-10T22:00:00+08:00",
      "updatedAt": "2026-05-10T22:30:00+08:00",
      "lastVerifiedAt": "2026-05-10T22:30:00+08:00"
    }
  ]
}
```

## 路径规则

- `storageState` 默认路径：

```text
%LOCALAPPDATA%\Codex\browser-sessions\states\<safe-file-name>.json
```

- `profile` 默认路径：

```text
%LOCALAPPDATA%\Codex\browser-sessions\profiles\<safe-file-name>\
```

- 如果脚本显式传入绝对路径，以显式路径为准。
- 如果传入相对路径，相对根目录解析。

## 建议约束

- 一个站点一个账号至少有一个独立会话，不要让多个账号共用同一份 `storageState`。
- `profile` 目录默认不要被多个脚本并发复用。
- 站点脚本在验证成功后再调用 `mark-verified`，不要把“文件存在”当作“已登录”。
