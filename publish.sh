#!/usr/bin/env bash
#
# Publish Plum Blossom 紫梅 to GitHub, then build the zip RemNote wants.
#
#   GH_TOKEN=ghp_xxx ./publish.sh
#
# The token needs, on a fine-grained token: Contents = Read and write, and
# Administration = Read and write (Administration is only needed to create the
# repo). A classic token with the `repo` scope also works. Revoke it afterwards
# if you like — nothing here stores it.
#
# Without a token the script tells you the two-step manual route instead.
set -euo pipefail

cd "$(dirname "$0")"

REPO_URL=$(python3 -c "import json;print(json.load(open('manifest.json'))['repoUrl'])")
OWNER=$(python3 -c "print('$REPO_URL'.split('/')[3])")
NAME=$(python3 -c "print('$REPO_URL'.split('/')[4])")
DESC=$(python3 -c "import json;print(json.load(open('manifest.json'))['description'])")

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

if [ -z "$TOKEN" ]; then
  cat <<EOF
No GitHub token in GH_TOKEN / GITHUB_TOKEN, and this machine has no stored
GitHub credential (no gh, no keychain entry, no SSH key), so publishing has
nothing to authenticate with. Pick either route:

  A. In the browser, no git — 2 clicks:
     1. open "https://github.com/new?name=$NAME&visibility=public"
     2. click "uploading an existing file" and drag in everything here
        except .git/ and dist/

  B. With a token — one command:
     GH_TOKEN=<your token> ./publish.sh

Then upload dist/plum-blossom-theme.zip in RemNote:
Plugins and Themes -> Build -> Upload Theme.
EOF
  exit 1
fi

echo "== who is this token? =="
curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/user |
  python3 -c "import json,sys; d=json.load(sys.stdin); print('  authenticated as', d.get('login') or d)"

echo "== create the public repo (skipped if it already exists) =="
HTTP=$(curl -sS -o /tmp/plum-blossom-repo.json -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$NAME\",\"description\":\"$DESC\",\"private\":false,\"has_issues\":true,\"has_wiki\":false,\"auto_init\":false}")

case "$HTTP" in
  201) echo "  created https://github.com/$OWNER/$NAME (public)" ;;
  422) echo "  already exists — carrying on" ;;
  401) echo "  token rejected (401). Check it is valid and has repo/Contents+Administration." >&2; exit 1 ;;
  403) echo "  token lacks permission to create repos (403)." >&2; exit 1 ;;
  *)   echo "  unexpected HTTP $HTTP:" >&2; cat /tmp/plum-blossom-repo.json >&2; exit 1 ;;
esac

# Push with the token in the URL so git never prompts, then always put the clean
# URL back so the token is not left sitting in .git/config.
cleanup() {
  git remote set-url origin "https://github.com/$OWNER/$NAME.git" 2>/dev/null || true
}
trap cleanup EXIT

echo "== push =="
git remote set-url origin "https://x-access-token:${TOKEN}@github.com/$OWNER/$NAME.git"
git push -u origin main

echo "== verify it is public =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://github.com/$OWNER/$NAME" || echo 000)
if [ "$CODE" = "200" ]; then
  echo "  https://github.com/$OWNER/$NAME answers 200 — public, RemNote will accept it"
else
  echo "  WARNING: answered HTTP $CODE — is the repo private?" >&2
fi

echo "== build the uploadable zip =="
./build-theme-zip.sh

echo
echo "Now: RemNote -> Plugins and Themes -> Build -> Upload Theme"
echo "     -> $(pwd)/dist/plum-blossom-theme.zip"
