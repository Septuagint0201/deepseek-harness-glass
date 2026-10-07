# DeepSeek Harness Glass

为本机安装的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
提供原生 macOS Liquid Glass 窗口。此分支保留 PR #1 的原生菜单与快捷键，独立继续开发，
适配 **dsh 0.2.0-rc.2**。应用仅包含 Swift 前端封装，不携带 Node.js、dsh 后端、
npm 包或单独复制的 Web 前端。

## 环境要求

从 [GitHub Releases](https://github.com/Septuagint0201/deepseek-harness-glass/releases)
或 [GitLab Releases](https://gitlab.com/Septuagintks/deepseek-harness-glass/-/releases)
下载 DMG，将应用拖入 Applications。

- macOS 26 及以上、Apple Silicon。
- 单独安装 dsh 及其要求的 Node.js。测试版本安装命令：
  `npm install -g @deepseek-ai/dsh@0.2.0-rc.2`。
- 确认终端能执行 `dsh --version` 和 `dsh web --no-open`。

应用沿用 `DSH_HOME`，默认 `~/.dsh`。数据、凭据、插件、迁移和升级由本机 dsh 管理；
Glass 不安装或升级后端。

## 连接与进程管理

1. 优先探测 `http://127.0.0.1:3080/`，之后记住最近成功连接的地址。
   `DSH_WEB_URL` 可覆盖地址并指定自定义端口。
2. 已有 dsh 服务时直接复用。0.2.0-rc.2 首次连接需要认证：在连接界面粘贴
   `dsh web` 输出的完整链接（包含 token），或通过 `DSH_WEB_URL` 提供。
   WebKit 保存认证 cookie，Glass 仅持久保存去除 token 的地址。
3. 只有连接被拒绝、没有服务监听时，才静默执行本机
   `dsh web --no-open --host <本地地址> --port <端口>`；不打开终端或浏览器。
   从完整输出行读取含 token 的启动链接。
4. 关闭窗口后驻留菜单栏；退出应用仅结束 Glass 自己启动的子进程。
   外部 dsh 不会被停止，“重启”操作对外部服务只重新连接。
   自己启动的进程意外退出后自动重试一次。

从 Finder 启动时通过登录／交互式 zsh 加载用户的 fnm、nvm、Homebrew 配置。
`DSH_EXECUTABLE` 可指定可执行文件的绝对路径，其 Node 仍需在该 shell 的 PATH 中。
仅支持本地 HTTP 地址；不自动扫描其他端口，需要提供已有服务的启动链接。
端口占用、认证未完成或服务无响应时显示连接提示，不重复启动后端。

## 原生功能

- Liquid Glass 原生窗口、透明 WKWebView、CSS 主题令牌覆盖。
- 原生菜单、快捷键、刷新、浏览器打开、菜单栏驻留。
- 下载后在 Finder 中显示文件，共享 CLI 数据，分层透明界面。
- 启动日志：`~/Library/Logs/DeepSeek Harness Glass.log`，token 自动脱敏。

## 构建与验证

需要支持 macOS 26 SDK 的 Xcode Command Line Tools。构建无需 npm 或后端下载；测试需要 Python 3。

```sh
APP_PATH="$PWD/glass/dist/DeepSeek Harness.app" glass/assemble.sh
python3 glass/Tests/smoke.py
python3 glass/Tests/install.py
# 用独立临时 DSH_HOME 验证本机实际 dsh：
GLASS_TEST_REAL_DSH=1 python3 glass/Tests/smoke.py
```

不设置 `APP_PATH` 时默认安装到 `/Applications/DeepSeek Harness.app`。
应用使用 ad-hoc 签名，未公证。发布 CI 编译此前端封装并打包为 DMG，附 SHA-256 校验文件。
`main` 推送与 PR 会运行构建、连接、真实 WebKit 下载和原子安装测试。
安装前验证暂存应用的签名，再通过原子目录交换替换已有应用；失败时保留旧应用。
应用退出后重新启动，会恢复上次的窗口位置和尺寸。

## 排错

找不到 dsh 时请单独安装并重试。启动失败时查看日志，并在终端检查 CLI 命令。
已有服务需要认证时粘贴启动链接；外部服务重启会生成新 token，必要时使用新链接。
Glass 不读取或伪造 dsh 凭据。

## 项目结构

- `glass/Sources/main.swift`：原生窗口、菜单、WebKit 与 CSS。
- `glass/Sources/BackendController.swift`：本地服务连接和进程管理。
- `glass/Tests/`：连接、下载与安装测试。
- `glass/assemble.sh`：编译、验证签名与原子安装前端应用。
- `glass/Tools/AtomicInstall.swift`：macOS 原子目录交换工具。
- `glass/Info.plist`：应用元数据。
- `build/icon.icns`：应用图标。

## 声明与许可

这是独立、非官方的封装，与 DeepSeek 无隶属或背书关系。
采用 MIT 许可，详见 [LICENSE](LICENSE) 和 [第三方声明](THIRD_PARTY_NOTICES.md)。

发布标签统一为 `glass-<dsh 版本号>`，当前为 `glass-0.2.0-rc.2`。
