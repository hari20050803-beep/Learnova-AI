/**
 * Learnova AI — password reset endpoint.
 *
 * Firebase will not let a signed-out app set a new password: the client SDK
 * can only do it with the one-time code from Firebase's own reset email. This
 * worker holds the privilege the app cannot, so the whole reset happens inside
 * the app: the student asks for a code, receives it by email, types it in, and
 * sets a new password. No reset link, and no paid Firebase plan.
 *
 * Three endpoints, in the order they are used:
 *
 *   POST /otp     { email }                        -> emails a six digit code
 *   POST /verify  { email, code }                  -> { ticket }
 *   POST /reset   { email, ticket, newPassword }   -> password changed
 *
 * The code is generated and checked HERE, not on the device, so a modified
 * copy of the app cannot skip it. The ticket returned by /verify is signed
 * with a secret only this worker knows and expires in fifteen minutes, so the
 * reset screen never has to hold the code and the code can only be used once.
 *
 * Nothing here ever stores or reads a password. Firebase keeps only a hash,
 * and this worker only ever writes a new one.
 */

const OTP_TTL_SECONDS = 600; // ten minutes to type a six digit code
const TICKET_TTL_SECONDS = 900; // fifteen minutes to choose a password
const MAX_ATTEMPTS = 5; // then the code is burned

// Least time between two codes for one address. Slightly under the thirty
// seconds the app makes the student wait, so its own timer is what they see
// rather than a rejection from here. Without this, anyone who knows an address
// could flood that mailbox and exhaust the EmailJS quota.
//
// This is measured against the instant stored in the pending code's record,
// not by letting a key expire: KV refuses any lifetime below sixty seconds.
const RESEND_COOLDOWN_SECONDS = 25;

// Every secret the worker cannot run without. Checked before anything else so
// a missing one is reported as such, instead of failing later inside the
// Firebase call as an unreadable key.
const REQUIRED_SECRETS = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_PRIVATE_KEY',
  'EMAILJS_SERVICE_ID',
  'EMAILJS_TEMPLATE_ID',
  'EMAILJS_PUBLIC_KEY',
  'TICKET_SECRET',
];

// Reveal whether an address has an account?
//
// Firebase hides this to stop an attacker learning who is registered. It also
// means a student whose account does not exist is told a code was sent when
// none was — which is exactly the confusion this endpoint was written to end.
// For a study application used by one class the clarity is worth more than the
// disclosure. Set to false to behave like Firebase.
const REVEAL_UNKNOWN_ACCOUNT = true;

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'method-not-allowed' }, 405);
    }

    const url = new URL(request.url);

    // A deployment missing a secret is an operator problem, not a caller
    // problem. Name it in the log; tell the caller only that it failed.
    const missing = REQUIRED_SECRETS.filter((name) => !env[name]);
    if (missing.length) {
      console.error('not configured — missing secrets: ' + missing.join(', '));
      return json({ error: 'not-configured' }, 503);
    }

    try {
      switch (url.pathname) {
        case '/otp':
          return await handleOtp(request, env);
        case '/verify':
          return await handleVerify(request, env);
        case '/reset':
          return await handleReset(request, env);
        default:
          return json({ error: 'not-found' }, 404);
      }
    } catch (err) {
      // Never echo the internal message back to the app: it can carry the
      // service account address or a Google error id.
      console.error(url.pathname, err && err.stack ? err.stack : err);
      return json({ error: 'server-error' }, 500);
    }
  },
};

// ---------------------------------------------------------------------------
// 1. Send the code
// ---------------------------------------------------------------------------

