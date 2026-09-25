# CyberGuard Mobile — Preview Run Doc

Flutter app (Flutter 3.44.4 at `C:\flutter`). The Preview tab runs the **web** build of the same codebase; Android-only plugins (notification listener, native siren, etc.) degrade gracefully in the browser — the Dashboard and scan UI render fine.

## Reproduce artifacts (fresh checkout)

1. No env files are needed — the project has no `.env`-style secrets.
2. Install dependencies (uses the committed `pubspec.lock`):
   ```
   flutter pub get
   ```
3. The `web/` platform folder is committed; no build artifacts are required for `flutter run`.

## Run the server

```
flutter run --web-hostname 127.0.0.1 --web-port 8090 --device-id web-server
```

- Port **8090** was chosen because the project has no fixed port and 8080 was occupied on this machine.
- First compile can take ~30–60s; the page is ready when the Dashboard ("URL Security / Protection ON") renders.
- Detached (PowerShell, per Freebuff preview recipe): start `C:\flutter\bin\flutter.bat` (Start-Process cannot resolve shell shims) with the args above, `-WorkingDirectory` the repo root, `-RedirectStandardOutput`/`-RedirectStandardError` to **different** files under `.freebuff/`, `-WindowStyle Hidden -PassThru` to capture the pid.
- The `flutter run` process stays attached to its VM; kill it with `Stop-Process -Id <pid>` (or quit the server via `q` if interactive).
