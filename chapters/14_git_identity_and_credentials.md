# Git Identity and Credential Storage

This chapter is about two problems that look like one problem.

The first is `Git` asking for a password every time you push. The second is
commits landing in your repositories attributed to the wrong person, or to
nobody at all. They feel related because they both involve "my account", and
they are usually fixed in the same sitting, but they are genuinely separate
mechanisms and confusing them is why this takes people so long to sort out.

Put bluntly:

- **Authentication** is how the server decides you are allowed to push. This is
  an `SSH` key or an `HTTPS` token.
- **Attribution** is how the forge decides whose face to put next to the commit.
  This is the email address baked into the commit object.

You can be perfectly authenticated and still have every commit show up as a
stranger. Fixing the password prompt does nothing for that, which is why people
fix the prompt, feel finished, and then wonder why their contribution graph is
empty.

[Chapter 9](./9_ssh_agent_setup.md) covers the `SSH` agent side in detail. This
chapter covers the `HTTPS` side, the identity side, and how to decide which
mechanism a given repository should be using in the first place.

## Working out what a repository is actually doing

Everything starts here:

```bash
git -C /path/to/repo remote -v
```

The `URL` scheme tells you which authentication mechanism is in play, and
therefore which fix applies:

| Remote URL | Mechanism | Fixed by |
|---|---|---|
| `git@github.com:<user>/<repo>.git` | `SSH` | `ssh-agent`, see chapter 9 |
| `ssh://git@host/<user>/<repo>.git` | `SSH` | `ssh-agent`, see chapter 9 |
| `https://github.com/<user>/<repo>.git` | `HTTPS` | credential helper, below |

This matters because a credential helper does nothing whatsoever for an `SSH`
remote, and `ssh-agent` does nothing whatsoever for an `HTTPS` remote. If you
apply the wrong fix, the prompt keeps appearing and you conclude the fix did
not work, when really it was never connected to the problem.

A quick sweep of every repository under a directory, so you can see the split
at a glance:

```bash
for d in ~/Projects/*/.git; do
  repo="${d%/.git}"
  url=$(git -C "$repo" remote get-url origin 2>/dev/null)
  [ -n "$url" ] && printf '%-40s %s\n' "$(basename "$repo")" "$url"
done
```

Most people find, as I did, that they have been consistently using `SSH` for
years and have two or three stragglers on `HTTPS` from a copy-pasted clone
command. Those stragglers are the ones nagging for a password.

## Why the password prompt can never succeed on GitHub

If an `HTTPS` remote prompts you for a username and password, and you type your
account password, it will be rejected. `GitHub` removed password authentication
for `Git` operations in August 2021. The prompt still says "Password" because
that is what the `HTTP` basic auth scheme calls the field, but the only thing
that will satisfy it is a **Personal Access Token**.

This is worth internalising, because the failure mode is a prompt that looks
like you are typing the wrong password. You are not. You are typing a kind of
credential the server stopped accepting years ago.

`GitLab` behaves the same way for most configurations, and self-hosted
instances vary.

## Choosing between SSH and HTTPS

Neither is wrong. They fail in different directions.

**`SSH`** is better when the machine is yours and stays yours. The key never
leaves the box, there is no expiry, and once the agent is set up the whole
thing is invisible. It is worse behind corporate firewalls that block port 22,
and it is more awkward on machines you do not fully control.

**`HTTPS` with a token** is better when you need something portable, scoped, or
revocable. Tokens can be limited to specific repositories and permissions, and
you can kill one remotely without touching the machine. It is worse in that
tokens expire, so the setup breaks periodically and needs renewing.

My own preference is `SSH` for everything on my own hardware, and `HTTPS` plus
a credential helper for the occasional remote that has to work that way. The
important thing is to be deliberate rather than accidental, because a repo
sitting on `HTTPS` purely because that is the button `GitHub` shows by default
is the one that will interrupt you at the worst moment.

### Converting a repository from HTTPS to SSH

Nothing is lost by switching. The remote `URL` is local metadata, and history,
branches and stashes are untouched:

```bash
git -C /path/to/repo remote set-url origin git@github.com:<user>/<repo>.git
git -C /path/to/repo remote -v    # confirm
```

Do this for each straggler and the credential helper becomes irrelevant to
those repositories.

## Setting up a credential helper properly

A credential helper is a small program `Git` calls whenever it needs a username
and password for an `HTTPS` remote. It has exactly three jobs: `get`, `store`
and `erase`. Which helper you choose decides where the token ends up living.

Arch ships several with `Git` itself:

```bash
ls /usr/lib/git-core/ | grep credential
```

You will typically see:

| Helper | Storage | Verdict |
|---|---|---|
| `git-credential-store` | Plaintext in `~/.git-credentials` | Avoid |
| `git-credential-cache` | Memory, expires after a timeout | Fine, but re-prompts |
| `git-credential-libsecret` | System keyring, encrypted at rest | Use this |