async function handleOtp(request, env) {
  const body = await readJson(request);
  const email = normaliseEmail(body.email);
  if (!email) return json({ error: 'bad-email' }, 400);

  // Refuse a second code too soon, before the account is even looked up: the
  // cheapest request should be the one that gets turned away.
  //
  // The time is read from the pending code's own record rather than from a
  // second key. KV will not accept a lifetime under sixty seconds, so a key
  // that expired on its own could not express a cooldown shorter than that;
  // comparing the stored instant can.
  const key = await otpKey(email);
  const pending = await env.OTP_KV.get(key);
  if (pending) {
    try {
      const { sentAt } = JSON.parse(pending);
      if (Date.now() - sentAt < RESEND_COOLDOWN_SECONDS * 1000) {
        return json({ error: 'too-soon' }, 429);
      }
    } catch {
      // An unreadable record should not lock anyone out; fall through.
    }
  }

  const user = await lookupUser(env, email);
  if (!user) {
    if (REVEAL_UNKNOWN_ACCOUNT) return json({ error: 'no-account' }, 404);
    return json({ ok: true }); // indistinguishable from success
  }

  // Six digits from a cryptographic source, never from Math.random.
  const code = String(randomInt(100000, 999999));

  // Send first, store second. If the email fails there is nothing to clean up
  // and nothing blocking an immediate retry; the reverse order would leave a
  // code the student never received and a cooldown they did not earn.
  await sendCodeEmail(env, email, code);

  await env.OTP_KV.put(
    key,
    JSON.stringify({ code, attempts: 0, sentAt: Date.now() }),
    { expirationTtl: OTP_TTL_SECONDS },
  );
  return json({ ok: true });
}

// ---------------------------------------------------------------------------
// 2. Check the code, hand back a ticket
// ---------------------------------------------------------------------------

async function handleVerify(request, env) {
  const body = await readJson(request);
  const email = normaliseEmail(body.email);
  const code = String(body.code || '').trim();
  if (!email || !/^\d{6}$/.test(code)) return json({ error: 'bad-request' }, 400);

  const key = await otpKey(email);
  const raw = await env.OTP_KV.get(key);
  if (!raw) return json({ error: 'expired' }, 400);

  const record = JSON.parse(raw);
  if (record.attempts >= MAX_ATTEMPTS) {
    await env.OTP_KV.delete(key);
    return json({ error: 'too-many-attempts' }, 429);
  }

  if (!timingSafeEqual(record.code, code)) {
    // Count the miss, keeping whatever life the entry had left.
    const elapsed = Math.floor((Date.now() - record.sentAt) / 1000);
    const remaining = Math.max(60, OTP_TTL_SECONDS - elapsed);
    await env.OTP_KV.put(
      key,
      JSON.stringify({ ...record, attempts: record.attempts + 1 }),
      { expirationTtl: remaining },
    );
    return json(
      { error: 'wrong-code', attemptsLeft: MAX_ATTEMPTS - record.attempts - 1 },
      400,
    );
  }

  // Correct. Burn the code so it cannot be replayed, and issue the ticket.
  await env.OTP_KV.delete(key);
  const ticket = await issueTicket(env, email);
  return json({ ok: true, ticket });
}

// ---------------------------------------------------------------------------
// 3. Set the new password
// ---------------------------------------------------------------------------

async function handleReset(request, env) {
  const body = await readJson(request);
  const email = normaliseEmail(body.email);
  const ticket = String(body.ticket || '');
  const newPassword = String(body.newPassword || '');

  if (!email || !ticket) return json({ error: 'bad-request' }, 400);
  if (!(await ticketIsValid(env, ticket, email))) {
    return json({ error: 'bad-ticket' }, 401);
  }

  const problem = passwordProblem(newPassword);
  if (problem) return json({ error: 'weak-password', detail: problem }, 400);

  const user = await lookupUser(env, email);
  if (!user) return json({ error: 'no-account' }, 404);

  await adminRequest(env, 'accounts:update', {
    localId: user.localId,
    password: newPassword,
  });

  return json({ ok: true });
}

// ---------------------------------------------------------------------------
// Password rules — the same five the Register screen enforces
// ---------------------------------------------------------------------------

function passwordProblem(password) {
  if (password.length < 8) return 'Password must be at least 8 characters.';
  if (!/[A-Z]/.test(password)) return 'Password needs an uppercase letter.';
  if (!/[a-z]/.test(password)) return 'Password needs a lowercase letter.';
  if (!/[0-9]/.test(password)) return 'Password needs a number.';
  if (!/[^A-Za-z0-9\s]/.test(password)) return 'Password needs a special symbol.';
  return null;
}

// ---------------------------------------------------------------------------
// Tickets — a signed note saying "this address proved itself just now"
// ---------------------------------------------------------------------------

async function issueTicket(env, email) {
  const payload = {
    email,
    exp: Math.floor(Date.now() / 1000) + TICKET_TTL_SECONDS,
    jti: crypto.randomUUID(),
  };
  const body = b64url(new TextEncoder().encode(JSON.stringify(payload)));
  const sig = await hmac(env.TICKET_SECRET, body);
  return `${body}.${sig}`;
}

