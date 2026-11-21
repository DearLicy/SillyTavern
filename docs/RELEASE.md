# 构建与 GitHub 发布

Dreamtide 只通过 GitHub 分发，不上架应用商店。

## Android

```bash
flutter build apk --release --split-per-abi
```

产物：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

CI 使用调试签名只用于公开测试构建。正式长期更新应先配置独立 Android release keystore，并把 Base64 或文件内容保存在 GitHub Actions Secrets 中，禁止提交到仓库。

## iOS 自签

GitHub Release 提供 unsigned IPA。用户自签流程：

1. 安装 iLoader；
2. 在 iLoader 中安装 LiveContainer 与 SideStore；
3. 导入 `Dreamtide-unsigned.ipa`；
4. 使用自己的 Apple ID 完成签名；
5. 按 SideStore 提示完成续签。

构建命令：

```bash
flutter build ios --release --no-codesign
```

把 `Runner.app` 放入 `Payload/`，压缩为 `Dreamtide-unsigned.ipa`：

```bash
mkdir -p .tmp/ipa/Payload
cp -R build/ios/iphoneos/Runner.app .tmp/ipa/Payload/
cd .tmp/ipa
zip -qry ../../build/Dreamtide-unsigned.ipa Payload
cd ../..
```

所有中间文件只放在 `.tmp/`。不要使用系统 `/tmp`。

## Web

```bash
flutter build web --release --base-href "/Dreamtide/"
```

GitHub Pages 发布 `build/web`。Web 是完整 BYOK 客户端，但受浏览器本地存储、CORS 与第三方供应商接口差异限制。

## Release 内容

每个 GitHub Release 应包含：

- Android APK 文件；
- `Dreamtide-unsigned.ipa`；
- `SHA256SUMS.txt`；
- 自签安装说明；
- 版本更新日志；
- Web 构建来源版本。

## 本地工具

本仓库约定：

- `TMPDIR=<仓库路径>/.tmp`
- Gradle 缓存可以使用现有系统缓存，但禁止把构建产物写入系统 `/tmp`
- 不创建功能分支，直接提交并推送 `main`

## V2.0.1 更新

- 首次安装为空白状态，不内置梦设、角色、会话、记忆或动态。删除本地演示回复、模拟角色点赞与评论。
- 默认 DeepSeek 官方；拉取真实模型列表后选择保存，未配置时保留聊天草稿。
- AI 括号动作与 V1 Markdown 旁白显示在气泡外，过滤空内容和协议残留。
- 主要交互控件切换至 Forui，降低圆角、阴影与动效强度，弹层完整覆盖底栏。
- 清空数据同步删除密钥，并阻止未完成的旧回复重新写回。

旧版本中已经保存的数据不会被更新静默删除。如需从空白状态开始，请先自行备份，再在「数据与备份」中清空。

## V2.0.2 更新

- OpenAI 兼容聊天默认不再发送 `max_tokens`，避免推理模型先耗尽内部推理额度后返回空正文；兼容 SSE、普通 JSON 和 `reasoning_content` 流式响应。
- 移除正文硬截断；回复长度改由本轮回复计划引导。
- 失败请求可直接重试上一条，最新角色回复可重新生成，不重复用户消息。
- 新增相册与相机图片消息、发送前预览和可选说明文字；原生附件写入应用私有目录，Web 附件写入 IndexedDB，不把图片 Base64 写入主数据库。

## V2.0.3 更新

- 正常对话完成后自动结算好感、信任、心动、张力和关系阶段，关系页展示上轮数值变化、原因与累计互动轮数。
- 同一条用户消息重新生成、重试不会重复增加关系数值。
- 最近角色表达会作为反复读提示注入；生成结果与近期回复高度相似时静默重写一次。


## V2.0.4 更新

- 新增聊天数据管理：记录搜索、全文查看、单条/批量删除、编辑消息和已编辑标记。
- 分离「清空聊天记录」「重新开始关系」「删除角色」，提供明确范围与确认。
- 重置和编辑会使对应静默摘要请求失效；防止旧回复、旧摘要在删除之后回写。
- 数据库保存串行化；附件在保存成功后按引用清理，失败不误删并支持再次保存重试。
- 动态和评论支持编辑/删除；增加梦设删除检查；角色改名同步会话标题。
- 修复首次 DeepSeek 配置默认协议与空配置解析默认值不一致。
- 修复刷新二级页面回到消息首页，以及满值关系的互动次数不增长。
- 默认不植入任何演示数据。既有 V2 数据可读取，只有明确确认的删除/重置操作才改变其范围。
- V2.1 主动消息、关系日历与纪念日尚未交付；原生设备性能和 iOS 构建仍需相应环境验收。


## V2.0.5 更新

- 用户、梦设、角色支持图片头像，头像在联系人、资料、会话与聊天气泡联动显示。
- 图片聊天发送真实图片内容块，OpenAI/Anthropic 兼容，保留最近图片上下文与重试原件。
- 接入 DeepSeek 官方 Search、OCR、ASR、TTS：联网来源、OCR 草稿、PCM 录音转文字、双声线消息朗读。
- 输入栏始终保留加号，不因已有草稿而丢失工具入口；资料支持自定义本地状态。
- 新完整备份包含头像与聊天图片；恢复验证原件并重映射引用，普通数据库不写入 Base64，备份不含密钥。
- 工具超时、取消、重置、切换供应商和清除密钥会停止对应网络请求；校验语音格式和完整性。
- Android 最低 API 23（Android 6.0），使用系统麦克风权限。iOS 麦克风用途文案明确说明 ASR 上传。
- 默认不写入演示数据；大型 ZIP、备份加密、原件语音消息与实时通话仍未交付。

## V2.0.7：供应商配置与联动回归

- 模型目录支持名称/ID 搜索与按需加载，大量模型不再堆满弹层。
- 更换供应商地址需输入对应 Key；原站点的根地址与 `/v1` 仍可复用其已保存密钥。
- 保存/清除供应商配置会停止主聊天流、静默记忆及工具请求，保留已有中断正文并丢弃过期结果。
- 串行处理密钥写入与清除，避免迟到的保存把已清除的密钥写回来；恢复不同供应商或保存方式的备份会清除现有 Key。
- CI 新增真实浏览器中的第三方兼容、模型拉取选择及头像/多模态联动验收，使用隔离的假供应商，不包含真实密钥。

## V2.0.6：第三方聊天兼容修复

- 空流最多追加一次同地址非流式请求；不把推理内容当正文，不缩小用户未指定的输出额度。
- 正确解析多行 SSE、UTF-8 分包、文本内容块与最终完整消息；完整消息不与流式草稿重复拼接。
- 透传并清理流内错误与 HTTP 200 错误对象；502/503/504 提示供应商网关异常。错误文本过滤当前密钥原文。
- 中断保留已有正文并提供重试，取消时中止实际网络请求且不再发起回退。
- 支持第三方 OpenAI 兼容聊天；官方工具能力保持独立，不跨供应商发送凭据。
