# 模型与多模态能力

核对日期：2026-11-21。实现依据 DeepSeek 官方 API 文档与官方 `deepseek-ai/chat-demo`，没有复用网页账号、Cookie 或未公开接口。

## 官方依据

- 官方示例：[chat-demo](https://github.com/deepseek-ai/chat-demo)，重点核对 `src/services/api/speech.ts`、录音和朗读流程。
- [识图](https://api-docs.deepseek.com/guides/vision.md)：Chat Completions 用户消息使用 `image_url` 内容块，接受 PNG、JPEG、WebP、GIF 的 data URL。
- [搜索](https://api-docs.deepseek.com/guides/search.md)：`POST /v1/tools/search`，Bearer 鉴权，`query`、`count`、`need_content`。
- [OCR](https://api-docs.deepseek.com/guides/ocr.md)：`POST /v1/tools/ocr`，multipart 的 `file` 与 `purpose=text_recognition`，响应按 `pages[].index` 排序，保留不完整提示。
- [ASR](https://api-docs.deepseek.com/guides/asr.md)：`POST /v1/tools/asr`，multipart PCM WAV，16 kHz/16 bit/单声道。本地录音最多 110 秒，低于供应商 120 秒上限。
- [TTS](https://api-docs.deepseek.com/guides/tts.md)：`POST /v1/tools/tts`，`text`、`voice_id`、`format=wav`、`filter_markdown=true`。提供 Stella/Tide 两种官方声线。

模型仍由真实 `/models` 目录拉取并由用户选择，不写死模型、不伪造模型可用性。识图需要所选模型支持，文本专用模型报错会明确保留在聊天里，用户可换模型后重试。

模型目录可以按名称或 ID 搜索，不一次性创建全部列表控件。更换供应商必须重新填写对应 Key；保存/清除配置会中止聊天、静默记忆及工具任务。恢复不同供应商或密钥保存方式的备份会清除现有 Key，避免将一个站点的凭据发送给另一个站点。

## 产品行为

| 能力 | 入口与联动 |
| --- | --- |
| 用户/用户人设/角色头像 | 资料编辑点击头像 → 相册/拍照 → 本地正方形预览 → 保存。取消不写入附件；移除恢复默认头像。联系人、资料、抽屉、消息列表和气泡显示实际头像。聊天用户侧优先使用绑定用户人设的头像 |
| 图片聊天 | 输入栏加号 → 图片/拍照，确认后发送真实内容块。最近上下文中的图片会重新附带原件，重试不删除原件。数据库只保存本地引用 |
| OCR | 加号或图片消息长按 → 识别图片文字 → 编辑结果 → 填入草稿，不自动发送 |
| 联网 | 加号开启/关闭；发送该聊天时先搜索，再把结果作为不可信引用资料注入。回复附来源入口，来源与搜索意图持久化，重试/重生成保持一致 |
| ASR | 麦克风或加号 → 点击开始 → 结束并转文字 → 填入原有草稿，用户确认再发。离开/关闭面板停止录音；不在后台录制 |
| TTS | 长按文本 → 朗读消息 → 选择声线 → 生成 → 播放/停止。关闭面板停止播放，不把合成文件写进聊天数据库 |
| 完整备份 | 包含所有头像、聊天图片原件及数据，排除密钥。恢复先验证并重映射本地附件引用；旧 V2 JSON 继续兼容 |

联网、OCR、ASR、TTS 目前仅发送到 HTTPS 的 `api.deepseek.com`，使用用户配置的官方 Key。配置第三方聊天服务时不会把其 Key 偷换到官方工具域名；这类工具会提示配置要求。对第三方的 OpenAI/Anthropic 兼容识图仍使用该第三方服务本身。

搜索结果不能覆盖稳定人设、同意边界与系统约束。取消/重置后迟到的搜索不能复活消息。网页来源只允许 HTTP(S)，不打开含 URL 凭据或脚本协议的链接。

API 可能计费；所有联网、OCR、ASR、TTS 都由用户明确触发。不把录音、头像或图片自动发给模型。OCR 一旦文件被服务端接收，断开客户端不代表服务端取消处理或免除供应商计费。

## 本地与隐私

- 头像与图片保存在原生应用目录/浏览器 IndexedDB；日常数据库没有图片 Base64。
- Base64 只在发送识图请求或用户主动导出便携备份时生成。
- 录音在内存中采集 PCM 并封装 WAV，ASR 后丢弃；不创建系统临时音频文件。
- 头像替换、角色/用户人设删除与聊天清理使用统一附件引用检查；共享附件不会误删。
- 完整备份当前以 JSON 复制至剪贴板，附件总量上限 48 MB，超限明确报错；暂未实现大型 ZIP/文件导出。
- 用户安全边界不会因为支持多模态而改变；工具能力与聊天关系隔离。

## 仍未交付

实时语音通话、语音消息原件发送/保存、声线克隆、自动读出、视频、生成式图像、完整 Files API 和服务端自动 Web Tools 调度不属于本次已完成项。当前联网采用独立 Search API + 有来源提示的角色主回复，不声称实现了官方深度搜索的全部自动工具循环。
