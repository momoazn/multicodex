# Security Policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Do not open a public issue for security problems.

Report it privately through GitHub:
[Security > Report a vulnerability](https://github.com/momoazn/multicodex/security/advisories/new).

Include:

- What the issue is and what an attacker can do with it
- Steps to reproduce
- MultiCodex version and macOS version

Do not include real auth tokens, `auth.json` contents, or account emails. Use placeholders.

You get a first reply within 7 days. After a fix is released, the advisory is published with credit, unless you ask to stay anonymous.

## Scope

MultiCodex stores Codex CLI auth files on the local disk. Issues of special interest:

- Auth files readable by other users or processes
- Auth tokens written to logs
- One account's auth written into another account's slot
