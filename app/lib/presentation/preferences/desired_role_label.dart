import 'package:flutter/widgets.dart';

import 'package:jobify_app/core/l10n/l10n_ext.dart';
import 'package:jobify_app/data/preferences/desired_role.dart';

/// Localized display label for [DesiredRole]. Reused by the preferences
/// screen, edit-profile screen, and the profile spec sheet. `unknown` should
/// never reach the UI (dropdowns exclude it; the profile display gates on
/// it separately), but returns a safe fallback if it somehow does.
String desiredRoleLabel(BuildContext context, DesiredRole role) {
  final l10n = context.l10n;
  return switch (role) {
    DesiredRole.softwareEngineering => l10n.desiredRoleSoftwareEngineering,
    DesiredRole.dataAnalytics => l10n.desiredRoleDataAnalytics,
    DesiredRole.productManagement => l10n.desiredRoleProductManagement,
    DesiredRole.design => l10n.desiredRoleDesign,
    DesiredRole.sales => l10n.desiredRoleSales,
    DesiredRole.marketing => l10n.desiredRoleMarketing,
    DesiredRole.customerSupport => l10n.desiredRoleCustomerSupport,
    DesiredRole.operations => l10n.desiredRoleOperations,
    DesiredRole.financeAccounting => l10n.desiredRoleFinanceAccounting,
    DesiredRole.hrRecruiting => l10n.desiredRoleHrRecruiting,
    DesiredRole.legal => l10n.desiredRoleLegal,
    DesiredRole.consulting => l10n.desiredRoleConsulting,
    DesiredRole.businessDevelopment => l10n.desiredRoleBusinessDevelopment,
    DesiredRole.contentCommunications => l10n.desiredRoleContentCommunications,
    DesiredRole.administration => l10n.desiredRoleAdministration,
    DesiredRole.other => l10n.desiredRoleOther,
    DesiredRole.unknown => l10n.desiredRoleUnknown,
  };
}
