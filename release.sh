#!/usr/bin/env bash
#
# Cut a new version of the theme.
#
#   ./release.sh patch "fixed the watermark on iPad"
#   ./release.sh minor "added a slate accent"
#   ./release.sh major "re-skinned: new palette"
#
#   --dry-run    print the plan, change nothing
#   --no-push    do everything locally except `git push`
#
# If git has no stored GitHub credential on this machine (only GitHub Desktop
# does, and that token is app-specific), pass one:
#
#   GH_TOKEN=ghp_xxx ./release.sh patch "fixed the watermark on iPad"
#
# It bumps the version in manifest.json, prepends a dated entry to
# CHANGELOG.md, validates + rebuilds dist/plum-blossom-theme.zip, commits, tags
# vX.Y.Z and pushes main + the tag.
#
# RemNote has no upload API, so the last step is always manual:
#   Plugins and Themes -> Build -> Upload Theme -> dist/plum-blossom-theme.zip
set -euo pipefail

cd "$(dirname "$0")"

BUMP=""
MESSAGE=""
DRY_RUN=0
DO_PUSH=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-push) DO_PUSH=0 ;;
    major | minor | patch) BUMP="$arg" ;;
    *)
      if [ -z "$MESSAGE" ]; then MESSAGE="$arg"; fi
      ;;
  esac
done

if [ -z "$BUMP" ]; then
  cat <<'EOF'
usage: ./release.sh <major|minor|patch> "<changelog line>" [--dry-run] [--no-push]

  patch   a fix            (1.0.0 -> 1.0.1)
  minor   new rules/extras (1.0.0 -> 1.1.0)
  major   a re-skin        (1.0.0 -> 2.0.0)

  GH_TOKEN=<token> ./release.sh ...   if git has no stored GitHub credential
EOF
  exit 1
fi

if [ -z "$MESSAGE" ]; then
  echo 'give it a changelog line, e.g. ./release.sh patch "fixed the phone watermark"' >&2
  exit 1
fi

# --- current version -------------------------------------------------------
read -r OLD_MAJOR OLD_MINOR OLD_PATCH <<<"$(
  python3 -c "import json;v=json.load(open('manifest.json'))['version'];print(v['major'],v['minor'],v['patch'])"
)"
OLD="v$OLD_MAJOR.$OLD_MINOR.$OLD_PATCH"

case "$BUMP" in
  major) NEW_MAJOR=$((OLD_MAJOR + 1)); NEW_MINOR=0; NEW_PATCH=0 ;;
  minor) NEW_MAJOR=$OLD_MAJOR; NEW_MINOR=$((OLD_MINOR + 1)); NEW_PATCH=0 ;;
  patch) NEW_MAJOR=$OLD_MAJOR; NEW_MINOR=$OLD_MINOR; NEW_PATCH=$((OLD_PATCH + 1)) ;;
esac
NEW="v$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
TODAY="$(date +%Y-%m-%d)"

echo "release plan"
echo "  version   $OLD  ->  $NEW   ($BUMP)"
echo "  changelog $TODAY: $MESSAGE"
echo "  touches   manifest.json, CHANGELOG.md, dist/plum-blossom-theme.zip"
echo "  git       commit \"$NEW: $MESSAGE\", tag $NEW$( [ "$DO_PUSH" = 1 ] && echo ', push origin main + tag' || echo ' (no push)')"
echo

if [ "$DRY_RUN" = 1 ]; then
  echo "--dry-run: nothing was changed."
  exit 0
fi

# --- bump the manifest -----------------------------------------------------
python3 - "$NEW_MAJOR" "$NEW_MINOR" "$NEW_PATCH" <<'PY'
import json, sys

path = "manifest.json"
with open(path, encoding="utf-8") as fh:
    manifest = json.load(fh)

manifest["version"] = {
    "major": int(sys.argv[1]),
    "minor": int(sys.argv[2]),
    "patch": int(sys.argv[3]),
}

with open(path, "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY

# --- prepend the changelog entry ------------------------------------------
python3 - "$NEW" "$TODAY" "$MESSAGE" <<'PY'
import sys

new, today, message = sys.argv[1], sys.argv[2], sys.argv[3]
marker = "<!-- releases -->"
entry = f"{marker}\n\n## {new.lstrip('v')} — {today}\n\n- {message}\n"

with open("CHANGELOG.md", encoding="utf-8") as fh:
    text = fh.read()

if marker not in text:
    sys.exit("CHANGELOG.md is missing its '<!-- releases -->' marker")

with open("CHANGELOG.md", "w", encoding="utf-8") as fh:
    fh.write(text.replace(marker, entry, 1))
PY

# --- validate + build (fails loudly if the manifest is wrong) -------------
./build-theme-zip.sh

# --- commit, tag ----------------------------------------------------------
git add -A
echo
echo "staged:"
git diff --cached --stat
git commit -q -m "$NEW: $MESSAGE"
git tag -a "$NEW" -m "$NEW: $MESSAGE"
echo "committed and tagged $NEW"

# --- push -----------------------------------------------------------------
# git has no credential of its own on a fresh machine (GitHub Desktop's token is
# app-specific), so accept one here the same way publish.sh does.
if [ "$DO_PUSH" = 1 ]; then
  PUSH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  ORIGIN_URL="$(git remote get-url origin)"

  restore_remote() {
    git remote set-url origin "$ORIGIN_URL" 2>/dev/null || true
  }

  if [ -n "$PUSH_TOKEN" ]; then
    case "$ORIGIN_URL" in
      https://*)
        git remote set-url origin "https://x-access-token:${PUSH_TOKEN}@${ORIGIN_URL#https://}"
        trap restore_remote EXIT
        ;;
      *) echo "note: GH_TOKEN set but origin is not https, pushing as-is" ;;
    esac
  fi

  if ! git push origin main --follow-tags; then
    restore_remote
    echo
    echo "push failed. Options:" >&2
    echo "  * GH_TOKEN=<pat> ./release.sh $BUMP \"$MESSAGE\"      # token in the URL, restored after" >&2
    echo "  * or push by hand once credentials are set up (see PUBLISHING.md)" >&2
    echo "The commit and tag exist locally either way." >&2
    exit 1
  fi

  restore_remote
  echo "pushed main + $NEW"
fi

cat <<EOF

Done. RemNote has no upload API, so finish it there:

  Plugins and Themes -> Build -> Upload Theme
  -> $(pwd)/dist/plum-blossom-theme.zip

Installed copies of a theme pick up the new version from the marketplace once
it is uploaded (the manifest version is what marks it as newer).
EOF
