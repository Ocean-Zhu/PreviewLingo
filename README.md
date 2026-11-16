<p align="center"><img src="Resources/AppIcon.png" width="112" alt="PreviewLingo icon"></p>

# PreviewLingo

A native, open-source macOS companion for Apple Preview. Select PDF text, press **Space twice**, and read the translation in a floating window.

[中文说明](README.zh-CN.md) · [Downloads](https://github.com/Ocean-Zhu/PreviewLingo/releases) · [MIT License](LICENSE)

## Use

1. Install **PreviewLingo.app** in Applications and open it.
2. Choose your provider, API endpoint, model, target language, and API key in Settings.
3. Allow PreviewLingo in **System Settings → Privacy & Security → Accessibility**.
4. Select text in a PDF opened with **Apple Preview**, then press Space twice within half a second.

Selecting text alone never sends a translation request. **Command+C continues to copy the original text.** Successful translations can be copied automatically or with the copy button. Auto-copy can be disabled in Settings. Spaces in search fields, annotations, and other apps are left alone. Without a text selection, Space retains Preview's normal behavior. With a PDF selection, Space is reserved for the shortcut and does not scroll the page.

The app has a Dock icon, a menu bar menu, a normal settings window, and a Finder-visible application bundle. Dock visibility and login startup are configurable. A clipboard command and a macOS Services command are also available.

## Providers

API keys are not restricted to a particular vendor or prefix. Enter the endpoint and model available to your account.

| Format | Included presets |
| --- | --- |
| OpenAI-compatible Chat Completions | OpenAI, DeepSeek, OpenRouter, Google Gemini, Ollama, custom endpoints |
| Anthropic Messages | Anthropic, compatible custom endpoints |
| Qwen-MT translation | Alibaba Cloud China and international endpoints |

All preset URLs and model IDs can be edited. Models, regional availability, and account permissions are controlled by the provider. A preset is a starting configuration, not a bundled subscription or a guarantee that a service is available in every country. Ollama requires a running local server and an installed model.

Protocol references: [OpenAI](https://platform.openai.com/docs/api-reference/chat/create), [Anthropic](https://platform.claude.com/docs/en/api/messages/create), [Gemini compatibility](https://ai.google.dev/gemini-api/docs/openai), [DeepSeek](https://api-docs.deepseek.com/api/create-chat-completion/), [OpenRouter](https://openrouter.ai/docs/quickstart), [Qwen-MT](https://help.aliyun.com/en/model-studio/machine-translation).

## Build

Requires macOS 13 or later and Xcode Command Line Tools with Swift 5.9 or newer. There are no external Swift packages.

```bash
bash scripts/check.sh
bash scripts/build.sh          # Apple Silicon + Intel universal app
bash scripts/package.sh        # DMG, ZIP, and SHA-256 checksums
```

For a faster local build, use `bash scripts/build.sh --native`. The app is written to `dist/PreviewLingo.app`. Run `bash scripts/install-local.sh` to install it locally. That script migrates the earlier Qwen Preview Translator helper, preserving its app and login item in a local backup. It never embeds your key in the build.

GitHub Actions builds and tests the universal app on macOS for pushes and pull requests. Built artifacts are available from the workflow run.

The check script runs dependency-free core checks with Command Line Tools, and also runs the XCTest suite when full Xcode is installed.

## Privacy

- API keys are stored only in the macOS Keychain, separately for each endpoint and protocol.
- Keys from the earlier helper can only be reused with the matching Qwen-MT China endpoint.
- Text is sent directly to the configured provider only after a translation command. No complete PDF upload is performed.
- No analytics, accounts, relay server, translation history, or keyboard logging.
- Remote endpoints require HTTPS; HTTP is allowed only for loopback hosts. Redirects are not followed.
- Local diagnostic status contains counts and permission flags, never source text, translated text, or API keys.

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Distribution

The first community build is ad-hoc signed, **not Apple-notarized**. macOS may ask you to allow it in **Privacy & Security → Open Anyway**. Do not disable Gatekeeper globally. Developers distributing a notarized build should sign it with their own Developer ID before notarization.

The original icon was generated specifically for this project. It references document inspection and translation, and does not include Apple's Preview artwork. See [artwork notes](Resources/ARTWORK.md).

PreviewLingo is an independent project and is not affiliated with or endorsed by Apple. Apple Preview and macOS belong to Apple.
