# UX contract

## Ownership and source
The current task defines a read-only LuCI page; LuCI owns navigation, session access, theme, localization and component presentation. The `codex-istore status` contract defines the four installation states and version/platform strings. Account status is outside the page's scope.

## Status flow
The view calls only `luci.codex-istore.status` through a dedicated rpcd plugin. Loading uses LuCI's view lifecycle. Valid results display the state and available version/platform text; malformed responses or RPC failures show a recoverable error. Refresh checks again and disables itself while pending. No state-changing or generic command endpoint is exposed.

## Instruction flow
Show root installation to a mounted volume, then official device-code login and normal use under the same non-root account. Explain that device authentication must be enabled and that the code must remain private. Instructions are static and do not accept or store credentials.

## Canonical UI map
| Capability | Owner | Verification |
| --- | --- | --- |
| Navigation and authorization | LuCI menu and rpcd ACL | package JSON and host integration |
| Status | LuCI rpc declaration and native status text | success/error/refresh states |
| Button and focus | LuCI theme | keyboard and theme runtime check |
| Locale | LuCI gettext and package PO catalog | source/catalog consistency |
| Layout and scrollbar | LuCI theme | host browser at narrow width |
