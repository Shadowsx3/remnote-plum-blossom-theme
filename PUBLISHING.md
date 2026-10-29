# Publishing 紫梅 Plum Blossom

## Want to use the theme right now? You do not need a repo for that

The repo is only needed for the **Theme Marketplace upload**. To use the theme
today on desktop or the web app:

1. Open the **Custom CSS** powerup in RemNote (search `Custom CSS` in the
   omnibar).
2. Add a CSS block and paste all of `theme.css` into it.

No manifest, no repo, no upload — and the mobile rules in the theme are written
for exactly this route too. The plugin route below is what puts it in the
marketplace and makes it installable from the mobile app's theme list.

## Why RemNote rejected the manifest

RemNote's validator does not just check that `repoUrl` looks like a URL — it
**fetches it** and requires it to resolve to an existing, **public** GitHub
repo. `https://github.com/BassMD/remnote-plum-blossom-theme` returns **404**
because the repo does not exist yet (your account `BassMD` currently has zero
public repos), so the upload is rejected with:

```
Repo URL must point to a public GitHub repo.
```

There is no way around this: the repo has to exist, and it has to be public.

## What is already done

- The whole theme folder is a **git repo**, committed on `main`:
  `36de049 Plum Blossom 紫梅: a cute purple Chinese-inspired light theme for RemNote`
- `manifest.json` points at `https://github.com/BassMD/remnote-plum-blossom-theme`
- `origin` is already configured for that URL, so pushing is a single command
- `build-theme-zip.sh` now warns when `repoUrl` is not reachable

## What you have to do (2 minutes)

### 1. Create the public repo

Open this link — it pre-fills the name and public visibility:

**https://github.com/new?name=remnote-plum-blossom-theme&visibility=public**

Do **not** add a README, .gitignore or licence in the GitHub wizard — this
folder already has them, and a pre-made README would cause a push conflict.

### 2. Publish the files — pick one

**Option A · no git, drag and drop (easiest)**

In the empty repo click **uploading an existing file**, drag in everything in
this folder **except `.git/` and `dist/`** (include `docs/` so the README
screenshots resolve), then **Commit changes**.

**Option B · git push**

```bash
cd ~/Documents/Github/remnote-plum-blossom-theme
git push -u origin main
```

GitHub no longer accepts account passwords over HTTPS, so when it asks for a
password paste a **personal access token** (github.com → Settings → Developer
settings → Personal access tokens → Fine-grained, `Contents: Read and write`).
To stop being asked again:

```bash
git config --global credential.helper osxkeychain
```

### 3. Confirm it is actually public

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://github.com/BassMD/remnote-plum-blossom-theme
# want: 200
```

Or just open it in a private/incognito window. If it asks you to log in, it is
private and RemNote will still reject it.

### 4. Upload the theme

```bash
cd ~/Documents/Github/remnote-plum-blossom-theme
./build-theme-zip.sh          # should now say: repoUrl reachable … (HTTP 200)
```

Then RemNote → **Plugins and Themes → Build → Upload Theme** →
`dist/plum-blossom-theme.zip`.

## Using a different repo name or owner

Edit `repoUrl` in `manifest.json`, re-run `./build-theme-zip.sh`, and update the
remote:

```bash
git remote set-url origin https://github.com/<you>/<repo>.git
```

## Why this could not be automated from here

- The GitHub toolkit is blocked in this session:
  `[Session Restriction] Toolkit 'github' is not allowed for this session`, so
  no tool available to me can create a repository.
- There is no cached credential on this machine (`git config --global
  credential.helper` is unset, and `gh` is not installed), so a push has
  nothing to authenticate with either.

Both are one-time, user-side steps.
