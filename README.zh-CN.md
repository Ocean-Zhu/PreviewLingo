# PreviewLingo

原生 macOS 划词翻译软件。选中“预览”里的 PDF 文字，**半秒内连按两次空格**，即可在浮窗中查看译文。

## 安装与使用

1. 从 [Releases](https://github.com/Ocean-Zhu/PreviewLingo/releases) 下载 DMG 或 ZIP，把 **PreviewLingo.app** 放进“应用程序”。
2. 打开 App，在设置里选择服务商、接口地址、模型、目标语言和 API Key。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”里允许 PreviewLingo。
4. 在 macOS 自带“预览”中选中文字，连按两次空格进行翻译。

只选中文字不会翻译。Command+C 仍然复制原文。双空格才会调用 API，成功后可自动复制译文；设置中可以关闭“自动复制译文”。选中 PDF 文字时，空格会保留给翻译快捷键，不会翻页；没有选区时空格照常使用。搜索框、批注输入框和其他应用的空格不受影响。

App 有独立图标、Dock 图标、菜单栏入口和设置窗口，能直接在“应用程序”中找到。菜单栏的“在访达中显示 App”也可以定位安装位置。可设置登录时启动、隐藏 Dock 图标，以及开关双空格翻译。

## API 配置

支持自定义 API 地址和模型，密钥不要求 `sk-` 前缀：

- OpenAI 兼容接口：OpenAI、DeepSeek、OpenRouter、Google Gemini、Ollama 和自定义服务。
- Anthropic Messages 原生接口。
- Qwen-MT 专用翻译接口，包含中国和国际端点预设。

模型名称和服务地址均可修改。软件本身不限制密钥地区，但服务商仍可能有地区、账号和模型权限限制。软件不包含订阅或 API 余额。本地 Ollama 需要另行启动并安装模型。

API Key 只保存在这台 Mac 的钥匙串，不写入源码、安装包或 GitHub。不同接口分别保存密钥，切换地址不会把旧密钥发给新服务。旧版 Qwen Preview Translator 的密钥仅迁移到相同的千问中国接口。

## 开发

需要 macOS 13+、Swift 5.9+ 和 Xcode Command Line Tools。无第三方 Swift 依赖。

```bash
bash scripts/check.sh
bash scripts/build.sh
bash scripts/package.sh
bash scripts/install-local.sh
```

生成的独立 App、DMG、ZIP 和校验文件位于 `dist/`。默认生成支持 Apple Silicon 和 Intel 的通用程序；快速本机构建使用 `bash scripts/build.sh --native`。

首版采用临时签名，未经过 Apple 公证，macOS 可能要求在“隐私与安全性”里点击“仍要打开”。不需要全局关闭系统安全检查。

开源协议：[MIT](LICENSE)。隐私说明：[PRIVACY.md](PRIVACY.md)。
