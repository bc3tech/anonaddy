---
title: "ACS sender display-name strategy for forwarded mail"
category: "Platform"
status: "🟡 In Progress"
priority: "High"
timebox: "2 days"
created: 2026-06-05
updated: 2026-06-05
owner: "Copilot"
tags: ["technical-spike", "platform", "azure-communication-services", "email", "smtp", "research"]
---

# ACS sender display-name strategy for forwarded mail

## Summary

**Spike Objective:** Determine whether Azure Communication Services can produce addy-like inbox cards for forwarded mail by changing sender-username resources or sender display names without adding meaningful cost.

**Why This Matters:** The current ACS-backed forwarding path delivers mail, but Outlook still shows the ACS sender identity instead of a user-friendly sender card. The goal is to improve perceived sender fidelity while keeping the low-cost ACS mail stack.

**Timebox:** 2 days

**Decision Deadline:** Before any more mail-surface changes are made in the forwarding pipeline.

## Research Question(s)

**Primary Question:** Can ACS sender-username resources with a custom display name produce a friendlier inbox card, or is the visible name effectively fixed once the sender resource is chosen?

**Secondary Questions:**

- Can we create one or more ACS sender-username resources with display names that show up in Outlook?
- Can the display name be changed per message, or is it fixed per sender resource?
- Is a neutral sender like `forwarded-by@anon.bc3.tech` with a friendly display name the best compromise?
- Is there any low-cost path to make the display name track the original sender more closely?

## Investigation Plan

### Research Tasks

- [x] Verify the ACS SMTP docs for what SMTP username controls versus what sender identity controls.
- [x] Verify how ACS MailFrom/sender-username resources store display name and whether that display name is static.
- [x] Inspect whether one sender resource can be reused safely for all forwards without breaking deliverability.
- [ ] Create a proof-of-concept sender-username resource with a custom display name and send a probe.
- [ ] Compare inbox rendering for:
  - default ACS sender
  - neutral branded sender
  - sender-username resource with custom display name
- [ ] Document the best low-cost option and the tradeoffs.

### Success Criteria

**This spike is complete when:**

- [x] The role of SMTP username is understood and documented.
- [x] The role of ACS sender-username/MailFrom display name is understood and documented.
- [x] A recommendation is documented for the forwarding pipeline.
- [ ] Any viable low-cost proof-of-concept is tested or explicitly ruled out.

## Technical Context

**Related Components:** `app/CustomMailDriver/AzureCommunicationServicesTransport.php`, `app/Mail/ForwardEmail.php`, ACS Email Communication Service domain configuration.

**Dependencies:** Forwarding UX decisions depend on whether ACS can show a useful sender name without per-message sender provisioning.

**Constraints:** 

- Forwarding aliases are dynamic and may be user-defined.
- SMTP relay is not viable in this environment.
- We need to avoid a materially higher operating cost.
- The sender address still has to satisfy ACS acceptance rules.

## Research Findings

### Investigation Results

- ACS SMTP username is for authentication, not visible inbox identity.
- ACS docs show sender display name lives on MailFrom / sender-username resources, not on SMTP auth.
- Microsoft Learn says multiple sender usernames can be added to a custom domain and each sender username can have a display name.
- The docs also show sender usernames are managed resources that can be created, updated, listed, and deleted.
- This suggests the display name is resource-level, not per-message.
- The current evidence points to a single remaining experiment: provision a branded sender-username resource and verify whether Outlook actually honors its display name in the inbox card.

### Prototype/Testing Notes

- Existing forwarding probes confirmed delivery works through ACS.
- The inbox card still showed the ACS sender identity when the sender resource display name was not aligned with the desired presentation.
- The live ACS sender-username display name was updated to `AnonAddy Relay`.
- A Container Apps job probe confirmed the SMTP listener could not be reached from that job environment:
  - `127.0.0.1:25` returned connection refused
  - `ca-mail-anonaddy-7bfodwgag525i.nicecliff-162ed054.westus2.azurecontainerapps.io:25` timed out
- Because the probe cannot currently reach the mail container, we do not yet have a recipient-visible inbox-card result for the branded sender-username change.

### External Resources

- https://learn.microsoft.com/en-us/azure/communication-services/quickstarts/email/add-multiple-senders
- https://learn.microsoft.com/en-us/azure/communication-services/quickstarts/email/send-email-smtp/send-email-smtp
- https://learn.microsoft.com/en-us/azure/communication-services/quickstarts/email/smtp-authentication

## Decision

### Recommendation

Use ACS sender-username resources with explicit display names as the only low-cost path worth testing further. If the desired display name must vary per forwarded message, ACS likely cannot do that directly; in that case, keep the sender address neutral and rely on a stable sender name plus reply-to context.

### Rationale

SMTP username alone does not change inbox display identity. ACS appears to bind display name to the sender resource, which makes per-message display-name fidelity unlikely. That means the best low-cost experiment is to create a sender resource with a more user-friendly display name and verify whether Outlook honors it consistently.

### Implementation Notes

- Prefer a single branded sender resource if one display name is acceptable for all forwards.
- If multiple sender resources are allowed, test whether a small set of representative sender names can cover the highest-value cases.
- Do not assume Outlook will honor a display-name-only trick if the sender resource itself does not match.

### Follow-up Actions

- [ ] Provision a test sender-username resource with a branded display name.
- [ ] Send a live probe and compare the inbox card to addy.io.
- [ ] If the display name still does not render, stop pursuing message-level sender tricks.
- [ ] Decide whether to keep the safe compromise or move to a different provider later.
- [ ] If the live probe is successful, record the exact resource name and display-name format to standardize future forwards.
- [ ] Find a probe path that can reach the live SMTP listener from inside Azure so the inbox-card result can be verified.

## Status History

| Date | Status | Notes |
| --- | --- | --- |
| 2026-06-05 | 🔴 Not Started | Spike created and scoped |
| 2026-06-05 | 🟡 In Progress | SMTP auth ruled out; branded sender-username probe attempted but network-restricted |

---

_Last updated: 2026-06-05 by Copilot_
