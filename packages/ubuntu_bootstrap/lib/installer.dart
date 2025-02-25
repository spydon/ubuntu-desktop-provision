import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gsettings/gsettings.dart';
import 'package:path/path.dart' as p;
import 'package:subiquity_client/subiquity_client.dart';
import 'package:subiquity_client/subiquity_server.dart';
import 'package:timezone_map/timezone_map.dart';
import 'package:ubuntu_flavor/ubuntu_flavor.dart';
import 'package:ubuntu_logger/ubuntu_logger.dart';
import 'package:ubuntu_provision/ubuntu_provision.dart';
import 'package:ubuntu_utils/ubuntu_utils.dart';
import 'package:ubuntu_wizard/ubuntu_wizard.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

import 'installer/installer_wizard.dart';
import 'l10n.dart';
import 'services.dart';
import 'slides.dart';

export 'installer/installer_wizard.dart';
export 'slides.dart';

Future<void> runInstallerApp(
  List<String> args, {
  List<String>? pages,
  List<WidgetBuilder>? slides,
  UbuntuFlavor? flavor,
  ThemeData? theme,
  ThemeData? darkTheme,
  GenerateAppTitle? onGenerateTitle,
  Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
}) async {
  final options = parseCommandLine(args, onPopulateOptions: (parser) {
    parser.addOption('config',
        valueHelp: 'path', help: 'Path to a config file');
    parser.addFlag('dry-run',
        defaultsTo: Platform.environment['LIVE_RUN'] != '1',
        help: 'Run Subiquity server in dry-run mode');
    parser.addOption('dry-run-config',
        valueHelp: 'path', help: 'Path of the dry-run config file');
    parser.addOption('machine-config',
        valueHelp: 'path',
        defaultsTo: 'examples/machines/simple.json',
        help: 'Path of the machine config (dry-run only)');
    parser.addOption('source-catalog',
        valueHelp: 'path',
        defaultsTo: 'examples/sources/desktop.yaml',
        help: 'Path of the source catalog (dry-run only)');
    parser.addFlag('welcome', aliases: ['try-or-install'], hide: true);
    parser.addOption('pages',
        valueHelp: 'path', help: 'A comma-separated list of pages', hide: true);
  })!;
  final liveRun = options['dry-run'] != true;
  final exe = p.basename(Platform.resolvedExecutable);
  final log =
      Logger.setup(path: liveRun ? '/var/log/installer/$exe.log' : null);

  final serverMode = liveRun ? ServerMode.LIVE : ServerMode.DRY_RUN;
  final subiquityPath = await getSubiquityPath()
      .then((dir) => Directory(dir).existsSync() ? dir : null);
  final endpoint = await defaultEndpoint(serverMode);
  final process = liveRun
      ? null
      : SubiquityProcess.python(
          'subiquity.cmd.server',
          serverMode: ServerMode.DRY_RUN,
          subiquityPath: subiquityPath,
        );

  final baseName = p.basename(Platform.resolvedExecutable);

  // conditional registration if not already registered by flavors or tests
  tryRegisterService<ActiveDirectoryService>(
      () => SubiquityActiveDirectoryService(getService<SubiquityClient>()));
  tryRegisterServiceInstance<ArgResults>(options);
  tryRegisterService<ConfigService>(
    () => ConfigService(scope: 'bootstrap', path: options['config'] as String?),
  );
  tryRegisterService<DesktopService>(() => GnomeService());
  tryRegisterServiceFactory<GSettings, String>((schema) => GSettings(schema));
  tryRegisterService<IdentityService>(() => SubiquityIdentityService(
      getService<SubiquityClient>(), getService<PostInstallService>()));
  tryRegisterService<InstallerService>(() => InstallerService(
      getService<SubiquityClient>(),
      config: tryGetService<ConfigService>(),
      pages: (options['pages'] as String?)?.split(',') ?? pages));
  tryRegisterService(JournalService.new);
  tryRegisterService<KeyboardService>(
      () => SubiquityKeyboardService(getService<SubiquityClient>()));
  tryRegisterService<LocaleService>(
      () => SubiquityLocaleService(getService<SubiquityClient>()));
  tryRegisterService<NetworkService>(
      () => SubiquityNetworkService(getService<SubiquityClient>()));
  tryRegisterService(() => PostInstallService('/tmp/$baseName.conf'));
  tryRegisterService(PowerService.new);
  tryRegisterService(ProductService.new);
  tryRegisterService(() => RefreshService(getService<SubiquityClient>()));
  tryRegisterService<SessionService>(
      () => SubiquitySessionService(getService<SubiquityClient>()));
  if (liveRun) tryRegisterService(SoundService.new);
  tryRegisterService(() => StorageService(getService<SubiquityClient>()));
  tryRegisterService(SubiquityClient.new);
  tryRegisterService(
      () => SubiquityServer(process: process, endpoint: endpoint));
  tryRegisterService<TelemetryService>(() {
    var path = '/var/log/installer/telemetry';
    if (kDebugMode) {
      final exe = Platform.resolvedExecutable;
      path = '${p.dirname(exe)}/.${p.basename(exe)}/telemetry';
    }
    return TelemetryService(path);
  });
  tryRegisterService<ThemeService>(GtkThemeService.new);
  tryRegisterService<TimezoneService>(
      () => SubiquityTimezoneService(getService<SubiquityClient>()));
  tryRegisterService(UdevService.new);
  tryRegisterService(UrlLauncher.new);

  final initialized = getService<SubiquityServer>().start(args: [
    if (options['dry-run-config'] != null)
      '--dry-run-config=${options['dry-run-config']}',
    if (options['machine-config'] != null)
      '--machine-config=${options['machine-config']}',
    if (options['source-catalog'] != null)
      '--source-catalog=${options['source-catalog']}',
    '--storage-version=2',
    '--dry-run-config=examples/dry-run-configs/tpm.yaml',
    ...options.rest,
  ]).then(_initInstallerApp);

  runZonedGuarded(() async {
    FlutterError.onError = (error) {
      log.error('Unhandled exception', error.exception, error.stack);
    };

    final window = await YaruWindow.ensureInitialized();
    await window.onClose(_closeInstallerApp);

    runApp(ProviderScope(
      child: SlidesContext(
        slides: slides ?? defaultSlides,
        child: Consumer(
          builder: (context, ref, child) {
            if (flavor != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(flavorProvider.notifier).state = flavor;
              });
            }
            return WizardApp(
              flavor: flavor,
              theme: theme,
              darkTheme: darkTheme,
              onGenerateTitle: onGenerateTitle ??
                  (context) {
                    final flavor = ref.watch(flavorProvider);
                    return UbuntuBootstrapLocalizations.of(context)
                        .windowTitle(flavor.name);
                  },
              locale: ref.watch(localeProvider),
              localizationsDelegates: [
                ...?localizationsDelegates,
                ...GlobalUbuntuBootstrapLocalizations.delegates,
              ],
              supportedLocales: supportedLocales,
              home: DefaultAssetBundle(
                bundle: ProxyAssetBundle(
                  rootBundle,
                  package: 'ubuntu_bootstrap',
                ),
                child: InstallerWizard(
                  welcome: options['welcome'] as bool?,
                ),
              ),
            );
          },
        ),
      ),
    ));
  }, (error, stack) => log.error('Unhandled exception', error, stack));

  return initialized;
}

Future<void> _initInstallerApp(Endpoint endpoint) async {
  getService<SubiquityClient>().open(endpoint);

  await getService<InstallerService>().init();
  await getService<DesktopService>().inhibit();
  await getService<RefreshService>().check();

  var geo = tryGetService<GeoService>();
  if (geo == null) {
    final geodata = Geodata.asset();
    final geoname = Geoname.ubuntu(geodata: geodata);
    geo = GeoService(sources: [geodata, geoname]);
    registerServiceInstance(geo);
  }
  await geo.init();

  final telemetry = getService<TelemetryService>();
  await telemetry.init({
    'Type': 'Flutter',
    'OEM': false,
    'Media': getService<ProductService>().getProductInfo().toString(),
  });
}

Future<bool> _closeInstallerApp() async {
  await getService<SubiquityClient>().close();
  await getService<SubiquityServer>().stop();
  await getService<DesktopService>().close();
  return true;
}
