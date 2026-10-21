# The prompt

Give this to any AI coding assistant. Replace the operating system in the first line with yours.

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

Before you grant the result any permission, read the code it wrote. The requirements above make a safer tool more likely, not certain.
