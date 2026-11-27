# SillyTavern V2 架构

## 技术路线

Flutter 负责 Android、iOS、Web 的主 UI 与产品交互。Kotlin/Swift 承担只有平台侧才能可靠提供的能力，例如通知调度、安全存储、生物识别、应用锁、截图保护、文件和音频。

不做三套独立 UI 客户端。体验按真实启动、滚动、输入、转场和后台行为验收，不以是否使用原生控件作为唯一标准。

## 目录

| 目录 | 职责 |
| --- | --- |
| `lib/domain` | 产品实体、枚举和序列化 |
| `lib/application` | Riverpod 应用控制器、状态变更和持久化调度 |
| `lib/data` | SQLite / Web 本地存储、种子数据与密钥存储 |
| `lib/ai` | 提示词装配、记忆检索、SSE 供应商客户端 |
| `lib/router` | 三个根分支与全屏二级路由 |
| `lib/ui` | 设计令牌、共享组件、根页面与详情页面 |
| `lib/platform` | MethodChannel 原生桥接 |
| `android` / `ios` | Kotlin / Swift 原生平台模块 |

## 导航

`StatefulShellRoute.indexedStack` 只包裹：

- `/messages`
- `/contacts`
- `/moments`

聊天、角色、记忆、导演、场景、边界、设置、备份和关于均注册在 Shell 外，从路由结构上保证二级页面没有底部导航。

## 核心类型

- `LocalOwner`
- `UserPersona`
- `Character`
- `Relationship`
- `ChatThread`
- `Message`
- `MemoryItem`
- `SceneState`
- `DirectorConfig`
- `ConsentProfile`
- `Moment`
- `ProviderConfig`
- `AppData`

`ChatThread` 当前只开放单聊，但已经使用参与者列表和关系绑定，为 V2.2 群聊保留稳定结构。

## 提示词优先级

1. 不可覆盖的平台安全规则；
2. 用户硬边界、允许/禁止主题、安全词和暂停状态；
3. 梦设与角色稳定人设；
4. 关系状态与数值；
5. 当前场景和导演设置；
6. 固定与检索记忆；
7. 当前会话的剧情连续性备忘；
8. 最近消息；
9. 本轮用户输入。

任何角色设定、场景亲密程度或导演指令都不能覆盖第 1、2 层。

## 记忆检索

V2.0 不引入向量数据库。检索顺序：

1. 边界记忆；
2. 固定记忆；
3. 与当前输入有词项重合的记忆；
4. 最近记忆。

原生 SQLite 同时维护 `memory_fts` 虚拟表，为后续搜索 UI 提供 FTS5 基础。

每个 `ChatThread` 另存独立的 `contextMemo` 和 `summarizedThroughMessageId`。每段对话累积到 12 条未整理消息后，在一次正常回复完成后客户端以同一 BYOK 供应商发起独立、非流式的静默整理请求；一次最多整理 16 条旧消息，并保留最近 8 条原文。它不显示在聊天里、不阻塞主回复，也不会在应用关闭后调用模型。工作记忆在摘要尚未建立前最多保留 24 条，稳定后回到最近 8 条原文（约 4 轮），避免摘要未返回时旧内容先从提示中消失。成功后摘要与覆盖游标一起写入本地数据，并在之后的主请求系统提示中使用。原消息不删除；摘要失败、空返回或会话重置都不会覆盖上一份有效备忘。

事实记忆只接受模型从输入消息 ID 中明确引用的来源；用户信息必须来自用户消息，用户边界只能由用户手动创建。自动整理对已有事实做增量合并，不静默清除用户已保存的记忆。记忆整理结果不回显到聊天；用户可以在关系记忆页查看、编辑或删除。

## 关系结算

成功回复后，`RelationshipDynamics` 根据本轮用户表达、图片事件和是否分享真实近况结算四项数值。正常交流至少会推动一项，冷淡回应会增加张力而不刷好感，恶意表达会降低好感并显著提高张力。数值越高增长越慢，综合分数决定关系阶段。`lastMetricDelta`、`lastMetricReason` 和 `interactionCount` 随关系持久化，关系页可直接查看。同一条用户消息重新生成不会重复结算。

## 重复回复防护

`RepetitionGuard` 对最近 6 条角色回复做归一化和字符二元组相似度比较；短句只拦截完全重复，长回复同时拦截高度相似的句式和内容。命中后使用同一 BYOK 供应商静默重写一次，只有明显不同的结果才会替换原回复。提示词同时列出最近 4 条角色表达作为“不要复用”的负空间。

摘要请求会把尚未整理的历史片段发送给用户当前配置的模型供应商；摘要不是只在设备上的模型推理。原始会话及摘要结果留在本地，原消息不因归纳而删除。

## 持久化

原生端当前使用 `sqflite` 保存版本化 `AppData` JSON 和 FTS5 记忆索引。Web 使用浏览器本地存储。

聊天图片通过独立 `AttachmentStore` 保存：原生端写入应用支持目录，Web 写入 IndexedDB。消息只保存不透明附件引用，避免把图片 Base64 塞进 SQLite/SharedPreferences。清空本地数据时同步清理附件库。

