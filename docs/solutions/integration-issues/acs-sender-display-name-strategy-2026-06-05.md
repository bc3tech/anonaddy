---
title: "ACS sender display name strategy for forwarded mail"
date: "2026-06-05"
last_updated: "2026-06-05"
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
  - "display-name"
  - "inbox-presentation"
  - "smtp-authentication"
---

## Context

Forwarded mail through ACS delivered successfully, but the inbox card did not look as friendly as addy.io. The question was whether ACS SMTP auth, sender-username resources, or message headers could make the visible sender look more like the original sender.

## Guidance

ACS SMTP username is for authentication only. The visible sender name comes from the ACS `MailFrom` / `sender-username` resource, and that display name is managed at the resource level.

Use a stable, neutral sender resource with a friendly display name, and keep the original sender in `Reply-To`.

```php
$from = new Address(config('mail.from.address'), 'AnonAddy Relay');
$replyTo = new Address($originalSenderEmail, $originalSenderName);
```

If a per-alias or per-message display name is required, ACS does not provide that directly. Trying to vary SMTP credentials or connection strings will not change the inbox presentation.

## Why This Matters

This separates what ACS can control from what the mail client renders. It avoids chasing sender-name tricks that ACS will ignore, and it keeps the forwarding path cheap and deliverable.

## When to Apply

Use this pattern when:

- forwarding alias mail through ACS
- trying to make inbox cards look more user-friendly
- deciding whether SMTP auth can change visible sender identity

Do not use it when you need per-message sender identity customization. ACS sender display names are not a dynamic runtime feature.

## Examples

**Good**

- `AnonAddy Relay <forwarded-by@anon.bc3.tech>`
- original sender preserved in `Reply-To`

**Not effective**

- changing the ACS SMTP username to try to influence the inbox card
- setting a different sender name per forwarded message and expecting ACS to render it

## Related docs

- `docs/solutions/integration-issues/inbound-catchall-forwarding-acs-sender-2026-06-03.md`

---

_Last updated: 2026-06-05 by Copilot_
