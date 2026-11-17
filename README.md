# Amader Bangla Keyboard — macOS

Type **Bangla phonetically** on your Mac: `amar sOnar bangla` → আমার সোনার বাংলা.

This is the macOS version of
[Amader Bangla Keyboard for Windows](https://github.com/amerganim/WindowsBanglaKeyboard),
with the **same phonetic engine, same key map, same word suggestions**.
It is a native macOS input method (InputMethodKit), so it works in every app —
Pages, Word, Safari, Chrome, Notes, Messages, Terminal, VS Code…

**Free and open source (MIT).** No account, no ads, no tracking.

🌐 **Website:** https://amerganim.github.io/MacOSBanglaKeyboard/ ·
📖 **Typing guide:** https://amerganim.github.io/MacOSBanglaKeyboard/guide.html

## Install

### Option 1 — one command (recommended)

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/amerganim/MacOSBanglaKeyboard/main/scripts/install.sh | bash
```

No admin password needed. It installs into `~/Library/Input Methods`.

### Option 2 — Homebrew

```bash
brew install --cask amerganim/tap/amader-bangla-keyboard
```

### Option 3 — installer package

Download `AmaderBanglaKeyboard-x.y.z.pkg` from the
[latest release](https://github.com/amerganim/MacOSBanglaKeyboard/releases/latest)
and double-click it.

> Because this free app is not signed with a paid Apple Developer certificate,
> macOS will say it *"cannot verify the developer"*. Click **Done**, then open
> **System Settings → Privacy & Security**, scroll down and click
> **Open Anyway** next to the message about the package. (Options 1 and 2 avoid this.)

### Last step — add it to your input sources (once)

macOS requires you to do this yourself:

1. **System Settings → Keyboard → Text Input → Input Sources → Edit…**
2. Click **+**, choose **Bangla**, select **Amader Bangla Keyboard**, click **Add**.
3. Switch to it from the input menu in the menu bar, or with the 🌐 **Globe** key /
   **Control+Space**.

If it isn't listed yet, log out and back in once.

## How to type

The scheme is **case-sensitive** (`t` = ত, `T` = ট). Type a word, then
**Space** to commit it.

| You type | You get |
|---|---|
| `ami tOmake valObasi` | আমি তোমাকে ভালোবাসি |
| `bangladesh` | বাংলাদেশ |
| `kShoma` | ক্ষমা |
| `sundor` | সুন্দর |
| `ca^d` | চাঁদ |
| `du:kh` | দুঃখ |
| `korm`, `bidza` | কর্ম, বিদ্যা |
| `2026` | ২০২৬ |
| `.` | । |

- **Control+Shift+B** — switch between Bangla and English.
- **Word suggestions** appear under the word as you type: **↓ / ↑ / Tab** to move,
  **Space** or **Enter** to pick, **Esc** to hide, or click one. It learns the
  words you pick.
- **Enter** commits the word (press it again for a new line).
- Full guide: [docs/KEYMAP.md](docs/KEYMAP.md), also in the input menu →
  **Typing Guide…**

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/amerganim/MacOSBanglaKeyboard/main/scripts/uninstall.sh | bash
```

Then remove it from System Settings → Keyboard → Input Sources.

## Build from source

Only the free **Xcode Command Line Tools** are needed (`xcode-select --install`):

```bash
make test       # engine unit tests
make            # build/AmaderBanglaKeyboard.app (Apple Silicon + Intel)
make install    # install for your user
make dist       # release zip + pkg in dist/
```

Releases are built automatically by GitHub Actions when a `v*` tag is pushed
(`git tag v1.0.2 && git push origin v1.0.2`). After the release appears, run
`./scripts/update-tap.sh 1.0.2` to update the Homebrew cask. The website in
`site/` is deployed to GitHub Pages on every push to `main`.

## How it works

```
engine/     Portable C++17 phonetic engine (shared with the Windows version)
mac/        InputMethodKit input method (Objective-C++)
resources/  Word lists, typing guide, icons
tests/      Engine unit tests + an end-to-end IME smoke test
scripts/    install / uninstall / package / update-tap
site/       The website (GitHub Pages); guide.html is resources/KEYMAP.html
```

`engine/` is copied unchanged from the Windows repository, so both keyboards
type exactly the same way. The macOS layer (`mac/BKInputController.mm`) mirrors
the Windows TSF text service: it buffers the romanized keys, shows the Bangla
as underlined marked text, and commits on Space/Enter.

The bundled `words.tsv` is derived from
[google/language-resources](https://github.com/google/language-resources) (bn),
licensed **CC BY 4.0**.

## License

MIT — see [LICENSE](LICENSE).
