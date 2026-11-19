// Banner shown on the meetings screen while the models required by the
// current settings are not installed, linking to the models screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../speech/model_catalog.dart';
import '../navigation.dart';
import '../strings_ar.dart';
import '../ui_providers.dart';
import 'common.dart';

/// "Models missing" banner; renders nothing when everything is installed.
class ModelsMissingBanner extends ConsumerWidget {
  /// Creates the banner.
  const ModelsMissingBanner({super.key, this.padding = EdgeInsets.zero});

  /// Outer padding when shown.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingModelsProvider);
    if (missing == null || missing.isEmpty) return const SizedBox.shrink();
    final names = missing
        .map((id) => ModelCatalog.tryById(id)?.displayNameAr ?? id)
        .join('، ');
    return Padding(
      padding: padding,
      child: ErrorBanner(
        severity: BannerSeverity.warning,
        title: S.modelsMissingTitle,
        message: S.modelsMissingBody(names),
        retryLabel: S.openModels,
        onRetry: () => openModelsScreen(context),
      ),
    );
  }
}
