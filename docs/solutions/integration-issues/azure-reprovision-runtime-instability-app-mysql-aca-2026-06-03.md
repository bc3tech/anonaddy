---
title: "Azure reprovision/runtime instability in ACA app + MySQL setup"
date: "2026-06-03"
track: "bug"
problem_type: "integration_issue"
category: "integration-issues"
status: "resolved"
module: "infra"
component: "Azure Container Apps + MySQL/MariaDB + custom domain + deployment hooks"
tags:
  - "azure-container-apps"
  - "azd"
  - "bicep"
  - "mariadb"
  - "custom-domain"
  - "migrations"
---

## Problem

Azure Container Apps reprovision and deployment were not consistently idempotent for app runtime dependencies. Migrations, custom-domain binding, and database startup behavior could fail or drift across reprovision/cold-start scenarios.

## Symptoms

- Reprovision could drop custom domain/certificate binding for the app Container App.
- Database migrations required explicit execution for environment setup, but app-lifecycle execution risked repeated runs on cold starts.
- Database startup/connectivity reliability degraded with the previous MySQL image on Azure Files-backed ACA storage.
- Empty ACS configuration values could pass through deployment inputs and break mail behavior later.

## What Didn't Work

- Coupling migrations to app startup behavior.
- Relying on manual custom-domain rebinding after each reprovision.
- Keeping `mysql:8.4` in this ACA + Azure Files profile.
- Allowing critical ACS parameters to be empty at deployment time.

## Solution

1. Added a **postdeploy hook** that triggers a **manual ACA migration job**:
   - `azure.yaml` postdeploy hook for app service
   - `infra/run-migrations.ps1` to update job image, start execution, and wait for completion
   - `infra/modules/container-apps.bicep` + `infra/main.bicep` wiring for `MIGRATE_CONTAINER_APP_JOB_NAME`
2. Added a **postprovision hook** for custom-domain rebinding:
   - `azure.yaml` postprovision hook
   - `infra/bind-custom-domain.ps1` to bind configured app hostname
3. Switched DB runtime from `mysql:8.4` to `mariadb:11` and defaulted `mysqlMinReplicas` to `1`.
4. Added `@minLength(1)` guards for `mailAcsEndpoint` and `mailAcsAccessKey` in Bicep parameters.

## Why This Works

The fix separates concerns across lifecycle boundaries: provisioning tasks, deploy tasks, and runtime tasks each run in the right place. Migrations now run explicitly during deploy (not every cold start), domain binding is re-applied automatically after reprovision, DB behavior uses a stable image/profile for ACA + Azure Files, and invalid ACS values fail fast before rollout.

## Prevention

- Keep migrations as a deploy hook + manual job trigger, not an app boot routine.
- Keep postprovision domain binding automation enabled for every `azd up`.
- Treat DB min replicas and image choice as reliability controls, not only cost controls.
- Enforce non-empty validation for critical infrastructure parameters that would otherwise fail late.
- Maintain infra docs (`infra/README.md`) alongside lifecycle changes so operational expectations stay explicit.
