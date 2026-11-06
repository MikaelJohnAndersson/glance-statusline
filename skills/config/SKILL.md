---
description: Show or change the glance status line's settings for this account (colour, icon)
argument-hint: "[<colour or icon> | colour <name> | icon <name> | reset]"
disable-model-invocation: true
---

Run this command with the Bash tool, passing the user's arguments through as they are:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/config.sh" "${CLAUDE_PLUGIN_DATA}" $ARGUMENTS
```

If it printed the current settings, show them to the user as printed. Otherwise tell the user what it printed, in one or two lines.