`git-credential-store` is the one most tutorials recommend, including an
earlier chapter of this guide, because it is the one that works with zero setup.
It writes your token to a file in your home directory in plain text, mode `600`.
That is not a catastrophe on a single-user machine with full-disk encryption,
but it means every process running as your user can read a credential that has
write access to all your repositories. A malicious `npm` postinstall script does
not need root to find that file. Prefer the keyring.

### The libsecret helper

```bash
git config --global credential.helper /usr/lib/git-core/git-credential-libsecret
```

The full path matters here. `git config --global credential.helper libsecret`
works only if the helper is on `PATH` under that name, and on Arch it lives in
`git-core` rather than `/usr/bin`, so the short form silently fails to resolve
and `Git` falls back to prompting.

Verify it is set:

```bash
git config --global --get-all credential.helper
```

### Making sure something is actually holding the secrets

`libsecret` is a client. It talks to whatever `D-Bus` service owns
`org.freedesktop.secrets`, which is the Secret Service `API`. If nothing owns
that name, the helper fails quietly and you are back to prompts.

Check who owns it:

```bash
busctl --user list | grep -i secret
```

On a `KDE` system this is where things get muddy. Both `gnome-keyring-daemon`
and `KDE`'s own `ksecretd` can provide the Secret Service, and if both are
installed and autostarted they race for the name. Whichever wins at login is
where your tokens go. That works fine until the other one wins after an update,
at which point your saved credentials appear to have vanished, because they are
sitting in a keyring nobody is reading any more.

If you see both in that output, pick one and disable the other's autostart
rather than leaving it to chance. The symptom to watch for is credentials that
persist for weeks and then abruptly stop persisting.

### Testing the helper without pushing anything

You do not need a real repository to prove the helper works. The helper protocol
is plain text on `stdin`, so you can exercise all three operations against a
throwaway host and clean up after yourself:

```bash
# store a dummy credential
printf 'protocol=https\nhost=selftest.invalid\nusername=testuser\npassword=dummy\n\n' \
  | git credential-libsecret store

# read it back, should print the username and password
printf 'protocol=https\nhost=selftest.invalid\n\n' \
  | git credential-libsecret get

# remove it again
printf 'protocol=https\nhost=selftest.invalid\nusername=testuser\npassword=dummy\n\n' \
  | git credential-libsecret erase
```

The blank line at the end of each block is part of the protocol, not a typo. It
terminates the input. If the `get` step prints nothing, the store did not work
and the problem is the Secret Service, not `Git`.

Use a `.invalid` hostname for this. It is reserved by `RFC 2606` specifically so
that it can never resolve to a real machine, which means a mistake here cannot
leak a test credential to a live host.

### Seeding the real credential

The first push after configuring the helper still prompts, once:

```bash
git push
# Username: <your-username>
# Password: <paste your Personal Access Token, not your account password>
```

The token is generated in your forge's settings under developer settings or
access tokens. Give it the narrowest scope that covers what you need, and set an
expiry you will actually remember to renew. After that push, the helper has the
credential and the prompt stops.

If you ever need to force it to forget:

```bash
printf 'protocol=https\nhost=github.com\n\n' | git credential-libsecret erase
```

## The other half: who your commits say you are

Authentication done, now attribution. This is the part people miss.

Every commit records an author name and email. Forges match that email against
registered accounts to decide who made the commit. The key or token that pushed
it is not consulted for this at all. So a commit authored with an unrecognised
email, pushed with a perfectly valid key, lands in the repository attributed to
a plain name with no profile, no avatar, and no contribution credit.

Check what you are currently stamping onto commits:

```bash
git config --global --get user.name
git config --global --get user.email
```

Then check what a specific repository is using, since a local value overrides
the global one:

```bash
git -C /path/to/repo config --get user.email
```

The common trap is a machine used for both work and personal projects. You set
your work email globally once, during onboarding, because that was the repo in
front of you. Every personal project since has been committing under an address
that your personal forge account has never heard of.

To see how far back it goes:

```bash
git -C /path/to/repo log --format='%ae' | sort | uniq -c | sort -rn
```

### Splitting identities by directory

The clean fix is `includeIf`, a conditional include. `Git` evaluates the
condition against the repository path and pulls in an extra config file when it
matches. That way the identity follows the location of the code rather than your
memory.

Organise the split by directory first. Something like:

```
~/Projects/          personal by default
~/Projects/work/     work overrides
```

Then in `~/.gitconfig`:

```ini
[user]
    name = <your-name>
    email = <your-personal-address>

[includeIf "gitdir:~/Projects/work/"]
    path = ~/.gitconfig-work
```

And in `~/.gitconfig-work`:

```ini
[user]
    email = <your-work-address>
```

Three details that catch people out:

