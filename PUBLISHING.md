# Publishing 紫梅 Plum Blossom

## Where things stand

- Repo: **https://github.com/Shadowsx3/remnote-plum-blossom-theme** — exists,
  **public**, default branch `main`, verified answering HTTP 200.
- It is still **empty**: nothing has been pushed to it yet.
- `manifest.json` now points `repoUrl` at that repo, so RemNote's
  *"Repo URL must point to a public GitHub repo"* check passes.
- This folder is a git repo: commits on `main`, `origin` set to that URL.

**One thing left: get the files into the repo, then upload the zip.**

> The earlier rejection was my mistake: `repoUrl` pointed at
> `https://github.com/BassMD/remnote-plum-blossom-theme`, a guessed account that
> does not own the repo. A URL that 404s is rejected even if it looks valid.

## Use the theme right now (no repo needed)

Paste `theme.css` into RemNote's **Custom CSS** powerup (search `Custom CSS` in
omnibar) and add a CSS block. Live immediately, mobile rules included.

Or run `./dev.sh` and load it into RemNote properly:
Settings → Plugins → Build → **"Develop from localhost"** →
`http://localhost:8080/`. See the README for the port-8080 caveat (another
plugin's dev server will be holding it).

The repo is only needed for the marketplace listing.

## Get the files into the repo — pick one

### A · drag and drop (no git, 2 clicks)

In the empty repo click **uploading an existing file**, drag in everything from
`~/Documents/Github/remnote-plum-blossom-theme` **except `.git/` and `dist/`**
(include `docs/` so the README screenshots resolve), then **Commit changes**.

### B · git push

```bash
cd ~/Documents/Github/remnote-plum-blossom-theme
git push -u origin main
```

GitHub no longer accepts account passwords over HTTPS, so paste a **personal
access token** when prompted (Settings → Developer settings → Personal access
tokens → fine-grained, `Contents: Read and write`). To stop being asked again:

```bash
 git config --global credential.helper osxkeychain
```

### C · hand over a token and let the script do it

```bash
GH_TOKEN=<token> ./publish.sh
```

`publish.sh` prints which account the token belongs to, creates the repo if it
is missing, pushes `main`, verifies the URL answers 200, and builds the zip. The
token only ever goes into the push URL, and a `trap` restores the clean remote
afterwards.

## Confirm, then upload

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://github.com/Shadowsx3/remnote-plum-blossom-theme   # want 200
./build-theme-zip.sh    # want: repoUrl reachable ... (HTTP 200)
```

Then RemNote → **Plugins and Themes → Build → Upload Theme** →
`dist/plum-blossom-theme.zip`.

## Updating an already-published theme

RemNote's docs cover the first upload only — there is no documented update
procedure. What is documented, and what it implies:

- **Manifest** (`version` is required): *"Only one plugin of each ID can be
  installed or registered in our marketplace"* → re-uploading the **same `id`**
  updates that listing rather than creating a second one.
- **Submitting Plugins**: the upload is done in-app, from the Build tab, and the
  repo must be public.
- **SDK changelog**: *"Manifests are now validated on build"*, and
  *"Add Repository and Report bugs links to the marketplace details page"* —
  hence `projectUrl` / `supportUrl` / `changelogUrl` in the manifest.

So: **same `id`, bumped `version`, re-upload the zip.** One command does the
local half:

```bash
./release.sh patch "fixed the phone watermark on iPad"     # or minor / major
./release.sh minor "added a slate accent" --dry-run        # preview only
```

It bumps the manifest, adds a dated `CHANGELOG.md` entry, validates and rebuilds
the zip, commits, tags `vX.Y.Z`, and pushes. Then:

**Plugins and Themes → Build → Upload Theme** → `dist/plum-blossom-theme.zip`

Not documented anywhere I could find: whether installed copies auto-refresh, or
whether an equal/lower version is rejected. Test it by uploading `1.0.1` over
`1.0.0` and watching the Build tab; the Discord is the place to ask.

## Using a different name or owner

Edit `repoUrl` in `manifest.json` and the screenshot URLs in `README.md`,
re-run `./build-theme-zip.sh`, then:

```bash
git remote set-url origin https://github.com/<owner>/<repo>.git
```

## Why the push could not be done from here

There is no GitHub credential on this machine: no `gh`, no keychain entry for
github.com, no SSH key (`Permission denied (publickey)`), no `GH_TOKEN`, and the
GitHub toolkit is blocked in this session
(`[Session Restriction] Toolkit 'github' is not allowed for this session`).
Creating a repo and pushing both need one of those, so it is a one-time
user-side step — everything else is prepared.
