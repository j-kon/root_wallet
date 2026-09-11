import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/network/network_transport_config.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/settings/presentation/providers/network_transport_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class ConnectionRoutingPage extends ConsumerStatefulWidget {
  const ConnectionRoutingPage({super.key});

  @override
  ConsumerState<ConnectionRoutingPage> createState() =>
      _ConnectionRoutingPageState();
}

class _ConnectionRoutingPageState extends ConsumerState<ConnectionRoutingPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  NetworkTransportMode _selectedMode = NetworkTransportMode.direct;
  bool _isTesting = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _populateFromConfig(NetworkConfiguration config) {
    if (_initialized) return;
    _selectedMode = config.transportMode;
    if (config.proxyConfig != null) {
      _hostController.text = config.proxyConfig!.host;
      _portController.text = config.proxyConfig!.port.toString();
      _usernameController.text = config.proxyConfig!.username ?? '';
      _passwordController.text = config.proxyConfig!.password ?? '';
    } else {
      _hostController.text = '127.0.0.1';
      _portController.text = '9050';
    }
    _initialized = true;
  }

  Socks5ProxyConfig? _buildConfigFromInputs({bool showErrors = true}) {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (host.isEmpty) {
      if (showErrors) {
        _showError('Proxy host cannot be empty.');
      }
      return null;
    }

    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      if (showErrors) {
        _showError('Proxy port must be an integer between 1 and 65535.');
      }
      return null;
    }

    try {
      return Socks5ProxyConfig(
        host: host,
        port: port,
        username: username.isEmpty ? null : username,
        password: password.isEmpty ? null : password,
      );
    } catch (e) {
      if (showErrors) {
        _showError(e.toString().replaceAll('FormatException: ', ''));
      }
      return null;
    }
  }

  void _showError(String message) {
    setState(() {
      _testErrorMessage = message;
      _testSuccessMessage = null;
    });
  }

  Future<void> _runConnectionTest() async {
    final config = _buildConfigFromInputs(showErrors: true);
    if (config == null) return;

    setState(() {
      _isTesting = true;
      _testErrorMessage = null;
      _testSuccessMessage = null;
    });

    HapticFeedback.selectionClick();
    final controller = ref.read(networkTransportProvider.notifier);
    final success = await controller.testConnection(config);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      if (success) {
        _testSuccessMessage =
            'Connected to Electrum node via SOCKS5 (${config.displayAddress}).';
        _testErrorMessage = null;
      } else {
        _testErrorMessage =
            'SOCKS5 proxy is unavailable. Root Wallet will not fall back to a direct connection. Check proxy host, port, and external Tor/proxy status.';
        _testSuccessMessage = null;
      }
    });
  }

  Future<void> _saveConfiguration() async {
    HapticFeedback.mediumImpact();
    final controller = ref.read(networkTransportProvider.notifier);

    if (_selectedMode == NetworkTransportMode.direct) {
      await controller.revertToDirect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to direct connection.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final config = _buildConfigFromInputs(showErrors: true);
    if (config == null) return;

    final isVerified = _testSuccessMessage != null;
    try {
      await controller.saveProxyConfig(
        config,
        activate: true,
        verified: isVerified,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVerified
                ? 'SOCKS5 proxy activated (verified).'
                : 'SOCKS5 proxy activated (not verified).',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _showError('Failed to save proxy settings: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportAsync = ref.watch(networkTransportProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Connection Routing',
      body: transportAsync.when(
        loading: () => const Loading(label: 'Loading transport settings...'),
        error: (error, _) => Center(
          child: Text('Unable to load network settings: $error'),
        ),
        data: (currentConfig) {
          _populateFromConfig(currentConfig);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              RootSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              // 1. Status Overview Card
              _RoutingStatusCard(
                config: currentConfig,
                isDark: isDark,
              ),
              const SizedBox(height: RootSpacing.lg),

              // 2. Transport Mode Selector
              const _SectionHeader(
                title: 'Transport mode',
                subtitle:
                    'Select how Bitcoin backend network traffic is routed.',
              ),
              const SizedBox(height: RootSpacing.xs),
              _ModeSelectionCard(
                selectedMode: _selectedMode,
                onSelect: (mode) {
                  setState(() {
                    _selectedMode = mode;
                    _testSuccessMessage = null;
                    _testErrorMessage = null;
                  });
                },
                isDark: isDark,
              ),
              const SizedBox(height: RootSpacing.lg),

              // 3. Proxy Configuration (when SOCKS5 selected)
              if (_selectedMode == NetworkTransportMode.socks5) ...[
                const _SectionHeader(
                  title: 'SOCKS5 Proxy Settings',
                  subtitle:
                      'Point to a local or remote Tor-compatible SOCKS5 proxy endpoint.',
                ),
                const SizedBox(height: RootSpacing.xs),
                _ProxyInputContainer(
                  isDark: isDark,
                  children: [
                    _InputField(
                      controller: _hostController,
                      label: 'Proxy Host or IP',
                      hintText: '127.0.0.1 or hostname / .onion',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: RootSpacing.sm),
                    _InputField(
                      controller: _portController,
                      label: 'Proxy Port',
                      hintText: '9050',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: RootSpacing.sm),
                    _InputField(
                      controller: _usernameController,
                      label: 'Username (Optional)',
                      hintText: 'Leave empty if unauthenticated',
                    ),
                    const SizedBox(height: RootSpacing.sm),
                    _InputField(
                      controller: _passwordController,
                      label: 'Password (Optional)',
                      hintText: 'Stored in SecureStorage only',
                      obscureText: true,
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.sm),
                // Authentication capability disclosure
                const InfoBanner(
                  type: InfoBannerType.info,
                  icon: Icons.shield_outlined,
                  message:
                      'Note: The underlying Bitcoin Dev Kit (BDK) Electrum client currently supports unauthenticated SOCKS5 proxies. Credentials entered will be securely retained in SecureStorage without transmission.',
                ),
                const SizedBox(height: RootSpacing.md),

                // Inline test feedback
                if (_testSuccessMessage != null) ...[
                  InfoBanner(
                    type: InfoBannerType.success,
                    icon: Icons.check_circle_outline_rounded,
                    message: _testSuccessMessage!,
                  ),
                  const SizedBox(height: RootSpacing.md),
                ],
                if (_testErrorMessage != null) ...[
                  InfoBanner(
                    type: InfoBannerType.warning,
                    icon: Icons.error_outline_rounded,
                    message: _testErrorMessage!,
                  ),
                  const SizedBox(height: RootSpacing.md),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: MagneticPressable(
                        onTap: _isTesting ? null : _runConnectionTest,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: RootSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? RootBrandColors.nightPine
                                : RootBrandColors.pureWhite,
                            borderRadius: BorderRadius.circular(RootRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? RootBrandColors.borderPine
                                  : const Color(0xFFD7E3DC),
                            ),
                          ),
                          child: Center(
                            child: _isTesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Test Proxy',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? RootBrandColors.warmIvory
                                          : RootBrandColors.charcoalPine,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: RootSpacing.sm),
                    Expanded(
                      child: MagneticPressable(
                        onTap: _saveConfiguration,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: RootSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: RootBrandColors.pineGreen,
                            borderRadius: BorderRadius.circular(RootRadius.md),
                          ),
                          child: Center(
                            child: Text(
                              _testSuccessMessage != null
                                  ? 'Save & Activate'
                                  : 'Save (Unverified)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RootSpacing.lg),
              ] else ...[
                // Direct mode save button
                MagneticPressable(
                  onTap: _saveConfiguration,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: RootSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: RootBrandColors.pineGreen,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                    ),
                    child: const Center(
                      child: Text(
                        'Apply Direct Connection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RootSpacing.lg),
              ],

              // 4. Privacy Model & Honest Disclosures Card
              _TechnicalDisclosuresCard(isDark: isDark),
            ],
          );
        },
      ),
    );
  }
}

class _RoutingStatusCard extends StatelessWidget {
  const _RoutingStatusCard({
    required this.config,
    required this.isDark,
  });

  final NetworkConfiguration config;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final status = config.statusDescription;
    final Color badgeColor;
    final Color badgeTextColor;

    switch (status) {
      case 'SOCKS5 connected':
        badgeColor = RootBrandColors.pineGreen.withValues(alpha: 0.15);
        badgeTextColor = RootBrandColors.pineGreen;
        break;
      case 'SOCKS5 configured':
        badgeColor = RootBrandColors.amberAccent.withValues(alpha: 0.15);
        badgeTextColor = RootBrandColors.amberAccent;
        break;
      case 'SOCKS5 unavailable':
        badgeColor = RootBrandColors.error.withValues(alpha: 0.15);
        badgeTextColor = RootBrandColors.error;
        break;
      default:
        badgeColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
        badgeTextColor = isDark
            ? RootBrandColors.mutedSage
            : const Color(0xFF5E6F68);
    }

    return Container(
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                config.isSocks5 ? Icons.security_rounded : Icons.public_rounded,
                size: 20,
                color: isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine,
              ),
              const SizedBox(width: RootSpacing.xs),
              Text(
                'Active Transport Status',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(RootRadius.sm),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.xs),
          Text(
            config.isSocks5
                ? 'Bitcoin Electrum traffic is routed through ${config.proxyConfig?.displayAddress ?? "configured SOCKS5 proxy"}. Esplora is disabled.'
                : 'Bitcoin backend traffic connects directly over standard TCP/HTTPS testnet infrastructure.',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSelectionCard extends StatelessWidget {
  const _ModeSelectionCard({
    required this.selectedMode,
    required this.onSelect,
    required this.isDark,
  });

  final NetworkTransportMode selectedMode;
  final ValueChanged<NetworkTransportMode> onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
        ),
      ),
      child: Column(
        children: [
          _ModeTile(
            title: 'Direct Connection (Default)',
            subtitle:
                'Connects directly to configured testnet Electrum and Esplora endpoints.',
            isSelected: selectedMode == NetworkTransportMode.direct,
            onTap: () => onSelect(NetworkTransportMode.direct),
            isDark: isDark,
          ),
          Divider(
            height: 1,
            color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          ),
          _ModeTile(
            title: 'SOCKS5 Proxy (Tor-Compatible)',
            subtitle:
                'Routes Electrum backend connections and remote DNS lookups through an external SOCKS5 proxy.',
            isSelected: selectedMode == NetworkTransportMode.socks5,
            onTap: () => onSelect(NetworkTransportMode.socks5),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RootRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(RootSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isSelected
                  ? RootBrandColors.pineGreen
                  : (isDark
                      ? RootBrandColors.mutedSage
                      : const Color(0xFF5E6F68)),
              size: 20,
            ),
            const SizedBox(width: RootSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? RootBrandColors.warmIvory
                          : RootBrandColors.charcoalPine,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProxyInputContainer extends StatelessWidget {
  const _ProxyInputContainer({
    required this.isDark,
    required this.children,
  });

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? RootBrandColors.mutedSage
                : const Color(0xFF5E6F68),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? RootBrandColors.warmIvory
                : RootBrandColors.charcoalPine,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark
                  ? RootBrandColors.mutedSage.withValues(alpha: 0.5)
                  : const Color(0xFF5E6F68).withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: isDark
                ? RootBrandColors.slatePine
                : RootBrandColors.warmIvory,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RootSpacing.sm,
              vertical: RootSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RootRadius.sm),
              borderSide: BorderSide(
                color: isDark
                    ? RootBrandColors.borderPine
                    : const Color(0xFFD7E3DC),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RootRadius.sm),
              borderSide: BorderSide(
                color: isDark
                    ? RootBrandColors.borderPine
                    : const Color(0xFFD7E3DC),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RootRadius.sm),
              borderSide: const BorderSide(
                color: RootBrandColors.pineGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TechnicalDisclosuresCard extends StatelessWidget {
  const _TechnicalDisclosuresCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: isDark
                    ? RootBrandColors.warmIvory
                    : RootBrandColors.charcoalPine,
              ),
              const SizedBox(width: RootSpacing.xs),
              Text(
                'Privacy & Network Model',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? RootBrandColors.warmIvory
                      : RootBrandColors.charcoalPine,
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.sm),
          _BulletPoint(
            title: 'Fail-closed routing guarantee:',
            body:
                'When SOCKS5 is enabled, Root Wallet strictly fails closed. If your proxy is unreachable, transactions will not sync or broadcast and will NEVER fall back to clearnet.',
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.xs),
          _BulletPoint(
            title: 'Backend scope:',
            body:
                'SOCKS5 routing applies to the Electrum backend (sync, broadcast, fee estimation, and tip height). Esplora HTTP proxying is not supported by BDK and is bypassed.',
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.xs),
          _BulletPoint(
            title: 'Remote DNS resolution:',
            body:
                'Hostnames are resolved remotely by the SOCKS5 proxy. Tor .onion addresses are supported without local DNS leakage.',
            isDark: isDark,
          ),
          const SizedBox(height: RootSpacing.xs),
          _BulletPoint(
            title: 'External daemon required:',
            body:
                'Root Wallet does not bundle a Tor daemon or proxy binary. Ensure an external proxy (such as Orbot on Android or a local Tor daemon) is running.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({
    required this.title,
    required this.body,
    required this.isDark,
  });

  final String title;
  final String body;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 6),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? RootBrandColors.mutedSage
                    : const Color(0xFF5E6F68),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? RootBrandColors.warmIvory
                        : RootBrandColors.charcoalPine,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? RootBrandColors.warmIvory
                : RootBrandColors.charcoalPine,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? RootBrandColors.mutedSage
                : const Color(0xFF5E6F68),
          ),
        ),
      ],
    );
  }
}
