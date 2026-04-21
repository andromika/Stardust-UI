# Quick Reference: Stardust-UI CI Mirror

## What Syncs Where?

| From | To | File | Branch |
|------|----|----|--------|
| `PolestarLabs/dashboard` `frontend/src/ui/**` | Stardust-UI | `mirror_stardust_ui.yml` (dashboard repo) | dash-v3 → main |
| Stardust-UI `src/ui/**` | `PolestarLabs/dashboard` `frontend/` | `mirror-to-dashboard.yml` (Stardust-UI repo) | main → dash-v3 |
| Stardust-UI `src/**` | `PolestarLabs/Stardust-UI` | `sync-to-polestarlabs.yml` (Stardust-UI repo) | main → main |

## Secrets Needed

### In `PolestarLabs/dashboard` GitHub Settings:
- `STARDUST_UI_PUSH_TOKEN` → Can push to `andromika/Stardust-UI`

### In `andromika/Stardust-UI` GitHub Settings:
- `DASHBOARD_SYNC_TOKEN` → Can push to `PolestarLabs/dashboard`
- `POLESTARLABS_SYNC_TOKEN` → Can push to `PolestarLabs/Stardust-UI` (optional)

## Testing Mirrors

### Test Dashboard → Stardust-UI:
```bash
# In dashboard repo on dash-v3 branch
echo "test" > frontend/src/ui/test.txt
git add frontend/src/ui/test.txt
git commit -m "test mirror"
git push origin dash-v3
# Watch: PolestarLabs/dashboard → .github/workflows/mirror_stardust_ui.yml
# Should appear in: andromika/Stardust-UI main branch as src/ui/test.txt
```

### Test Stardust-UI → Dashboard:
```bash
# In Stardust-UI repo on main branch
echo "test" > src/ui/test.txt
git add src/ui/test.txt
git commit -m "test mirror"
git push origin main
# Watch: Stardust-UI → .github/workflows/mirror-to-dashboard.yml
# Should appear in: PolestarLabs/dashboard dash-v3 as frontend/src/ui/test.txt
```

## Manual Sync Commands

```bash
# In Stardust-UI directory
chmod +x sync-mirrors.sh

# Show status
./sync-mirrors.sh both

# Manually sync Stardust-UI → Dashboard
./sync-mirrors.sh stardust

# Get help
./sync-mirrors.sh help
```

## Files Created

```
.github/
├── workflows/
│   ├── mirror-to-dashboard.yml      ← Stardust-UI → Dashboard
│   └── sync-to-polestarlabs.yml     ← Stardust-UI → PolestarLabs
├── CI_MIRROR_SETUP.md               ← Full setup guide
└── SETUP_COMPLETE.md                ← This was created

sync-mirrors.sh                       ← Helper script
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Workflows not running | Check `paths:` in YAML match actual file changes |
| Auth failures | Verify PAT tokens have `repo` scope and haven't expired |
| No changes appear | Manually trigger workflow in Actions tab → "Run workflow" |
| Infinite loop | GitHub automatically prevents this with action token scoping |

## Documentation Files

- **`CI_MIRROR_SETUP.md`** - Complete architectural guide with setup steps
- **`SETUP_COMPLETE.md`** - What was created and next steps
- **`QUICK_REFERENCE.md`** - This file!

---

**Last Updated:** April 2026
**Status:** Ready for deployment
**Manual Token Setup Required:** Yes ⚠️
