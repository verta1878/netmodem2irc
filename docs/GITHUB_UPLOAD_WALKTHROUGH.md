# Publishing NetModem/32 on GitHub — a first-timer's walkthrough

You've never pushed to GitHub before, so this goes slow and assumes nothing. The
repo is already prepared and committed locally (inside `netmodem2/`). You just need
to get it onto GitHub. There are two ways — pick **A** (easiest, no command line)
or **B** (git command line). Both end in the same place.

---

## First: a one-time account + tool setup

1. **Make a GitHub account** at https://github.com (free). Pick a username — it
   becomes part of your repo URL, e.g. `github.com/yourname/netmodem2`.
2. That's all you need for Option A. For Option B you'll also install Git from
   https://git-scm.com/downloads and, the first time, tell it who you are:
   ```
   git config --global user.name "Your Name"
   git config --global user.email "your-github-email@example.com"
   ```

---

## Option A — Upload through the website (no command line)

Best if you just want it up without learning git yet.

1. On GitHub, click the **+** (top right) → **New repository**.
2. **Repository name:** `netmodem2`. Add a short description if you like.
3. Choose **Public** (so others can find and use it) — or Private for now.
4. **Do NOT** check "Add a README", "Add .gitignore", or "Choose a license" —
   your folder already has all three. Leaving them unchecked avoids conflicts.
5. Click **Create repository**. You'll land on an empty repo page.
6. Click the link **"uploading an existing file"** (in the page's Quick Setup box),
   or go to **Add file → Upload files**.
7. Open your `netmodem2` folder on your computer, select **all** its contents
   (the files *and* the `driver`, `server`, `config`, `common`, `docs` folders),
   and drag them into the browser upload area. Wait for them to finish uploading.
8. At the bottom, in **Commit changes**, type a message like
   `Initial commit: NetModem/32 revival` and click **Commit changes**.

Done — your code is live at `github.com/yourname/netmodem2`.

> Note: the website upload won't carry the local git history/commit I already made;
> it just publishes the files. That's totally fine for a first release.

---

## Option B — Push from the command line (keeps the history)

Best if you want the commit I already prepared, and to work with git going forward.

1. Create the empty repo on GitHub exactly as in Option A steps 1–5 (name it
   `netmodem2`, Public, **no** README/gitignore/license added).
2. GitHub then shows a page with a URL like
   `https://github.com/yourname/netmodem2.git`. Copy it.
3. On your computer, open a terminal **in the `netmodem2` folder** and run:
   ```
   git remote add origin https://github.com/yourname/netmodem2.git
   git branch -M main
   git push -u origin main
   ```
4. It'll ask you to sign in. Modern GitHub doesn't take your account password here —
   when prompted for a password, paste a **Personal Access Token** instead:
   GitHub → your avatar → **Settings** → **Developer settings** →
   **Personal access tokens** → **Tokens (classic)** → **Generate new token**,
   tick the **repo** scope, generate, and copy it. Use that as the password.
   (Or install **GitHub Desktop** / the **`gh`** CLI, which handle login for you.)

Your repo (with history) is now live.

---

## After it's up

* **Set the two branches** we planned. On the repo page, use the branch dropdown to
  create `9x` and `nt` from `main` (or `git branch 9x && git push origin 9x`).
  Keep shared GUI work on `main`; branch-specific driver/transport work on each.
* **Check the license shows.** GitHub should detect `LICENSE` and display "GPL-2.0"
  near the top of the repo — confirmation that Dedrick's license is properly applied.
* **Releases (for binaries later).** When you've built working `.exe`/`.vxd` files in
  the VM, go to **Releases → Draft a new release**, tag it (e.g. `v2.0-a3-revival`),
  and **attach the binaries** as release assets. Source stays in the repo; compiled
  files ride along on the Release. (That's the clean way — build artifacts don't
  belong in the tracked source, which is why `.gitignore` excludes `*.exe`/`*.vxd`.)

## A couple of good-manners notes

* The README already credits Dedrick as the original author and states GPLv2. Keep
  that prominent — it's both the license requirement and the right thing to do.
* If you ever reach Dedrick, tell him it's up; he may want to be linked or consulted.
* Don't commit the decompiled `.dfm` files or the original `.exe`/`.cpl` — those are
  private reference. The repo ships your *new* GUI plus his GPLv2 driver source.
