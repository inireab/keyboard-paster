# Keyboard Paster

*På svenska: [README.md](README.md)*

**Blocking paste is not a security feature. It makes security worse.**

Some login forms refuse paste: VPN clients, remote-access portals, banking pages, internal tools. They do it in the name of security, and the effect is the opposite: it locks out the password manager and leaves people with weaker passwords.

## The proof of concept is a prompt

The workaround takes clipboard text and types it into the focused field as real keystrokes. You don't need this repository to get it. **[PROMPT.md](PROMPT.md) is one prompt you can give any AI coding assistant**, for macOS, Windows or Linux, and you get your own version. That's the point: if one prompt gets around it, blocking paste stops nobody.

The prompt also spells out the security rules: no logging, memory only, no network, clear the clipboard.

We tested it. A fresh AI agent that had never seen this code got only the prompt. It wrote a 258-line macOS app that compiled cleanly on the first try, in under five minutes. That test covered building, not typing into a live field; the instance below covers that.

This repository holds one instance: **Keyboard Paster**, a macOS app built with an AI assistant. It works: tested against VPN client login prompts that refuse paste.

![Keyboard Paster's floating keyboard after capturing 20 characters: only the count and time are shown, never the text](kbpaster.png)

This is a workaround, not a fix. The fix is for the vendor to stop blocking paste.

### A legacy to the future

Code ages with its platform. The prompt isn't tied to one: give it to whatever AI assistant exists in five years, for whatever system you use then, and you get a version for that day. Here it is in full, in English so it works with any assistant ([PROMPT.md](PROMPT.md) has the same text to copy):

```text
Build me a small desktop tool for [macOS / Windows / Linux] that types text into fields that refuse paste.

Use the language and APIs native to that platform, with no third-party dependencies. Keep it to one
source file I can read in a few minutes, plus a build script or build instructions.

What it does:
1. A global hotkey captures the current clipboard text into an in-memory buffer, then clears the
   clipboard.
2. A second global hotkey types the buffer into whatever field has focus, as synthetic keystrokes,
   one character at a time. Send characters as Unicode text, not as key codes, so any keyboard
   layout works.
3. Before typing, wait until the hotkey's modifier keys are released, so the typed text doesn't
   turn into shortcuts.
4. Drop trailing newlines from the buffer so typing never submits the form. Inside the text, a line
   break presses Enter and a tab presses Tab.
5. Pause a few milliseconds between keystrokes, because some apps drop keys that arrive too fast.
6. Show a small status window or tray icon with only the number of characters captured and the
   time of capture, never the text itself.
7. Pick hotkeys that don't clash with common shortcuts, and make them easy to change in the source.
   If a hotkey can't be registered because another app owns it, say so in the status display.
8. Keep the buffer after typing, so it can be typed again, until the next capture, an explicit
   "clear" action or quit.
9. Only one instance may run at a time.

Security requirements, because the buffer is usually a password:
- Never log, print or display the buffer's contents. Send stdout and stderr nowhere.
- Keep the buffer only in memory. Never write it to disk, settings or crash reports.
- No network access of any kind.
- If typing needs a special OS permission (for example Accessibility on macOS), say which one and
  why, and request nothing more.

When you're done, explain how to build and run it, which permission it needs, and how to take that
permission away again.
```

## Why blocking paste makes security worse

A field that refuses paste doesn't stop an attacker. It stops the person logging in from using a password manager. People who have to type a password by hand pick one they can type: short, memorable and reused. So the site that blocks paste gets weaker passwords, not stronger ones.

This isn't a fringe opinion. The people who write the rules agree:

- **NIST SP 800-63B-4** (US digital identity guidelines, §3.1.1.2): "Verifiers SHALL allow the use of password managers and autofill functionality. Verifiers SHOULD permit claimants to use the 'paste' function when entering a password." It also notes that password managers "have been shown to increase the likelihood that subscribers will choose stronger passwords." ([source](https://pages.nist.gov/800-63-4/sp800-63b.html))
- **WCAG 2.2, Success Criterion 3.3.8** (Accessible Authentication, Level AA): blocking paste in an authentication field forces people to transcribe a password, and fails the criterion unless another method is offered. ([source](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html))
- **Google Lighthouse** flags "Prevents users from pasting into input fields" as a bad practice, because "password pasting actually *improves* security because it enables the use of password managers." ([source](https://developer.chrome.com/docs/lighthouse/best-practices/paste-preventing-inputs))
- **Troy Hunt** called it "[The 'Cobra Effect' that is disabling paste on password fields](https://www.troyhunt.com/the-cobra-effect-that-is-disabling/)" back in 2014: a measure meant to help security that makes it worse.

The usual reasons given for blocking paste don't hold up:

| Claim | Reality |
|---|---|
| "It stops brute-force attacks." | Attackers don't use your login form's paste function. They script requests directly. Rate limiting and lockout stop brute force; paste blocking doesn't. |
| "The password stays on the clipboard." | Password managers clear the clipboard after a short time, and many fill fields without the clipboard at all. Keyboard Paster clears it right after capture. |
| "People should remember their passwords." | A password you can remember is one an attacker can guess. Long, random, unique passwords need a password manager. |

### It doesn't even stop anyone: AI can build the bypass

Keyboard Paster was written with an AI coding assistant; the commit credits it. Typing text as synthetic keystrokes takes a few system calls, and any AI assistant will write them for whoever asks ([PROMPT.md](PROMPT.md) is all it takes). Whatever barrier paste blocking once was, it's gone.

That changes what paste blocking does. It stops no one who wants to get past it. What it does is push people into one of two outcomes, both worse than paste:

1. **A weak password.** Short enough to type by hand, and usually reused.
2. **An unreviewed helper tool.** Something found online, or something an AI wrote for them a few minutes ago, and then granted Accessibility access: the macOS permission that lets an app read and control other apps, including typing into them. Nobody has reviewed that code.

So blocking paste doesn't close an attack path. It opens one, which makes security worse again. The people it's meant to protect end up handing their most sensitive text to software nobody has audited. Pasting from a password manager was the safer option, and paste blocking took it away.

That applies to this tool too: read the source before you grant it permission.

## What vendors should do

**Is it still 2012?** Troy Hunt called out paste blocking in 2014, and NIST has told verifiers to permit paste since June 2017 ([SP 800-63B, §5.1.1.2](https://pages.nist.gov/800-63-3/sp800-63b.html)).

Allow paste, and mark your fields so password managers can fill them (`autocomplete="current-password"` on the web). In desktop clients, let the password field accept ⌘V and Edit › Paste like any other text field, and don't clear the clipboard behind the user's back.

## What it does

Keyboard Paster shows a small floating keyboard that never takes focus, so your cursor stays in the field you're typing into.

| Shortcut | Action |
|---|---|
| ⌘F | Capture the clipboard text into the buffer, then clear the clipboard |
| ⌘G | Type the buffer as keystrokes into the focused field |

1. Copy the password from your password manager (⌘C).
2. Press ⌘F. You'll hear a "tink", and the panel shows `Captured N characters at <time>`.
3. Click the field that blocks paste and press ⌘G.

The buffer is kept until the next ⌘F, so you can type it repeatedly. When typing:

- Trailing newlines are dropped, so typing doesn't press Enter and submit the form.
- Line breaks inside the text press Enter, and tabs press Tab.

You can also click the on-screen keys directly (Swedish layout). Closing the panel quits the app.

> ⌘F / ⌘G replace Find / Find Next in every app while Keyboard Paster is running.
> To change them, edit `registerHotKeys()` in `KeyboardPaster.swift`. Key codes are `kVK_ANSI_*`; modifiers are `cmdKey`, `optionKey`, `controlKey` and `shiftKey`.

## Build and run

Requires macOS 13 or later and the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/inireab/keyboard-paster.git
cd keyboard-paster
./build.sh                               # builds ~/Applications/KeyboardPaster.app
open ~/Applications/KeyboardPaster.app   # or launch from Spotlight
```

The app is built for your Mac's architecture and signed ad hoc on your machine; there is no prebuilt download. Starting the app quits any copy that's already running.

## Accessibility permission

Typing keystrokes needs **System Settings › Privacy & Security › Accessibility › Keyboard Paster**.

- Launch the `.app` with Finder, Spotlight or `open`. Running the binary inside it from a terminal makes macOS ask for the terminal's permission instead.
- The app is ad-hoc signed, so **every rebuild invalidates the permission**. After a rebuild:

  ```sh
  pkill -x KeyboardPaster
  tccutil reset Accessibility local.kbpaster
  open ~/Applications/KeyboardPaster.app   # approve the prompt, then quit and reopen
  ```

Read the source before you grant that permission. It's one file of about 300 lines, and an app that can type keystrokes can type anything.

## Privacy

The buffer is usually a password, so:

- Nothing is ever logged. There are no log calls, and stdout/stderr go to `/dev/null`.
- The buffer is held only in memory and is never written to disk.
- The panel shows only the character count and the time of the capture.
- The clipboard is cleared right after capture.
- The app makes no network connections.

Two risks remain:

- Clipboard-history tools (Raycast, Alfred, Paste, …) may record the text when you press ⌘C. Most password managers mark their copies so these tools skip them; plain text copied from elsewhere gets no such protection.
- Synthetic keystrokes are visible to any app with keyboard-monitoring permission, exactly like real typing.

## Limitations

This is a proof of concept, not a product.

- macOS only.
- Characters are sent as Unicode text, not as physical key codes. Apps that read key codes instead of characters, such as remote desktop clients and virtual machines, may receive the wrong characters.
- Each character takes a few milliseconds, because some web apps drop keys that arrive too fast. A long text takes a moment.
- Not signed with an Apple Developer ID and not notarized. You build it yourself.

## Files

| File | Purpose |
|---|---|
| `PROMPT.md` | The prompt that builds the tool on any platform |
| `KeyboardPaster.swift` | The whole app (AppKit, Carbon hotkeys, CGEvent typing) |
| `build.sh` | Compiles, creates the `.app` bundle, ad-hoc signs it |
| `kbpaster.png` | Screenshot of the app |

## License

MIT, see [LICENSE](LICENSE).
