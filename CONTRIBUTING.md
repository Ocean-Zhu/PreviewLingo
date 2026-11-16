# Contributing

Run `bash scripts/check.sh` and `bash scripts/build.sh --native` on macOS before submitting changes. Keep the no-automatic-translation behavior: selecting or copying PDF text must not send a request or overwrite the clipboard. Text fields and other applications must retain normal Space behavior.

New providers should reuse one of the supported API formats or add a small, tested adapter. Test request shape, endpoint normalization, key isolation, response parsing, and error handling without real credentials. Do not add provider keys to test fixtures.

The app targets macOS 13+ and avoids external runtime dependencies. User interface changes should use native AppKit controls and remain usable at the minimum window size.
