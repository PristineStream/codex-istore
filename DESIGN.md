# Design context

## Product and audience
A LuCI administration page for router owners who install Codex CLI on mounted storage and use it through SSH. Its job is to show installation status and explain the next steps without presenting a remote command console.

## Visual direction
Use the host LuCI theme and its native view, `cbi-map`, `cbi-section`, and button styles. Typography, colors, focus indicators, scrolling, and responsive layout belong to the active theme; this package introduces no duplicate design tokens or global CSS. The distinctive element is a short, ordered SSH setup path beneath the actual installation status.

## Content and accessibility
Use concise, translatable source strings and a Simplified Chinese catalog. Use semantic headings, a real button, ordered instructions and a polite status announcement. Code examples must stay selectable and must not imply that installation status is an account login check. Avoid additional animation and preserve host theme behavior.
