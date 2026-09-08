/// ---------------------------------------------------------------------------
/// EMAIL (OTP) CONFIGURATION
///
/// The registration OTP is emailed through EmailJS, which is built for sending
/// mail straight from a client app — no server and no SMTP password needed.
///
/// ===========================================================================
/// THE THREE VALUES BELOW ARE THE ONLY THING YOU EVER NEED TO EDIT.
/// ===========================================================================
///
/// Where each one comes from (free account, about 5 minutes):
///
///   serviceId   EmailJS -> "Email Services" -> connect Gmail (or any
///               provider) -> copy the ID, looks like  service_ab12cde
///
///   templateId  EmailJS -> "Email Templates" -> Create New Template ->
///               copy the ID, looks like  template_xy34fgh
///               Inside the template set:
///                   To Email : {{to_email}}
///                   Subject  : Your Learnova AI verification code
///                   Content  : Your Learnova AI code is {{otp_code}}.
///                              It expires in 5 minutes.
///
///   publicKey   EmailJS -> "Account" -> General / API Keys -> Public Key,
///               looks like  A1bC2dE3fG4hI5jK
///
/// ONE EXTRA STEP THAT PEOPLE ALWAYS MISS
/// EmailJS blocks non-browser apps by default, so a Flutter app gets
/// "API calls are disabled for non-browser applications" even when all three
/// IDs are correct. Fix it once in EmailJS -> Account -> Security ->
/// turn OFF "Block API requests from non-browser applications" (older name:
/// "Allow EmailJS API for non-browser applications" -> turn it ON).
/// [OtpService] also sends an Origin header, which covers most accounts.
///
/// SECURITY NOTE
/// A public key is meant to ship inside an app, so this is safe. Keep
/// "Use Private Key" OFF in the dashboard, and set the monthly quota + rate
/// limit so nobody can abuse the template.
/// ---------------------------------------------------------------------------
class EmailConfig {
  // ---- 1. EmailJS service ID -------------------------------------------
  static const String serviceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: 'service_50m6dmw',
  );

  // ---- 2. EmailJS template ID ------------------------------------------
  static const String templateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: 'template_z2tl92g',
  );

  // ---- 3. EmailJS public key -------------------------------------------
  static const String publicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: 'DLJWaMysgJMsHkkPp',
  );

  // ---- 4. Password-reset template --------------------------------------
  /// Template used by the Forgot Password flow.
  ///
  /// Defaults to [templateId] so password-reset codes send immediately with
  /// the template that is already working. To use a dedicated one, create
  /// "Learnova AI Password Reset" in EmailJS with the SAME variables
  /// ({{to_email}}, {{otp_code}}, {{app_name}}) and paste its ID here.
  static const String resetTemplateId = String.fromEnvironment(
    'EMAILJS_RESET_TEMPLATE_ID',
    defaultValue: 'template_z2tl92g',
  );

  /// Where EmailJS receives send requests. Does not change.
  static const String endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Sent as the Origin header. EmailJS treats the request as a browser call,
  /// which is what stops the "non-browser applications" rejection.
  static const String origin = 'http://localhost';

  /// Name shown inside the email body.
  static const String appName = 'Learnova AI';
}
