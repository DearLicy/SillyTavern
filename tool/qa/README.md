# 多模态浏览器联动验收

仅用于开发验收。测试 fixture 从 `test/fixtures` 生成到被 Git 忽略的 `.tmp`，不会导入或编译进程序。无需真实 API Key，不会访问付费模型。

1. `export TMPDIR="$PWD/.tmp" TMP="$PWD/.tmp" TEMP="$PWD/.tmp"`，先 `mkdir -p .tmp`。
2. `dart run tool/qa/export_fixture.dart`。
3. `flutter build web --release --base-href '/Dreamtide/'`。
4. 将 `build/web` 以 `/Dreamtide/` 路径托管到本机测试 HTTP 服务，默认 `http://127.0.0.1:8089/Dreamtide/`。
5. 指定已安装的 Playwright 模块与 Chromium（不自动下载浏览器），运行：

```bash
PLAYWRIGHT_MODULE=/absolute/path/to/playwright-core \
CHROMIUM_EXECUTABLE=/absolute/path/to/chrome \
node tool/qa/multimodal.e2e.cjs
```

可以通过 `DREAMTIDE_QA_BASE_URL` 指向其他待验收构建。只能在你同意写入测试浏览器状态的目标使用；脚本通过独立新浏览器上下文隔离数据，不会更改日常浏览器。

脚本测试手机浅/深主题、头像选择预览保存、发送真实图片块、图片重生成、OCR 草稿、联网及来源、实际 PCM 录音与 ASR 上传、TTS 合成播放、带附件备份恢复与刷新。mock 服务检查 Bearer、URL、multipart 和图像/WAV 字节。结果与截图保存在 `.tmp`。

第三方兼容与重试验收使用相同准备步骤及环境变量，将脚本换为：

```bash
node tool/qa/compatible.e2e.cjs
```

此流程在手机浅/深主题中依次验证：空流只向原供应商回退一次非流式请求 → 正常显示并落盘 → 流内错误显示原因为供应商异常 → 点击重试 → 恢复正文且不重复用户消息。同时检查配置的模型、鉴权、请求地址、不添加输出额度和不落入空消息；不会调用真实收费服务。

两套脚本通过 Flutter 的可访问性节点定位控件，使用键盘输入和应用提供的语义操作；录音和消息长按也覆盖浏览器实际输入事件。每步查找有超时，长备份通过一次文本输入写入，避免逐字模拟键盘导致验收挂起。该验证不能替代手机触屏、系统键盘或屏幕阅读器实测。

浏览器启动时使用虚拟麦克风自动授予测试权限。真实权限拒绝、API 超时、取消与重置的错误路径另由 Dart/Widget 测试和专项浏览器测试覆盖；不能据此声称已经验收真机音质或设备性能。

如果更改插件后运行过旧构建，检查生成的 `web_plugin_registrant.dart` 是否包含 `ImagePickerPlugin`、`RecordPluginWeb`、`AudioplayersPlugin`。缓存过旧时先 `flutter clean`、`flutter pub get` 再构建；不要手改生成的注册文件。
