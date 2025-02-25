import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subiquity_client/subiquity_client.dart';
import 'package:ubuntu_bootstrap/l10n.dart';
import 'package:ubuntu_logger/ubuntu_logger.dart';
import 'package:ubuntu_wizard/ubuntu_wizard.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import 'confirm_model.dart';

/// @internal
final log = Logger('confirm');

class ConfirmPage extends ConsumerWidget {
  const ConfirmPage({super.key});

  static Future<bool> load(WidgetRef ref) {
    return ref.read(confirmModelProvider).init().then((_) => true);
  }

  String prettyFormatDisk(Disk disk) {
    final fullName = <String?>[
      disk.model,
      disk.vendor,
    ].where((p) => p?.isNotEmpty == true).join(' ');
    return '$fullName <b>${disk.sysname}</b>';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = UbuntuBootstrapLocalizations.of(context);
    final model = ref.watch(confirmModelProvider);
    return WizardPage(
      title: YaruWindowTitleBar(
        title: Text(lang.confirmPageTitle),
      ),
      header: Text(lang.confirmHeader),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.confirmDevicesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: kWizardSpacing / 2),
              Text(lang.confirmPartitionTables)
            ],
          ),
          const SizedBox(height: kWizardSpacing / 2),
          Flexible(
            child: YaruBorderContainer(
              color: Theme.of(context).colorScheme.surface,
              padding: EdgeInsets.symmetric(
                  horizontal: kWizardPadding.left, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final disk in model.disks)
                      Html(
                        data: prettyFormatDisk(disk),
                        style: {'body': Style(margin: Margins.zero)},
                        key: ValueKey(disk),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: kWizardSpacing),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.confirmPartitionsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: kWizardSpacing / 2),
              Text(lang.confirmPartitionChanges),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: YaruBorderContainer(
              color: Theme.of(context).colorScheme.surface,
              padding: EdgeInsets.symmetric(
                  horizontal: kWizardPadding.left, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in model.partitions.entries)
                      for (final partition in entry.value)
                        _PartitionLabel(
                          entry.key,
                          partition,
                          model.getOriginalPartition(
                              entry.key, partition.number ?? -1),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomBar: WizardBar(
        leading: WizardButton.previous(context),
        trailing: [
          WizardButton.next(
            context,
            highlighted: true,
            label: lang.confirmInstallButton,
            onNext: () {
              // start installation after the page transition (#1393)
              Future.delayed(kThemeAnimationDuration).then((_) async {
                await model.markNetworkConfigured();
                await model.startInstallation();
              });
            },
          ),
        ],
      ),
    );
  }
}

class _PartitionLabel extends StatelessWidget {
  _PartitionLabel(this.sysname, this.partition, this.original)
      : super(key: ValueKey(partition));

  final String sysname;
  final Partition partition;
  final Partition? original;

  String formatPartition(BuildContext context) {
    final lang = UbuntuBootstrapLocalizations.of(context);
    if (partition.resize == true) {
      return lang.confirmPartitionResize(
        partition.sysname,
        context.formatByteSize(original?.size ?? 0),
        context.formatByteSize(partition.size ?? 0),
      );
    } else if (partition.wipe != null && partition.mount?.isNotEmpty == true) {
      return lang.confirmPartitionFormatMount(
        partition.sysname,
        partition.format ?? '',
        partition.mount ?? '',
      );
    } else if (partition.wipe != null && partition.format?.isNotEmpty == true) {
      return lang.confirmPartitionFormat(
        partition.sysname,
        partition.format ?? '',
      );
    } else if (partition.mount?.isNotEmpty == true) {
      return lang.confirmPartitionMount(
        partition.sysname,
        partition.mount ?? '',
      );
    } else {
      assert(partition.preserve == false);
      return lang.confirmPartitionCreate(partition.sysname);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Html(
      data: formatPartition(context),
      style: {'body': Style(margin: Margins.zero)},
    );
  }
}
