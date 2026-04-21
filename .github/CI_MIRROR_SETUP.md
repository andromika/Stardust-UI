# Stardust-UI CI Mirror Configuration

This document describes the bidirectional CI/CD mirroring setup for Stardust-UI changes between repositories.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Git Repositories                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  PolestarLabs/dashboard (dash-v3 branch)                     │
│  └─ frontend/src/ui/                                        │
│  └─ frontend/src/stories/                                   │
│  └─ frontend/src/assets/                                    │
│  └─ frontend/.storybook/                                    │
│         ↕ (bidirectional mirror)                            │
│  andromika/Stardust-UI (main branch)                        │
│  └─ src/ui/                                                 │
│  └─ src/stories/                                            │
│  └─ src/assets/                                             │
│  └─ .storybook/                                             │
│         ↕ (mirror to organization)                         │
│  PolestarLabs/Stardust-UI (optional)                        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Workflows

### 1. Mirror Dashboard → Stardust-UI (in dashboard repo)
**File:** `.github/workflows/mirror_stardust_ui.yml`
**Trigger:** Push to `dash-v3` with changes in `frontend/**`
**Action:** Mirrors `frontend/src/ui/**` to Stardust-UI main branch
**Target:** `andromika/Stardust-UI` (main)

### 2. Mirror Stardust-UI → Dashboard (in Stardust-UI repo)
**File:** `.github/workflows/mirror-to-dashboard.yml`
**Trigger:** Push to `main` with changes in `src/**`
**Action:** Syncs changes back to dashboard `frontend/**`
**Target:** `PolestarLabs/dashboard` (dash-v3)

### 3. Sync to PolestarLabs Organization (in Stardust-UI repo)
**File:** `.github/workflows/sync-to-polestarlabs.yml`
**Trigger:** Push to `main` with UI changes
**Action:** Pushes main branch to PolestarLabs/Stardust-UI
**Target:** `PolestarLabs/Stardust-UI` (main)

## Required GitHub Secrets

### For Dashboard Repository (`PolestarLabs/dashboard`)

**`STARDUST_UI_PUSH_TOKEN`**
- Type: Personal Access Token (PAT) or GitHub App token
- Permissions: `repo` (full control of private repositories)
- Used by: `mirror_stardust_ui.yml` to push to `andromika/Stardust-UI`
- Scope: Can push to target repository

### For Stardust-UI Repository (`andromika/Stardust-UI`)

**`DASHBOARD_SYNC_TOKEN`**
- Type: Personal Access Token (PAT)
- Permissions: `repo` (full control)
- Used by: `mirror-to-dashboard.yml` to push to `PolestarLabs/dashboard`
- Scope: Must have write access to `PolestarLabs/dashboard`

**`POLESTARLABS_SYNC_TOKEN`** (Optional)
- Type: Personal Access Token (PAT)
- Permissions: `repo`
- Used by: `sync-to-polestarlabs.yml` to push to `PolestarLabs/Stardust-UI`
- Scope: Only needed if using PolestarLabs organization mirror

## Setup Instructions

### Step 1: Create Personal Access Tokens

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Create token with `repo` scope for each sync direction needed
3. Store tokens securely

### Step 2: Add Secrets to Repositories

**In `PolestarLabs/dashboard`:**
```
Settings → Secrets and variables → Actions → New repository secret
Name: STARDUST_UI_PUSH_TOKEN
Value: <PAT from step 1>
```

**In `andromika/Stardust-UI`:**
```
Settings → Secrets and variables → Actions → New repository secret
Name: DASHBOARD_SYNC_TOKEN
Value: <PAT from step 1>

Name: POLESTARLABS_SYNC_TOKEN (optional)
Value: <PAT for PolestarLabs organization>
```

### Step 3: Test the Workflows

1. Make a test change to `frontend/src/ui/**` in dashboard dash-v3 branch
2. Verify mirror appears in Stardust-UI main branch
3. Make a test change to `src/ui/**` in Stardust-UI main branch
4. Verify mirror appears in dashboard frontend

## File Mapping

| Source | Target |
|--------|--------|
| `frontend/src/ui/**` | `src/ui/**` |
| `frontend/src/stories/**` | `src/stories/**` |
| `frontend/src/assets/fonts.css` | `src/assets/fonts.css` |
| `frontend/src/assets/tailwind.css` | `src/assets/tailwind.css` |
| `frontend/.storybook/**` | `.storybook/**` |

## Preventing Infinite Loops

Both workflows use `GITHUB_TOKEN` which prevents automatic triggers on actions bot commits, avoiding infinite loops. The workflows are also rate-limited with concurrency groups.

## Troubleshooting

### Workflow not triggering
- Verify file paths in `paths:` match actual changes
- Check that branch names match (dash-v3, main)
- Ensure secrets are properly set and not expired

### Sync failures
- Check that tokens have proper permissions
- Verify target repositories exist and are accessible
- Review workflow logs for specific error messages

### Conflicts
- Workflows do force pushes (`--force` flag)
- Ensure no local manual edits to mirrored paths in target repos
- Use manual `workflow_dispatch` trigger for controlled syncs

## Manual Trigger

All workflows can be manually triggered via:
```
Actions → [Workflow Name] → Run workflow
```

Select the branch and click "Run workflow" to force an immediate sync.
