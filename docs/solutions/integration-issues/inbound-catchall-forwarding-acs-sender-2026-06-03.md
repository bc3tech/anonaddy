---
title: "Inbound catch-all forwarding failed after SMTP acceptance"
date: "2026-06-03"
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
---

## Problem

Catch-all inbound mail to `@b.anon.bc3.tech` was accepted by SMTP but did not complete forwarding to destination inboxes.

## Symptoms

- Inbound traffic reached the mail container and messages were processed.
- Forwarded messages were not delivered to recipient mailboxes.
- Earlier in the incident, RCPT checks rejected some senders due to strict reverse-DNS and RBL/RHSBL restrictions.

## What Didn't Work

- Fixing only inbound SMTP rejection behavior in Postfix improved acceptance but did not restore forwarding delivery.
- Re-deploying with only SMTP policy changes left the ACS outbound failure unresolved.

## Solution

Two linked fixes were required:

1. **Relax false-positive inbound checks in Postfix** (`docker/mail/entrypoint.sh`) by removing strict sender/recipient checks that blocked legitimate internet mail.
2. **Fix ACS sender mapping for forwarded mail** (`app/CustomMailDriver/AzureCommunicationServicesTransport.php`) so `senderAddress()` always uses the configured sender address when present, while preserving the original sender in `Reply-To`.

Test coverage was updated in `tests/Unit/AzureCommunicationServicesTransportTest.php` to assert configured-sender precedence and reply-to behavior for forwarded mail.

## Why This Works

Inbound and outbound were failing at different layers. Postfix policy changes fixed SMTP acceptance, but ACS still enforces sender identity constraints. Using the configured ACS sender for `From` satisfies provider requirements, and `Reply-To` keeps the original sender context for responses.

## Prevention

- Keep a unit test that enforces: configured sender is authoritative for ACS `From`, original sender is preserved in `Reply-To`.
- Add a deployment smoke test for the full path: inbound SMTP -> alias processing -> ACS forward -> recipient delivery.
- When debugging mail flow, split checks by stage (ingress SMTP policy vs egress provider acceptance) to avoid false closure on partial fixes.
