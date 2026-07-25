---
title: "Separating sender address (MAIL_FROM_ADDRESS) from reply routing (Reply-To)"
date: "2026-06-05"
track: "knowledge"
problem_type: "integration_issue"
category: "integration-issues"
status: "resolved"
module: "mail"
component: "Azure Communication Services transport"
tags:
  - "azure-communication-services"
  - "mail-forwarding"
  - "sender-identity"
  - "MAIL_FROM_ADDRESS"
  - "reply-to"
  - "azd"
  - "azure-container-apps"
  - "inbox-presentation"
---

## Context

After setting the ACS sender-username display name to "AnonAddy Relay" (covered in
`acs-sender-display-name-strategy-2026-06-05.md`), the next request was to change the
visible FROM address itself to `reply-to-sender@anon.bc3.tech`. This required understanding
which config controls the address portion of `From:` versus which mechanism controls where
replies actually land — two orthogonal concerns that are easy to conflate.

Additionally, applying the live update exposed a deployment gotcha: `azd` remote build failed,
requiring the Container App env var to be updated directly.

## Guidance

**From address and Reply-To serve different purposes and must not be conflated.**

- `MAIL_FROM_ADDRESS` (and its companion `MAIL_FROM_NAME`) controls the sender identity —
  what the recipient sees in their inbox as `From: AnonAddy Relay <reply-to-sender@anon.bc3.tech>`.
  This is purely presentational.

- `Reply-To` header controls where replies are routed. It should continue to point at the
  original sender so that replies reach the alias owner, not the forwarding infrastructure.

Changing `MAIL_FROM_ADDRESS` has zero effect on reply routing. Reply-To remains the mechanism
for that entirely regardless of what address appears in `From:`.

To change the visible FROM address, update the env var:

```
MAIL_FROM_ADDRESS=reply-to-sender@anon.bc3.tech
MAIL_FROM_NAME="AnonAddy Relay"
```

### Applying the change when azd remote build fails

`azd up` with remote build can fail (build pipeline errors unrelated to the env change).
When that happens, update the Container App env var directly without a redeploy:

```bash
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --set-env-vars MAIL_FROM_ADDRESS=reply-to-sender@anon.bc3.tech
```

The app picks up the new value on the next request without a full redeploy. Sync the azd
env afterward so state stays consistent:

```bash
azd env set MAIL_FROM_ADDRESS reply-to-sender@anon.bc3.tech
```

## Why This Matters

Conflating `From` address with `Reply-To` routing leads to one of two failure modes:

1. Changing `MAIL_FROM_ADDRESS` expecting it to fix reply behavior — it won't.
2. Changing `Reply-To` expecting it to change the inbox-visible sender — it won't.

Each layer controls exactly one thing. Keeping them separated makes the system predictable
and keeps reply behavior stable when sender identity is updated for presentation reasons.

## When to Apply

- Changing the visible FROM address for inbox presentation (branding, clarity)
- Debugging why replies go to the wrong address after a sender-identity change
- Applying any env var update to a live Container App when `azd` remote build is unavailable

## Examples

**Correct separation**

```php
// From: presentational — controlled by MAIL_FROM_ADDRESS / MAIL_FROM_NAME
$from = new Address(config('mail.from.address'), config('mail.from.name'));

// Reply-To: routing — always points at the original sender
$replyTo = new Address($originalSenderEmail, $originalSenderName);
```

**What the recipient sees**

```
From:    AnonAddy Relay <reply-to-sender@anon.bc3.tech>
Reply-To: Alice <alice@example.com>
```

Hitting "Reply" in any mail client routes to Alice, not to the relay address.

## Gotchas

- `azd` remote build failures are unrelated to env var changes. A direct Container App
  update via `az containerapp update --set-env-vars` is safe and does not require a redeploy.
  Always follow up with `azd env set` to keep the azd state in sync.
- `MAIL_FROM_ADDRESS` must match a verified sender domain in ACS. Using an address on an
  unverified domain will cause delivery failures.

## Related docs

- `docs/solutions/integration-issues/acs-sender-display-name-strategy-2026-06-05.md` — display name configuration at the ACS sender-username resource level
- `docs/solutions/integration-issues/inbound-catchall-forwarding-acs-sender-2026-06-03.md` — ACS sender setup for inbound forwarding

---

_Last updated: 2026-06-05 by Copilot_