- The trailing slash on `gitdir:~/Projects/work/` matters. Without it the
  pattern matches a path prefix rather than a directory tree, so
  `~/Projects/workshop` would match too.
- The condition is evaluated against the repository's own path, so it applies to
  every repo underneath, at any depth.
- `includeIf` only affects repositories. Commands run outside a repository fall
  back to the global values.

Verify from inside a repository, which is the only place the condition can be
evaluated:

```bash
git -C ~/Projects/work/some-repo config --get user.email    # work address
git -C ~/Projects/personal-thing config --get user.email     # personal address
```

### Keeping your address off the internet

If you would rather not have a real email address in every public commit, most
forges offer a no-reply address that still attributes correctly. `GitHub`'s form
is `<id>+<username>@users.noreply.github.com`, and the exact string is shown in
your email settings. Use that as your personal `user.email` and enable the
setting that blocks pushes exposing your real address.

This is worth doing before your first public commit rather than after, because
rewriting author metadata across existing history means rewriting every commit
`SHA` from that point forward.

### Commits already made under the wrong identity

You cannot change history that other people have pulled without causing them
pain, so the usual answer is to leave it. If it is a private repository that
only you have cloned, the simplest route for recent commits is:

```bash
git rebase -i HEAD~<n> --exec 'git commit --amend --no-edit --reset-author'
```

This rewrites those commits with your current identity. Every rewritten commit
gets a new `SHA`, so anyone else with a clone will have a bad time. Treat it as
a tool for repositories nobody else has touched.

For most people, the pragmatic fix is the opposite direction: add the old
address to your forge account as a secondary verified email, and the existing
commits retroactively link to you with no history rewriting at all. This is
almost always the right answer.

## Confirming which account a key belongs to

If you have an `SSH` key and no longer remember which account it is registered
against, you do not need to look anything up. Ask the server:

```bash
ssh -T git@github.com
```

A successful reply greets you by account name, which tells you both that the key
is registered and exactly whose it is. `GitLab` responds similarly. A
`Permission denied (publickey)` means the key on this machine is not on any
account, and you need a new one or need to upload the existing public half.

There is no need to hunt for a "link code" or any record from when the key was
first added. The key pair is the only thing that matters, and the public half can
be re-uploaded to the account at any time from the private half:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519
```

That prints the public key derived from the private key, which you can paste
into the account's key settings. You only genuinely need a new key if the private
half is lost or you believe it has been exposed.

### Generating a replacement

```bash
ssh-keygen -t ed25519 -C "<a comment identifying this machine>"
cat ~/.ssh/id_ed25519.pub    # paste this into your account's SSH key settings
```

Use a comment that identifies the machine rather than the person, since the point
of the comment is to let you work out which key to revoke when a machine is
retired. Adding a new key does not invalidate the old one, so you can add the
new key, confirm it works, and remove the old entry afterwards with no downtime.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Prompted for username and password on push | Remote is `HTTPS` with no helper | Set the helper, or convert the remote to `SSH` |
| Account password rejected on `HTTPS` | Password auth removed in 2021 | Use a Personal Access Token |
| Helper configured but still prompting | Short helper name did not resolve | Use the full `/usr/lib/git-core/` path |
| Helper configured, nothing ever stored | No Secret Service on the bus | `busctl --user list \| grep -i secret` |
| Credentials worked, then stopped after an update | Two keyring daemons racing | Disable one of `gnome-keyring` or `ksecretd` |
| Prompted for a passphrase, not a password | This is `SSH`, not `HTTPS` | See [chapter 9](./9_ssh_agent_setup.md) |
| Commits show a name but no profile link | Author email not on the account | Add it as a secondary email, or fix `user.email` |
| `includeIf` not applying | Missing trailing slash, or run outside a repo | Add the slash, test with `git -C <repo>` |
| Token expired without warning | `PAT` expiry reached | Regenerate, then `erase` the stale credential |

## Why this is more confusing than it should be

Three things conspire here.

The first is that the word "password" appears in a prompt that cannot accept a
password. Everything about the interface suggests you are getting the password
wrong, when the real answer is that the concept no longer applies.

The second is that authentication and attribution both feel like "my account",
and they are configured in completely different places, by completely different
mechanisms, with no cross-checking between them. Nothing warns you that you are
pushing valid credentials while stamping an unrecognised email on the work. The
push succeeds. It just quietly belongs to nobody.

The third is that credential helpers depend on a `D-Bus` service that is
invisible unless you know to look for it. When the keyring is absent or
contested, the helper does not error, it simply stores nothing, and `Git` falls
back to prompting exactly as if no helper were configured. The failure looks
identical to having done nothing at all, which is the worst possible signal.

Once you separate the three layers, which mechanism authenticates, where the
secret is kept, and which email is stamped on the commit, each one is
individually simple. It is only the overlap that is hard.

| [← Previous](./13_safetycore.md) |
|:--|