async function ticketIsValid(env, ticket, email) {
  // Everything in here is attacker-controlled, so a malformed ticket must come
  // back as "no" rather than as an exception: a throw would surface as a 500
  // and tell whoever sent it that they had found an unhandled path.
  try {
    const [body, sig] = ticket.split('.');
    if (!body || !sig) return false;
    if (!timingSafeEqual(await hmac(env.TICKET_SECRET, body), sig)) return false;

    const payload = JSON.parse(new TextDecoder().decode(unb64url(body)));
    if (payload.email !== email) return false;
    return payload.exp > Math.floor(Date.now() / 1000);
  } catch {
    return false;
  }
}

async function hmac(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(message),
  );
  return hex(new Uint8Array(sig));
}

// ---------------------------------------------------------------------------
// Firebase admin, over REST — no SDK, so this runs on the Workers runtime
// ---------------------------------------------------------------------------

let cachedToken = null; // { value, expiresAt } — survives while the isolate does

async function accessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = b64url(
    new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  );
  const claim = b64url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: env.FIREBASE_CLIENT_EMAIL,
        scope: 'https://www.googleapis.com/auth/identitytoolkit',
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
      }),
    ),
  );

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(env.FIREBASE_PRIVATE_KEY),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claim}`),
  );
  const jwt = `${header}.${claim}.${b64url(new Uint8Array(signature))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`token ${res.status}: ${await res.text()}`);

  const data = await res.json();
  cachedToken = { value: data.access_token, expiresAt: now + data.expires_in };
  return cachedToken.value;
}

async function adminRequest(env, method, body) {
  const token = await accessToken(env);
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/${method}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) throw new Error(`${method} ${res.status}: ${await res.text()}`);
  return res.json();
}

async function lookupUser(env, email) {
  const data = await adminRequest(env, 'accounts:lookup', { email: [email] });
  return data.users && data.users.length ? data.users[0] : null;
}

// ---------------------------------------------------------------------------
// The code email — sent from here, so the EmailJS private key never ships
// inside the application
// ---------------------------------------------------------------------------

async function sendCodeEmail(env, email, code) {
  const res = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: 'https://learnova.app',
    },
    body: JSON.stringify({
      service_id: env.EMAILJS_SERVICE_ID,
      template_id: env.EMAILJS_TEMPLATE_ID,
      user_id: env.EMAILJS_PUBLIC_KEY,
      accessToken: env.EMAILJS_PRIVATE_KEY,
      template_params: {
        to_email: email,
        email: email,
        otp_code: code,
        passcode: code,
        time: '10 minutes',
      },
    }),
  });
  if (!res.ok) throw new Error(`emailjs ${res.status}: ${await res.text()}`);
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

function normaliseEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : null;
}

/** The KV key is a hash, so the store never holds a list of addresses. */
async function otpKey(email) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(`reset:${email}`),
  );
  return `reset:${hex(new Uint8Array(digest))}`;
}

function randomInt(min, max) {
  const range = max - min + 1;
  const buf = new Uint32Array(1);
  // Reject the tail of the range so every value is equally likely.
  const limit = Math.floor(0xffffffff / range) * range;
  let value;
  do {
    crypto.getRandomValues(buf);
    value = buf[0];
  } while (value >= limit);
  return min + (value % range);
}

/** Compares without leaking, through timing, how much of the value matched. */
function timingSafeEqual(a, b) {
  const x = String(a);
  const y = String(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}

function hex(bytes) {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function b64url(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function unb64url(text) {
  const padded = text.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(padded + '='.repeat((4 - (padded.length % 4)) % 4));
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

/** Turns the PEM in the service account file into the bytes WebCrypto wants. */
function pemToBytes(pem) {
  const text = String(pem).replace(/\\n/g, '\n'); // secrets arrive escaped
  if (!text.includes('BEGIN PRIVATE KEY')) {
    // Saying this plainly saves a long hunt: the same fault would otherwise
    // surface as an unreadable-base64 error three frames deeper.
    throw new Error(
      'FIREBASE_PRIVATE_KEY is not a PEM private key. Set it to the whole ' +
        '"private_key" value from the service account JSON, including the ' +
        'BEGIN and END lines.',
    );
  }
  const body = text
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}
