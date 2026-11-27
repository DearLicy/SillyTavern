# 构建与 GitHub 发布

SillyTavern APP 只通过 GitHub 分发，不上架应用商店。

## 本地约定

- 所有临时文件统一放在仓库内 `.tmp/`；
- 不创建功能分支，直接提交并推送 `main`；
- 构建、签名材料和调试输出不得写入系统 `/tmp`；
- 真实 API Key 不得进入源码、测试、CI 日志或 Release 产物。

## Android

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

产物：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

CI 的调试签名只用于公开测试构建。正式长期更新应配置独立 Android release keystore，并把密钥材料保存在 GitHub Actions Secrets 中。

## iOS 自签

GitHub Release 提供 unsigned IPA。用户可以通过 iLoader、LiveContainer、SideStore 或自己的 Xcode 证书完成签名。

```bash
flutter build ios --release --no-codesign
mkdir -p .tmp/ipa/Payload
cp -R build/ios/iphoneos/Runner.app .tmp/ipa/Payload/
cd .tmp/ipa
zip -qry ../../build/SillyTavern-unsigned.ipa Payload
cd ../..
```

## Web

```bash
flutter build web --release --base-href "/SillyTavern/"
```

GitHub Pages 发布 `build/web`。Web 是完整 BYOK 客户端，但受浏览器本地存储、CORS、麦克风权限和供应商接口差异限制。

## Release 内容

每个 GitHub Release 应包含：

- Android APK 文件；
- `SillyTavern-unsigned.ipa`；
- `SHA256SUMS.txt`；
- 安装与自签说明；
- 版本更新日志；
- Web 构建来源版本。

## V2.2.0：手机端 SillyTavern 重构

- 删除底部三栏导航和动态页；会话首页与角色库成为全屏根入口。
- 删除关系好感/信任/心动/张力、关系阶段、导演模式、场景编辑和安全词面板。
- 角色创建不再强制要求用户人设；未选择人设时自动使用本地用户资料。
- Character Card V2 增加 scenario、mes_example、system_prompt、post_history_instructions、creator notes 等独立字段。
- 角色卡 JSON/PNG 导入导出改为直接保留上述字段，不再压缩进单一 personality/voice 字段。
- 提示词改为 SillyTavern 式优先级：平台安全 > 用户纠正 > 用户人设/全局提示词 > 角色卡 > 世界书 > 记忆 > 历史。
- 角色库改为搜索、标签筛选与角色卡入口，不再展示关系数值。
- 保留角色卡、世界书、Prompt Manager、Chat Completion Preset、正则、宏、记忆、群聊、分支、多模态、Search/OCR/ASR/TTS 与 BYOK。
- 全量 `flutter analyze` 与 `flutter test` 通过后交付。

## 历史兼容

- 旧 V2 数据中的角色、会话、消息、记忆、世界书与附件继续读取。
- 已废弃的 moments、关系数值、导演、场景和同意档案字段不会重新出现在 UI。
- 普通备份不包含 API Key；Web 清理站点数据会删除本地状态，请提前导出备份。
