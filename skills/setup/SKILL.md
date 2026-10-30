---
description: Turn on the glance status line by pointing the user's statusLine setting at it
disable-model-invocation: true
---

Run this command with the Bash tool:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" "${CLAUDE_PLUGIN_ROOT}" "${CLAUDE_PLUGIN_DATA}"
```

Then tell the user the result in one or two lines.

- If it printed `EXISTING`, the user already has a status line. Show them the command it runs and ask whether to replace it. Only if they say yes, run the same command again with `--replace` added as a third argument.
- If it says jq is missing, pass on the install hint and stop.
- On success, add that the icons need a Nerd Font in the terminal, that `/glance:detail` toggles the detail row, and that the `?` at the end of the first row (⌘-click or Ctrl-click) opens a cheat sheet.
