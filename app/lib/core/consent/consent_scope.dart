/// Mirror of backend's ConsentScope StrEnum from PR #26.
/// Plain string values match the wire format (backend uses TEXT, not enum).
enum ConsentScope {
  emailTransactional('email_transactional'),
  emailMarketing('email_marketing'),
  inAppNotifications('in_app_notifications'),
  whatsappNotifications('whatsapp_notifications'),
  smsNotifications('sms_notifications'),
  profileVisibilityRecruiters('profile_visibility_recruiters'),
  thirdPartySharingRecruiters('third_party_sharing_recruiters');

  const ConsentScope(this.wire);
  final String wire;

  static ConsentScope? fromWire(String wire) {
    for (final s in ConsentScope.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }

  /// Active scopes shown in the v0 Privacy UI. Reserved scopes are hidden.
  static const v0VisibleScopes = <ConsentScope>[
    ConsentScope.emailTransactional,
    ConsentScope.emailMarketing,
    ConsentScope.inAppNotifications,
  ];
}
