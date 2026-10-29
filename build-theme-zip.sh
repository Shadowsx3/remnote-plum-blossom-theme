#!/usr/bin/env bash
#
# Bundle the theme into an uploadable zip for the RemNote Theme Marketplace.
#
#   ./build-theme-zip.sh
#
# RemNote expects theme.css, manifest.json and README.md at the *root* of the
# zip (that is how the official templates and plugin builds ship), so the
# archive is built from a staging directory rather than by zipping this folder.
#
# Then: RemNote -> Plugins and Themes -> Build tab -> "Upload Theme".
set -euo pipefail

cd "$(dirname "$0")"

DIST="dist"
STAGE="$DIST/plum-blossom-theme"
OUT="$DIST/plum-blossom-theme.zip"

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE"

cp theme.css manifest.json README.md "$STAGE/"

# Validate the manifest against RemNote's own schema before shipping it, so a
# rejected upload tells you why here rather than in RemNote's error toast.
# The limits below are lifted from @remnote/plugin-sdk's manifest zod schema:
#   id 5-100 chars of [A-Za-z0-9_-], name/author 3-100, repoUrl a real URL
#   (it is required), description at most 200 chars, theme only light/dark.
python3 - "$STAGE/manifest.json" <<'PY'
import json, re, sys

m = json.load(open(sys.argv[1], encoding="utf-8"))
errors = []

def check(ok, message):
    if not ok:
        errors.append(message)

ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")
URL_RE = re.compile(r"^https?://[^\s]+$")

check(m.get("manifestVersion") == 1, "manifestVersion must be the literal 1")
check(
    isinstance(m.get("id"), str) and 5 <= len(m["id"]) <= 100 and ID_RE.match(m["id"]),
    "id must be 5-100 chars of a-z A-Z 0-9 - _",
)
check(
    isinstance(m.get("name"), str) and 3 <= len(m["name"]) <= 100,
    "name must be 3-100 chars",
)
check(
    isinstance(m.get("author"), str) and 3 <= len(m["author"]) <= 100,
    "author must be 3-100 chars",
)
repo = m.get("repoUrl")
check(
    isinstance(repo, str) and URL_RE.match(repo),
    "repoUrl is required and must start with http:// or https://",
)
desc = m.get("description")
check(
    desc is None or (isinstance(desc, str) and len(desc) <= 200),
    "description must be at most 200 chars (currently %s)"
    % (len(desc) if isinstance(desc, str) else "not a string"),
)
check(isinstance(m.get("enableOnMobile"), bool), "enableOnMobile must be a boolean")
check(isinstance(m.get("requestNative"), bool), "requestNative must be a boolean")
theme = m.get("theme")
check(
    theme is None or (isinstance(theme, list) and all(t in ("light", "dark") for t in theme)),
    'theme must be a list of "light" and/or "dark"',
)
v = m.get("version")
check(
    isinstance(v, dict)
    and all(isinstance(v.get(k), int) and not isinstance(v.get(k), bool) and v.get(k) >= 0
            for k in ("major", "minor", "patch")),
    "version needs numeric major/minor/patch",
)
check(isinstance(m.get("requiredScopes"), list), "requiredScopes must be a list")

if errors:
    print("manifest.json does not match RemNote's schema:")
    for e in errors:
        print("  - " + e)
    sys.exit(1)

print(
    "manifest ok: id %s, name %d chars, description %d/200, repoUrl %s"
    % (m["id"], len(m["name"]), len(desc or ""), repo)
)
PY

# RemNote also fetches repoUrl, and insists it is an existing *public GitHub
# repo* — a plausible-but-nonexistent URL is rejected at upload time with
# "Repo URL must point to a public GitHub repo". Warn rather than fail, since
# you may be offline or creating the repo as you read this.
REPO_URL=$(python3 -c "import json;print(json.load(open('manifest.json'))['repoUrl'])")
REPO_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$REPO_URL" 2>/dev/null || echo 000)
if [ "$REPO_CODE" = "200" ]; then
  echo "repoUrl reachable: $REPO_URL (HTTP 200)"
else
  echo "WARNING: repoUrl $REPO_URL answered HTTP $REPO_CODE."
  echo "         RemNote needs an existing PUBLIC GitHub repo here, or the upload is"
  echo "         rejected. See PUBLISHING.md."
fi

( cd "$STAGE" && zip -q -r "../plum-blossom-theme.zip" theme.css manifest.json README.md )

echo "Built $OUT"
unzip -l "$OUT"
