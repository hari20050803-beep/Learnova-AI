# Learnova AI — password reset endpoint

A single Cloudflare Worker that lets a student reset a forgotten password
**inside the application**: ask for a code, receive it by email, type it in,
choose a new password. No reset link to open.

## Why it exists

Firebase deliberately refuses to let a signed-out client set a password. The
client SDK offers only `confirmPasswordReset()`, which needs the one-time
`oobCode` that Firebase puts inside its own reset email — otherwise anyone
could reset any account from a modified copy of the app.

So the privilege has to live somewhere the app cannot reach. This worker holds
the Firebase service account and makes the change on the app's behalf, after
checking a code it generated itself. It runs on the **Cloudflare Workers free
plan**: no card, and no Firebase Blaze plan either.

## What it does

| Endpoint | Body | Result |
|---|---|---|
| `POST /otp` | `{ email }` | emails a six digit code, valid ten minutes |
| `POST /verify` | `{ email, code }` | `{ ticket }` — signed, valid fifteen minutes |
| `POST /reset` | `{ email, ticket, newPassword }` | password changed |

The code is generated and checked on the server, so a modified app cannot skip
it. It is stored under a **hash** of the address, dies after ten minutes, is
deleted the moment it is used, and is burned after five wrong guesses. The
ticket returned by `/verify` is an HMAC over the address and an expiry, so the
reset screen never has to carry the code and the code can never be replayed.

No password is ever stored or read. Firebase keeps only a hash; this worker
only writes a new one.

## Deploying it

You need a free Cloudflare account. Everything below is free.

### 1. Get the Firebase service account

Firebase Console → your project → gear icon → **Project settings** →
**Service accounts** → **Generate new private key**. A `.json` file downloads.
Keep it off version control — it can change any password in the project.

From that file you need three values: `project_id`, `client_email` and
`private_key`.

### 2. Install the tool and sign in

```bash
cd server
npx wrangler login
```

### 3. Create the store for pending codes

```bash
npx wrangler kv namespace create OTP_KV
```

It prints an `id`. Paste it into `wrangler.toml`, replacing
`PASTE_THE_KV_NAMESPACE_ID_HERE`.

### 4. Set the secrets

Each command asks for the value and stores it encrypted. Nothing secret goes
in a file.

```bash
npx wrangler secret put FIREBASE_PROJECT_ID
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY
npx wrangler secret put EMAILJS_SERVICE_ID
npx wrangler secret put EMAILJS_TEMPLATE_ID
npx wrangler secret put EMAILJS_PUBLIC_KEY
npx wrangler secret put EMAILJS_PRIVATE_KEY
npx wrangler secret put TICKET_SECRET
```

Notes on three of them:

- **`FIREBASE_PRIVATE_KEY`** — paste the whole value from the JSON file,
  including `-----BEGIN PRIVATE KEY-----`. The `\n` sequences in it are fine;
  the worker converts them.
- **`EMAILJS_PRIVATE_KEY`** — EmailJS → Account → API Keys → Private Key.
  This is why the reset code is sent from here and not from the app: a private
  key must never ship inside an APK.
- **`TICKET_SECRET`** — any long random string you invent. It only ever has to
  match itself. For example: `openssl rand -hex 32`.

### 5. Turn on the EmailJS private key

EmailJS → Account → Security → switch **Use Private Key** ON. The app no
longer calls EmailJS for reset codes, so this no longer breaks anything, and
it stops anyone using your template from outside.

### 6. Deploy

```bash
npx wrangler deploy
```

It prints an address like `https://learnova-reset.your-name.workers.dev`.

### 7. Tell the app where it is

Open `lib/config/reset_config.dart` and paste that address into `endpoint`,
**without** a trailing slash. Rebuild the app.

## Checking it works

```bash
curl -X POST https://YOUR-WORKER-URL/otp \
  -H "Content-Type: application/json" \
  -d '{"email":"the-address-on-your-account@example.com"}'
```

- `{"ok":true}` — the code is on its way.
- `{"error":"no-account"}` — no Firebase user has that address. This is the
  answer the old flow could never give: Firebase reports success whether or
  not the address is registered, which is why the app used to promise an email
  that was never sent.

## Tests

```bash
node test/helpers.test.js
```

Twelve checks over the password rules, the address check and the code
comparison.

The endpoints can be exercised without deploying and without a Cloudflare
account, using wrangler's local simulator:

```bash
echo 'TICKET_SECRET = "local-test-secret"' > .dev.vars
npx wrangler dev --local --port 8788
```

Then, from another terminal:

```bash
# routing and input validation
curl -X POST localhost:8788/nope                       # {"error":"not-found"}    404
curl -X POST localhost:8788/otp    -d '{"email":"x"}'  # {"error":"bad-email"}    400
curl -X POST localhost:8788/verify -d '{"email":"a@b.com","code":"123456"}'
                                                       # {"error":"expired"}      400

# a forged ticket, and one minted for a different address, are both refused
curl -X POST localhost:8788/reset   -d '{"email":"a@b.com","ticket":"ZmFrZQ.deadbeef","newPassword":"Learn1a!"}'
                                                       # {"error":"bad-ticket"}   401
```

With a genuine ticket the password rules run before Firebase is touched, so a
weak password comes back as `{"error":"weak-password","detail":"..."}` naming
the rule that failed. Only the Firebase call itself needs the deployed secrets.

`.dev.vars` is git-ignored. Delete it when you are done.

## One deliberate choice

`REVEAL_UNKNOWN_ACCOUNT` at the top of `src/worker.js` is `true`, so an
unregistered address is told so. Firebase hides this to stop an attacker
learning who has an account. For a study application used by one class, a
student being told plainly that they typed the wrong address is worth more
than the disclosure. Set it to `false` to behave like Firebase.
