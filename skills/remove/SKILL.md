---
description: Turn off the glance status line by removing it from the user's statusLine setting
disable-model-invocation: true
---

Run this command with the Bash tool and tell the user what it printed, in one or two lines:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/remove.sh" "${CLAUDE_PLUGIN_DATA}"
```

If it removed the status line, mention they can now uninstall the plugin with `/plugin`.
