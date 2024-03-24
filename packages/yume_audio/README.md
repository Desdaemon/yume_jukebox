# yume_audio

Minimal time-stretching audio player plugin for Flutter.

## Development

Install the version of the Android NDK specified in `android/build.gradle`. Later versions
can be used but are not guaranteed to compile.

Build the project once with Android Studio first. This will generate a `compile_commands.json` file that can be used
to provide completions for clangd.

Create a symlink (or hardlink) to `android/.cxx/Debug/<id>/arm64-v8a/compile_commands.json` to the root of this package:

```powershell
New-Item -Force -ItemType HardLink -Path compile_commands.json -Target (Resolve-Path ".\android\.cxx\Debug\<id>\arm64-v8a\compile_commands.json").Path
```

Or with Bash:
```bash
ln -sf "$(pwd)/android/.cxx/Debug/<id>/arm64-v8a/compile_commands.json"
```

When you make changes to `src/CMakeLists.txt`, remember to also run **Build > Refresh Linked C++ Project** to renew
the contents of `compile_commands.json`.

To regenerate Dart bindings:
```bash
dart run ffigen --config ffigen.yaml
```