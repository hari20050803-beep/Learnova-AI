/// ---------------------------------------------------------------------------
/// PASSWORD RESET ENDPOINT
///
/// >>> PASTE THE ADDRESS OF YOUR DEPLOYED WORKER BELOW <<<
///
/// Forgotten passwords are reset entirely inside the application: the student
/// asks for a code, receives it by email, types it in and chooses a new
/// password. No reset link and no email to open.
///
/// That needs one privilege the application is not allowed to hold. Firebase
/// will not let a signed-out client set a password — only the one-time code
/// from its own reset email can do that — so the change is made by a small
/// endpoint that holds the service account instead. Its source is in
/// `server/src/worker.js` and `server/README.md` explains how to deploy it.
/// It runs on the Cloudflare Workers free plan: no card, and no Firebase
/// Blaze plan either.
///
/// After deploying, `wrangler deploy` prints the address. Paste it below
/// WITHOUT a trailing slash, for example:
///
///     https://learnova-reset.your-name.workers.dev
///
/// Until it is filled in the Forgot Password screen says so plainly rather
/// than failing at the last step.
/// ---------------------------------------------------------------------------
class ResetConfig {
  /// Base address of the deployed reset endpoint.
  static const String endpoint = 'https://learnova-reset.learnova-ai.workers.dev';

  /// True while the address above has not been filled in.
  static bool get isMissing =>
      endpoint.isEmpty || endpoint == 'PASTE_YOUR_WORKER_URL_HERE';
}
