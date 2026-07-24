# Building Siren's Bargain

Requires **Godot 4.7** (matches `project.godot`'s `config/features`). All steps
below run from the project root.

## Sanity check first

```
./test.sh                                          # runs the GUT suite
godot --headless -s res://tests/verify_scenes.gd   # loads every scene
```

Both should pass before you attempt an export.

## 1. Install the export templates

Godot needs the export template pack that matches its version. Once:

```
godot --headless --editor -- --install-android-build-template
```

Or open the editor once and go **Editor → Manage Export Templates → Download and
Install**. The bundle covers Android and Web.

## 2. Register export presets

Open the project in the Godot editor and go **Project → Export**. Click
**Add…** and create the two presets below. Godot writes `export_presets.cfg`
in the project root — commit it so future exports pick up your settings.

### Android

- **Platform:** Android
- **Name:** `Android`
- **Runnable:** on
- **Export path:** `build/android/sirens_bargain.apk`
- **Options → Package → Unique name:** `com.<yourorg>.sirensbargain`
- **Options → Package → Name:** `Siren's Bargain`
- **Options → Package → Signed:** debug for local testing (uses the default
  debug keystore Godot generates once); release requires your own keystore.
- **Screen → Orientation:** `Portrait`
- **Screen → Immersive Mode:** on (optional)

Then in the Export dialog: **Export Project…** → pick the APK path.

### Web

- **Platform:** Web
- **Name:** `Web`
- **Runnable:** on
- **Export path:** `build/web/index.html`
- **Options → HTML → Custom HTML Shell:** leave blank unless you want a
  branded page.
- **Options → Progressive Web App → Enable PWA:** on (optional, lets phones
  install it from the browser).

Then: **Export Project…** → pick the `index.html` path.

## 3. Build from the CLI

Once presets exist, subsequent builds don't need the editor UI:

```
mkdir -p build/android build/web
godot --headless --export-debug   "Android" build/android/sirens_bargain.apk
godot --headless --export-release "Web"     build/web/index.html
```

`--export-debug` uses the debug keystore for Android and disables
optimizations; `--export-release` requires signing config for Android but is
what you'd upload.

## 4. Run the outputs locally

- **Android debug APK:** `adb install -r build/android/sirens_bargain.apk`
  then launch **Siren's Bargain** on the device.
- **Web:** the export produces `index.html`, `index.wasm`, `index.pck`, and
  friends. Godot's WASM export needs
  [cross-origin isolation headers][coi] to run, so serve locally with a small
  Python script:

  ```
  python3 -c "from http.server import HTTPServer, SimpleHTTPRequestHandler as H; \
    class C(H):
      def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        H.end_headers(self)
    HTTPServer(('',8000), C).serve_forever()" 
  ```

  ...run from `build/web/`, then open `http://localhost:8000/`.

[coi]: https://developer.mozilla.org/en-US/docs/Web/API/Window/crossOriginIsolated

## 5. Assets & audio

- **Audio:** `SoundEffects` looks up files under `assets/audio/`. See the
  README there for the file names it expects. Missing files are silent
  no-ops, so shipping without audio just plays a quieter game.
- **Card art:** `CardView` and the peek popup render placeholder coloured
  banners. When card art assets are added, wire them into the CardView's
  `_refresh_style` and the CardPeek's body panel.

## Troubleshooting

- **"Cannot resolve unique_name":** you probably renamed a node in a `.tscn`
  but not its `unique_name_in_owner` reference. Load `verify_scenes.gd` to
  catch this at parse time.
- **APK install fails with signature mismatch:** you've swapped debug/release
  keystores; `adb uninstall com.<yourorg>.sirensbargain` first.
- **Web export blank screen:** almost always the cross-origin headers above.
  Use the Python snippet, not plain `python3 -m http.server`.
