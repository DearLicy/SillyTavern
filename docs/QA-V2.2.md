# V2.2.0 验收记录

验收日期：2026-11-28

## 静态与测试

```text
flutter analyze
No issues found

flutter test
238 tests passed

flutter build web --release --base-href /SillyTavern/
Built build/web

flutter build apk --release --split-per-abi
Built app-armeabi-v7a-release.apk
Built app-arm64-v8a-release.apk
Built app-x86_64-release.apk
```

## 浏览器验收

使用本地 `build/web`、Chromium 390×844 视口和真实 Flutter Web 构建检查：

- 首次启动显示成年确认；
- 确认后进入空白会话首页，不出现角色、消息、记忆或动态；
- 角色库为空时显示 Character Card V2 JSON/PNG 导入入口；
- 根页面与聊天均没有 `root-bottom-bar`；
- 角色库不出现好感、信任、心动、张力；
- 角色详情不出现导演模式或关系数值；
- 聊天菜单不出现当前场景或安全词；
- 测试夹具只在浏览器 QA 环境中注入，运行时空状态不包含演示数据。
- 使用全新浏览器上下文走完成年确认、空白会话首页和空白角色库，没有旧联系人/动态导航、运行时异常或控制台错误。
- Prompt Manager 在 390×844 浅色和深色真实 Web 构建中完成视觉检查，提示词块、角色、注入位置和启停状态均可见。
- GitHub Pages 线上版本返回 200、标题正确且无运行时异常；Web 字体从 17 MB 完整 TTF 改为约 321 KB 的界面字库 WOFF2，避免慢网首屏被字体下载阻塞。

截图位于 `assets/screenshots/`：

- `01-age-gate.png`
- `02-clean-home.png`
- `03-characters.png`
- `04-character-card.png`
- `05-chat.png`
- `06-prompt-manager.png`

## 已知环境限制

- Android/iOS 原生性能、应用锁、通知和签名安装仍需在对应真机环境验收；
- 当前 Linux 环境只验证 Android Release 构建；iOS unsigned IPA 交由 macOS CI 验证；
- 微信/QQ 内嵌浏览器、CORS、第三方供应商网关差异需要用户目标设备复核；
- 当前未执行任意 SillyTavern JavaScript 扩展。
