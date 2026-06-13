# OpenAI Codex App Windows 重连问题排查工具包

本工具包用于帮助 Windows 用户排查 OpenAI Codex App、OpenAI 或 ChatGPT 客户端反复“正在重连”、无法连接、网络异常等问题。

> **安全说明**：本工具包不会删除用户文件。重置脚本只会把可能相关的缓存目录移动到带时间戳的备份目录中，便于需要时恢复。

## 文件说明

- `check-codex-network.ps1`：只读检查脚本，用于收集代理、DNS、HTTPS、端口和缓存目录状态。
- `reset-codex-client.ps1`：安全重置脚本，用于停止相关进程、备份缓存目录、同步 WinHTTP 代理，并输出下一步操作建议。

## 使用前准备

1. 在 Windows 中打开 **PowerShell**。
2. 建议使用普通用户权限先运行检查脚本；如果需要修改 WinHTTP 代理或停止某些进程，请使用“以管理员身份运行”。
3. 如果 PowerShell 阻止运行本地脚本，可在当前窗口临时允许本次会话运行脚本：

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

## 第一步：运行网络检查

在本工具包目录中执行：

```powershell
.\check-codex-network.ps1
```

脚本会检查以下内容：

1. 当前 WinHTTP 代理配置。
2. 当前系统代理注册表设置。
3. `chatgpt.com`、`openai.com`、`oaistatic.com`、`oaiusercontent.com` 的 DNS 解析结果。
4. `https://chatgpt.com` 的 HTTPS 请求是否成功。
5. 本机常见代理端口 `7890`、`7897`、`1080`、`10808` 是否正在监听。
6. `%APPDATA%` 和 `%LOCALAPPDATA%` 下是否存在 Codex、OpenAI、ChatGPT 相关缓存目录。

## 第二步：根据检查结果处理

- 如果 DNS 解析失败，请检查系统 DNS、公司网络策略或代理软件的 DNS 设置。
- 如果 HTTPS 请求失败，请确认代理软件是否启动，并检查系统代理是否正确。
- 如果本地代理端口没有打开，但你平时依赖代理访问 OpenAI 服务，请先启动代理软件。
- 如果 WinHTTP 代理为空但系统代理已配置，可运行重置脚本同步 WinHTTP 代理。

## 第三步：安全重置 Codex 客户端

如果 Codex App 仍然反复重连，可运行：

```powershell
.\reset-codex-client.ps1
```

该脚本会执行以下操作：

1. 停止名称中包含 `Codex`、`OpenAI` 或 `ChatGPT` 的相关进程。
2. 将 `%APPDATA%` 和 `%LOCALAPPDATA%` 下可能相关的缓存目录移动到同级备份目录。
3. 备份目录会带有时间戳后缀，例如 `OpenAI.backup-20260613-153000`。
4. 执行 `netsh winhttp import proxy source=ie`，把当前系统代理导入 WinHTTP。
5. 输出清晰的后续操作建议。

## 重置后的建议步骤

1. 确认代理软件已启动，并且浏览器可以打开 `https://chatgpt.com`。
2. 重新启动 OpenAI Codex App。
3. 如果问题仍然存在，请再次运行 `check-codex-network.ps1`，并把输出结果提供给支持人员。
4. 如果需要恢复缓存，可关闭 Codex App 后，将对应的 `.backup-时间戳` 目录改回原目录名。

## 注意事项

- 本工具包不会修改或删除项目代码、文档、下载文件等用户数据。
- 缓存目录可能包含登录状态、临时文件或应用配置；备份后首次启动应用可能需要重新登录。
- 在公司、校园或受管设备上，代理和证书策略可能由管理员统一控制，请遵守所在组织的网络规则。
