# Privacy

PreviewLingo has no backend, telemetry, user account, or translation-history database.

With Accessibility permission, it reads the current PDF selection in Apple Preview to determine when the double-Space command applies. It does not record typed keys. Only the shortcut state is retained in memory. Ordinary selection and copying do not initiate network requests.

When you issue a translation command, selected or explicitly copied text is sent directly to your configured API endpoint. Connection testing sends only the literal sample `Hello, world.`. The provider's policies apply to that request. Your API key is sent only to the endpoint to which it is assigned. The app does not follow redirects and requires HTTPS except for local loopback services.

Keys are stored in macOS Keychain. Non-secret preferences, including endpoint URL, model, and target language, are stored in local preferences. Local status in `~/Library/Logs/PreviewLingo/status.json` records permission flags, request counts, and result lengths. It contains no source text, translation text, or credentials.

The clipboard is only written on a successful translation when auto-copy is enabled, or when you explicitly press the result's copy button. The clipboard command reads the text you already copied.

Quitting the app stops the shortcut monitor. Accessibility authorization and login startup can be managed in macOS System Settings. Removing the app does not delete your keys automatically; they can be removed in Keychain Access under `io.github.ocean-zhu.PreviewLingo`.
