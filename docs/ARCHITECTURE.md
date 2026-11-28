# SillyTavern APP 架构

## 技术路线

Flutter 负责 Android、iOS、Web 的主 UI 与产品交互。Kotlin/Swift 承担系统安全存储、通知、生物识别、应用锁、截图保护、音频和文件等平台能力。

产品不复制三套独立客户端。验收以真实启动、滚动、输入、转场、后台行为和构建产物为准，而不是以是否使用原生控件作为唯一标准。

## 目录

| 目录 | 职责 |
| --- | --- |
| `lib/domain` | 角色、角色卡、会话、消息、记忆、世界书与序列化 |
| `lib/application` | Riverpod 控制器、数据管理、生成、记忆与持久化调度 |
| `lib/data` | SQLite / Web 本地存储、附件、角色卡、世界书、Preset 与密钥存储 |
| `lib/ai` | 上下文装配、宏、正则、记忆检索、重复防护与 SSE 客户端 |
| `lib/router` | 根页面与全屏二级路由 |
| `lib/ui` | 设计令牌、共享组件、会话、角色库与管理页面 |
| `lib/platform` | MethodChannel 原生桥接 |
| `android` / `ios` | Kotlin / Swift 原生平台模块 |

## 导航

应用只有两个全屏根入口：

- `/`：会话首页；
- `/characters`：角色库。

两者都没有常驻底部导航。聊天、角色资料、角色卡管理、世界书、提示词、记忆、设置与备份均使用全屏二级路由。旧版的联系人、动态和根级消息地址不再注册，避免已废弃产品结构重新进入导航或深链。

## 核心类型

- `OwnerProfile`
- `UserPersona`
- `Character`
- `Relationship`：仅保存角色、可选用户人设、会话绑定与回复能量；
- `ChatThread`
- `Message`
- `MemoryItem`
- `WorldBook` / `WorldInfoEntry`
- `PromptConfig` / `PromptBlock`
- `ProviderConfig`
- `AppData`

`Relationship` 不是用户可见的关系数值。它没有好感、信任、心动、张力、场景导演或同意档案字段，只用于把角色卡和会话安全绑定起来。

`ChatThread` 支持参与者列表、消息分支、滚动摘要、宏变量与群聊。所有角色卡都会保存为标准 Character Card V2 字段，旧版自定义字段继续兼容读取。

## 提示词优先级

1. 不可覆盖的平台安全约束；
2. 用户本轮明确纠正与停止要求；
3. 用户人设、全局系统提示词与 Prompt Manager 条目；
4. Character Card 字段；
5. 世界书、作者注记与 post-history instructions；
6. 固定与检索记忆；
7. 会话连续性摘要；
8. 最近消息；
9. 本轮用户输入。

Prompt Manager 支持命名提示词块、System/User/Assistant 角色、角色卡前后、历史前和消息深度注入。条目只保存声明式文本，不执行脚本。任何角色卡、世界书、preset、提示词块或记忆都不能覆盖第 1、2 层。Character Card 的 `system_prompt` 和 `post_history_instructions` 被保留为高优先级风格约束，但不是平台安全约束的替代品。

## 记忆检索

不引入本地向量数据库。检索顺序：

1. 用户边界；
2. 固定记忆；
3. 与当前输入存在词项重合的记忆；
4. 最近记忆。

SQLite 保存 FTS5 索引。每个 `ChatThread` 另存 `contextMemo`、`summarizedThroughMessageId` 和宏变量。正常回复完成后，应用可使用同一 BYOK 供应商发起一次独立、非流式、可取消的摘要请求。摘要失败不会覆盖上一版有效结果，也不会删除原消息。

自动事实必须引用输入中真实存在的消息 ID；用户边界不能由自动整理新增或覆盖。

## 会话与数据管理

`DataManagement` 与 `AppController` 共享单一状态和串行持久化队列。清空、重新开始、编辑、删除、分支和角色删除都走统一写入路径，并递增 thread revision 使迟到的流式文本、摘要或工具结果失效。

附件先完成引用变更并成功保存，再删除无引用文件。共享附件不会被单条消息删除误伤。清空应用时同时清理本地数据、附件仓库和已保存密钥。

## 重复回复防护

`RepetitionGuard` 对最近角色回复做归一化和字符二元组相似度比较。命中后使用同一供应商静默重写一次；最近表达同时作为负空间注入提示词。内部重写过程不显示在聊天中。

摘要与重写请求都会把必要的聊天片段发送给当前供应商。原始消息和派生结果保存在本地。

## 持久化

- 原生端：`sqflite` 保存版本化 `AppData` JSON 和 FTS5 记忆索引；
- Web：浏览器本地存储保存应用状态；
- 聊天图片：原生端应用私有目录，Web 使用 IndexedDB；
- 消息只保存不透明附件引用，不把图片 Base64 写入主数据库；
- API Key：原生端系统安全存储，Web 默认会话存储或用户明确选择持久化。

## 供应商客户端

支持：

- OpenAI Chat Completions 兼容；
- Anthropic Messages；
- DeepSeek 官方；
- SSE、完整 JSON、文本内容块与常见推理模型响应；
- 空流一次非流式兼容回退；
- 温度、Top P、频率/存在惩罚、输出 Token 和停止序列；
- Chat Completion Preset 导入与真实 `/models` 目录拉取。

错误统一清洗并过滤当前密钥原文。更换供应商、清除 Key、恢复备份和重置会使旧的聊天、工具和摘要请求失效。

## 性能原则

- 会话和角色列表使用 Sliver；
- 聊天只渲染可显示消息；
- 流式更新只修改当前消息；
- 空内容和协议残留不进入 UI；
- 键盘输入区使用安全区和 `resizeToAvoidBottomInset`；
- 根页面没有常驻底栏，减少小屏永久占位；
- Web 首屏只加载按界面文案裁剪的 WOFF2 字体，生僻字由运行时字体回退处理；
- 网络请求异步，不阻塞主线程持久化。

Web 字体可按以下方式重建：

```bash
pip install 'fonttools[woff]'
tool/update_web_font.sh /path/to/NotoSansSC-VF.ttf
```

## 原生桥

当前 `com.dearlicy.sillytavern/platform` 提供：

- `platformName`；
- `setSecureScreen`。

Android 已启用 `FLAG_SECURE`。更完整的应用锁、通知、生物识别和后台生命周期能力按路线图接入。
