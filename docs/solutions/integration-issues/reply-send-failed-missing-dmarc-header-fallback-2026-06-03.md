---
title: "Reply/Send failed for verified recipient when DMARC allow header was missing"
date: "2026-06-03"
track: "bug"
problem_type: "integration_issue"
category: "integration-issues"
status: "resolved"
module: "mail"
component: "ReceiveEmail reply/send authorization"
tags:
  - "reply"
  - "send"
  - "dmarc"
  - "receive-email"
  - "dns"
  - "regression-test"
---

## Problem

Reply/send attempts from a verified recipient were being rejected with an authentication error even when the sender domain was legitimate.

## Symptoms

- User received **Attempted Reply/Send Failed** notifications.
- Failures occurred when `X-AnonAddy-Dmarc-Allow` was not present on inbound reply/send messages.
- Same sender could be valid, but reply still failed due to single-header gating.

## What Didn't Work

- Relying only on `X-AnonAddy-Dmarc-Allow` as the authorization signal in `ReceiveEmail`.
- No fallback path when that header was absent in this deployment path.

## Solution

Updated `app/Console/Commands/ReceiveEmail.php` to use a layered check:

1. If `X-AnonAddy-Dmarc-Allow` exists, allow as before.
2. If it is missing, fall back to a strict DNS DMARC policy check for the sender domain (`_dmarc.<domain>`).
3. Only allow fallback when DMARC policy is enforcing (`p=quarantine` or `p=reject`).
4. Deny on DNS errors, malformed sender domain, or non-enforcing/no policy.

The same helper check is now reused for unsubscribe authorization logic as well.

Added regression coverage in `tests/Feature/ReplyToEmailTest.php`:
- `it_can_reply_without_dmarc_allow_header_when_sender_domain_policy_fallback_applies`
- fixture: `tests/emails/email_reply_without_dmarc_header.eml`

## Why This Works

This removes the brittle single-header dependency while preserving anti-spoofing behavior. Valid domains with enforcing DMARC can reply/send even if header injection is unavailable, and unsafe/unknown cases still fail closed.

## Prevention

- Keep reply/send auth checks multi-signal (header + secure fallback), not single-signal.
- Keep deny-by-default behavior on DNS lookup failures or invalid sender domains.
- Keep regression tests for missing-header reply/send paths.
- When mail pipeline behavior changes, validate both ingress header signals and fallback auth behavior end-to-end.
