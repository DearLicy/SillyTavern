# 浏览器功能联动验收

仅用于开发验收。测试 fixture 从 `test/fixtures` 生成到被 Git 忽略的 `.tmp`，不会导入或编译进程序。无需真实 API Key，不会访问付费模型。

1. `export TMPDIR="$PWD/.tmp" TMP="$PWD/.tmp" TEMP="$PWD/.tmp"`，先 `mkdir -p .tmp`。
2. `dart run tool/qa/export_fixture.dart`。
3. `flutter build web --release --base-href '/SillyTavern/'`。
4. 指定已安装的 Playwright 模块与 Chromium，运行全部验收。包装脚本在本机 8089 端口托管构建，结束后关闭自身启动的服务：

```bash
PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core \
CHROMIUM_EXECUTABLE=/absolute/path/to/chrome \
bash tool/qa/run-browser-checks.sh
```

没有现成 Playwright 时，使用 Node.js 20+ 将依赖与浏览器装到项目 `.tmp`，不全局安装：

```bash
mkdir -p .tmp/qa
cp tool/qa/package*.json .tmp/qa/
npm ci --prefix .tmp/qa --ignore-scripts --no-audit --no-fund
export PLAYWRIGHT_MODULE="$PWD/.tmp/qa/node_modules/playwright"
export PLAYWRIGHT_BROWSERS_PATH="$PWD/.tmp/pw-browsers"
node .tmp/qa/node_modules/playwright/cli.js install chromium
bash tool/qa/run-browser-checks.sh
```

CI 额外安装 Chromium 系统依赖，并保存截图和验收日志。全部脚本使用独立新浏览器上下文，不会更改日常浏览器。单独运行脚本时可以通过 `DREAMTIDE_QA_BASE_URL` 指向其他待验收构建；只能在同意写入测试浏览器状态的目标使用。

脚本测试手机浅/深主题、头像选择预览保存、发送真实图片块、图片重生成、OCR 草稿、联网及来源、实际 PCM 录音与 ASR 上传、TTS 合成播放、带附件备份恢复与刷新。mock 服务检查 Bearer、URL、multipart 和图像/WAV 字节。结果与截图保存在 `.tmp`。

第三方兼容与重试验收使用相同准备步骤及环境变量，将脚本换为：

```bash
node tool/qa/compatible.e2e.cjs
```

此流程在手机浅/深主题中依次验证：空流只向原供应商回退一次非流式请求 → 正常显示并落盘 → 流内错误显示原因为供应商异常 → 点击重试 → 恢复正文且不重复用户消息。同时检查配置的模型、鉴权、请求地址、不添加输出额度和不落入空消息；不会调用真实收费服务。

供应商设置联动验收对应 `node tool/qa/provider.e2e.cjs`：更换地址后不复用旧 Key → 拉取 1500 个模型 → 搜索名称 → 选择保存 → 聊天使用刚保存的模型和 Key，浅深主题均检查无浏览器错误。

默认检查 390/1440 两种宽度及浅/深主题。线上抽查可指定 `DREAMTIDE_QA_WIDTHS=390`、`DREAMTIDE_QA_THEMES=light`，弱网首屏等待可通过 `DREAMTIDE_QA_STARTUP_TIMEOUT_MS` 调整。脚本等待实际画布和聊天控件，不以网络空闲或固定延时假定路由完成；失败时额外保存截图、可访问性树与请求路径。

三套脚本通过 Flutter 的可访问性节点定位控件，使用键盘输入和应用提供的语义操作；录音和消息长按也覆盖浏览器实际输入事件。每步查找有超时，长备份通过一次文本输入写入，避免逐字模拟键盘导致验收挂起。该验证不能替代手机触屏、系统键盘或屏幕阅读器实测。

浏览器启动时使用虚拟麦克风自动授予测试权限。真实权限拒绝、API 超时、取消与重置的错误路径另由 Dart/Widget 测试和专项浏览器测试覆盖；不能据此声称已经验收真机音质或设备性能。

如果更改插件后运行过旧构建，检查生成的 `web_plugin_registrant.dart` 是否包含 `ImagePickerPlugin`、`RecordPluginWeb`、`AudioplayersPlugin`。缓存过旧时先 `flutter clean`、`flutter pub get` 再构建；不要手改生成的注册文件。
