---
title: "Inbound catch-all forwarding failed after SMTP acceptance"
date: "2026-06-03"
last_updated: "2026-06-04"
track: "bug"
problem_type: "integration_issue"
category: "integration-issues"
status: "resolved"
module: "mail"
component: "postfix + Azure Communication Services transport"
tags:
  - "azure-container-apps"
  - "postfix"
  - "azure-communication-services"
  - "mail-forwarding"
  - "catch-all"
  - "incident-validation"
---

## Problem

Catch-all inbound mail to `@b.anon.bc3.tech` was accepted by SMTP but did not complete forwarding to destination inboxes.

## Symptoms

- Inbound traffic reached the mail container and messages were processed.
- Forwarded messages were not delivered to recipient mailboxes.
- Postfix showed accepted SMTP sessions but pipe handoff deferred with generic retry errors.
- Laravel logs showed `Undefined variable $from` inside ACS payload construction.
- Earlier in the incident, RCPT checks rejected some senders due to strict reverse-DNS and RBL/RHSBL restrictions.

## What Didn't Work

- Fixing only inbound SMTP rejection behavior in Postfix improved acceptance but did not restore forwarding delivery.
- Re-deploying with only SMTP policy changes left the ACS outbound failure unresolved.
- Using invalid SMTP probe inputs produced false negatives:
  - `HELO debug.local` was rejected (`Helo command rejected: Host not found`).
  - `MAIL FROM:<sender@example.com>` was rejected (`example.com` nullMX).

## Solution

Two linked fixes were required:

1. **Relax false-positive inbound checks in Postfix** (`docker/mail/entrypoint.sh`) by removing strict sender/recipient checks that blocked legitimate internet mail.
2. **Fix ACS sender mapping and sender resolution in forwarded mail payloads** (`app/CustomMailDriver/AzureCommunicationServicesTransport.php`) so payload assembly resolves a concrete `From` address before use, keeps configured sender precedence where required by ACS, and preserves original sender context via `Reply-To`.

Test coverage in `tests/Unit/AzureCommunicationServicesTransportTest.php` now asserts:
- configured-sender precedence and reply-to behavior for forwarded mail
- missing-`From` behavior fails with an explicit transport exception (regression for the `$from` crash path)

Validation after deploy used corrected probe inputs and queue-level tracing:
- Probe with `MAIL FROM:<brandon@bc3tech.net>` and `RCPT TO:<inbound-test@b.anon.bc3.tech>` was accepted and queued as `AAA35AA8E1`.
- Postfix showed `AAA35AA8E1 ... status=sent (delivered via anonaddy service)` and queue removal.
- Recipient receipt was confirmed by the user.

## Why This Works

Inbound and outbound were failing at different layers. Postfix policy changes fixed SMTP acceptance, but ACS still enforces sender identity constraints and requires valid sender payload construction. Resolving `From` explicitly before payload generation removes the undefined-variable failure mode, configured sender usage satisfies provider requirements, and `Reply-To` keeps original sender context for responses.

## Prevention

- Keep a unit test that enforces: configured sender is authoritative for ACS `From`, original sender is preserved in `Reply-To`.
- Keep a unit test that fails if payload assembly can reference an unresolved `From` value.
- Add a deployment smoke test for the full path: inbound SMTP -> alias processing -> ACS forward -> recipient delivery.
- Standardize SMTP verification probes to use a valid FQDN HELO and a sender domain that accepts mail (avoid nullMX test senders).
- Validate successful runs by tracing queue ID to `status=sent`, not only by initial SMTP acceptance.
- When debugging mail flow, split checks by stage (ingress SMTP policy vs egress provider acceptance) to avoid false closure on partial fixes.
