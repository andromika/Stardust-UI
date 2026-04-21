#!/bin/bash
#
# Manual sync script for Stardust-UI ↔ Dashboard bidirectional mirroring
# Usage: ./sync-mirrors.sh [dashboard|stardust|both]
#

set -euo pipefail

DASHBOARD_REPO="PolestarLabs/dashboard"
DASHBOARD_BRANCH="dash-v3"
STARDUST_REPO="${STARDUST_REPO:-andromika/Stardust-UI}"
STARDUST_BRANCH="main"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

sync_stardust_to_dashboard() {
    log_info "Syncing Stardust-UI → Dashboard"
    
    if [ ! -d ".git" ]; then
        log_error "Not a git repository"
        return 1
    fi
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    if [ "$current_branch" != "$STARDUST_BRANCH" ]; then
        log_warn "Current branch is $current_branch, expected $STARDUST_BRANCH"
        git checkout "$STARDUST_BRANCH" || log_error "Failed to checkout $STARDUST_BRANCH"
    fi
    
    # Get latest from origin
    git fetch origin "$STARDUST_BRANCH"
    git pull origin "$STARDUST_BRANCH"
    
    # Prepare temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    log_info "Preparing UI content for mirror..."
    
    # Create structure
    mkdir -p "$temp_dir/frontend/src/ui"
    mkdir -p "$temp_dir/frontend/src/stories"
    mkdir -p "$temp_dir/frontend/src/assets"
    mkdir -p "$temp_dir/frontend/.storybook"
    
    # Copy files
    [ -d "src/ui" ] && cp -r src/ui/* "$temp_dir/frontend/src/ui/" || true
    [ -d "src/stories" ] && cp -r src/stories/* "$temp_dir/frontend/src/stories/" || true
    [ -f "src/assets/fonts.css" ] && cp src/assets/fonts.css "$temp_dir/frontend/src/assets/" || true
    [ -f "src/assets/tailwind.css" ] && cp src/assets/tailwind.css "$temp_dir/frontend/src/assets/" || true
    [ -d ".storybook" ] && cp -r .storybook/* "$temp_dir/frontend/.storybook/" || true
    
    log_info "Adding dashboard remote..."
    if ! git remote | grep -q dashboard; then
        git remote add dashboard "https://github.com/${DASHBOARD_REPO}.git"
    fi
    
    git fetch dashboard "$DASHBOARD_BRANCH"
    
    log_info "Checking out mirror branch..."
    git checkout -b "mirror/sync-$(date +%s)" "dashboard/$DASHBOARD_BRANCH" || \
        git checkout "mirror/sync-$(date +%s)"
    
    # Copy to working directory
    cp -r "$temp_dir/frontend" .
    
    if [ -z "$(git status --porcelain)" ]; then
        log_warn "No changes to mirror"
        return 0
    fi
    
    log_info "Committing changes..."
    git add frontend/
    git commit -m "chore: sync Stardust-UI changes to dashboard

Source: $STARDUST_REPO/$STARDUST_BRANCH
Timestamp: $(date -Iseconds)"
    
    log_info "Pushing to dashboard..."
    git push -f dashboard "mirror/sync-$(date +%s):$DASHBOARD_BRANCH"
    
    log_info "Sync completed successfully!"
}

sync_dashboard_to_stardust() {
    log_info "Syncing Dashboard → Stardust-UI"
    log_error "This direction is handled by dashboard repository workflows"
    log_info "See: $DASHBOARD_REPO/.github/workflows/mirror_stardust_ui.yml"
}

show_help() {
    cat << EOF
Stardust-UI Mirror Sync Helper

Usage: $0 [COMMAND]

Commands:
  stardust    Sync changes from Stardust-UI → Dashboard
  dashboard   Sync changes from Dashboard → Stardust-UI (automated)
  both        Show both sync directions
  help        Show this help message

Examples:
  $0 stardust    # Manually sync Stardust-UI to dashboard
  $0 dashboard   # Check dashboard sync status
  $0 both        # Show all sync information

Environment Variables:
  DASHBOARD_REPO  Set custom dashboard repository (default: PolestarLabs/dashboard)
  STARDUST_REPO   Set custom Stardust-UI repository (default: andromika/Stardust-UI)

EOF
}

case "${1:-help}" in
    stardust)
        sync_stardust_to_dashboard
        ;;
    dashboard)
        sync_dashboard_to_stardust
        ;;
    both)
        echo "Bidirectional Mirror Setup:"
        echo ""
        echo "Dashboard → Stardust-UI:"
        echo "  Repository: $DASHBOARD_REPO"
        echo "  Branch: $DASHBOARD_BRANCH"
        echo "  Workflow: .github/workflows/mirror_stardust_ui.yml"
        echo "  Trigger: Push to frontend/src/ui/**"
        echo ""
        echo "Stardust-UI → Dashboard:"
        echo "  Repository: $STARDUST_REPO"
        echo "  Branch: $STARDUST_BRANCH"
        echo "  Workflow: .github/workflows/mirror-to-dashboard.yml"
        echo "  Trigger: Push to src/ui/**"
        echo ""
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