V2.0.2 计划在原生端接入 SQLCipher，并把应用锁、数据库密钥和截图保护统一到原生安全模块。当前 API Key 已在原生端进入系统安全存储，普通备份不包含密钥。

## AI 供应商

当前支持：

- OpenAI Chat Completions 兼容接口；
- Anthropic Messages 接口；
- SSE 流式增量；
- OpenAI 兼容流可识别 `delta.content`、完整 `message.content`、普通 JSON 回包和只包含 `reasoning_content` 的推理模型；
- OpenAI 兼容聊天默认省略 `max_tokens`，长度由提示词规划而非正文截断控制；
- 供应商配置可控制温度、Top P、频率/存在惩罚、最大输出 Token 和停止序列；OpenAI 兼容接口使用 `stop`，Anthropic 使用 `stop_sequences`，未配置的可选参数不会发送；
- 错误统一收束为角色消息与可见错误提示。

请求路径：

```text
AppData + ChatThread + User input
      ↓
ContextAssembler
      ↓
Provider-specific SSE client
      ↓
Streaming Message updates
```

## 性能原则

- 聊天列表只渲染可显示消息；
- 空消息在进入控制器前过滤；
- 根页面使用分支状态保持；
- 动态与长列表使用 Sliver；
- 流式更新只改当前消息；
- 键盘使用 `resizeToAvoidBottomInset`，输入区固定安全区；
- 所有网络请求异步，不阻塞主线程持久化。

## 原生桥

当前 `com.dearlicy.sillytavern/platform` 提供：

- `platformName`；
- `setSecureScreen`。

Android 已启用 `FLAG_SECURE`。iOS 快照隐私遮罩、通知、生物识别、录音和本地生活调度按版本接入。


## 局部数据操作与一致性（2026-11-21）

`DataManagement` 是 `AppController` 同一 library 的扩展，复用单一状态与持久化队列。清空、重新开始、单条/批量编辑删除、角色删除使用同一条数据写入路径；所有数据库保存串行化，避免旧流式快照覆盖已经删除的新状态。

每个 thread 有内存中的 revision。修改记录、清空或重置前递增 revision 并中止该 thread 的生成与摘要；静默请求回写前验证生命周期、revision 和 abort，防止删除后旧摘要再次写入。重新生成也复用记录失效逻辑，不能把废弃的上一版回复保留在摘要里。关系结算按用户消息 ID 去重，编辑、重试和重生成不会重复加分；完成互动次数与指标是否达到上限分开计数。

消息增加可选 `editedAt`，旧 V2 JSON 可继续读取。修改正文不改变消息 ID、发送时间或图片引用。手动更正/删除记录后清空该会话的派生摘要和自动记忆，保留手动记忆，并解除被改动来源的引用。保留原始记录后可由后续正常回复重新触发静默归纳，前台不额外请求模型。

附件先保存引用变更再删除文件/IndexedDB 项，仍有引用的附件保留。保存失败时不删除附件；清理失败单独提示并在后续成功保存时重试。本次附件删除重试队列为运行期状态，进程异常退出后的孤儿文件扫描尚未实现。

启动、成年确认和正式应用共用同一个 `MaterialApp.router`；加载时保留初始 deep link，防止 Web 刷新二级页面回到消息首页。数据管理、记录搜索等二级页面依然在 Shell 外。


## V2.0.5 头像与多模态

`OwnerProfile`、`UserPersona`、`Character` 增加可空 `avatarReference`；读取旧 V2 数据默认没有头像。`DtAvatar` 通过应用已有附件仓库加载，所有引用汇总在 `AppData.attachmentReferences`，替换、删除与导入使用同一引用清理规则。选择头像时只在本地编辑器裁切预览，保存才写附件。重置期间迟到的资料写入被生命周期代数拒绝。

`PromptMessage` 同时保留纯文字与可选图片引用，在发送前由控制器读取并探测图片内容，编码为 OpenAI `image_url` 或 Anthropic `image`，不持久化 Base64。原始图片缺失明确报错，不声称模型已看图。整轮内联内容限制在供应商请求上限以下。

`DeepSeekTools` 使用独立官方 Search/OCR/ASR/TTS endpoint，Bearer 鉴权，只接受配置为 HTTPS 官方域的工具请求。工具统一使用可中止 HTTP request、响应字节上限、总期限和无密钥的错误文本；取消面板、清除 Key、恢复与重置使迟到数据失效。搜索结果作为不可信引用进入本轮提示，`Message.sources` 和 `searchWeb` 保存来源和重试意图。

`record` 的 PCM 流在内存封装 WAV，`audioplayers` 播放合成 WAV。两者在 Android/iOS 采用原生平台实现，Web 使用浏览器权限与音频能力；不把录音写到系统临时目录。前后台切换取消正在录制的输入。

`sillytavern.media.v1` 完整备份包装原有 V2 数据与有大小限制的本地图片，恢复时先校验再写新引用，只重映射已知媒体字段。它是明文可携带备份；备份加密和大型文件打包未实现。
