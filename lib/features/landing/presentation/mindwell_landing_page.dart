import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/core/experiments/experiments.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/core/routes/app_routes.dart';

import 'landing_content.dart';
import 'widgets/experts_section.dart';
import 'widgets/footer_section.dart';
import 'widgets/header_widget.dart';
import 'widgets/hero_section.dart';
import 'widgets/method_section.dart';
import 'widgets/programmes_section.dart';
import 'widgets/sanctuaries_section.dart';
import 'widgets/toolkit_section.dart';

class MindWellLandingPage extends ConsumerStatefulWidget {
  const MindWellLandingPage({
    super.key,
    required this.onOpenBooking,
    required this.onOpenLogin,
    required this.onOpenCompanionsPreview,
  });

  final VoidCallback onOpenBooking;
  final VoidCallback onOpenLogin;
  final VoidCallback onOpenCompanionsPreview;

  @override
  ConsumerState<MindWellLandingPage> createState() =>
      _MindWellLandingPageState();
}

class _MindWellLandingPageState extends ConsumerState<MindWellLandingPage> {
  final _scrollController = ScrollController();
  final _heroKey = GlobalKey();
  final _conceptKey = GlobalKey();
  final _sanctuariesKey = GlobalKey();
  final _programmesKey = GlobalKey();
  final _toolkitKey = GlobalKey();
  final _expertsKey = GlobalKey();
  final _footerKey = GlobalKey();

  bool _menuOpen = false;

  static const Set<String> _loginRequiredFeatures = {
    'Self-Assessment',
    'Private Journal',
    'Resource Library',
    'Wellness Trends',
    'Journal',
    // 'Behavior Tracker',
  };

  static const Map<String, String> _loginDescriptions = {
    'AI Chatbot':
        'Sign in to unlock unlimited conversations and saved history.',
    'Self-Assessment':
        'Complete guided assessments after logging in to save your results.',
    'Private Journal':
        'Log in to unlock your secure space for daily reflections and mood tracking.',
    'Resource Library':
        'Personalised recommendations are available once you are signed in.',
    'Wellness Trends': 'Log in to visualise your personal progress over time.',
    'Journal':
        'Access your personal journal by logging in with your MindWell account.',
    'Behavior Tracker':
        'Track your behavioral patterns and get AI-powered insights by logging in.',
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    setState(() => _menuOpen = false);
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroVariant = ref
        .watch(experimentResolverProvider)
        .maybeWhen(
          data: (resolver) => resolver.variantFor(ExperimentKey.landingHero),
          orElse: () => 'control',
        );
    final bool immersiveHero = heroVariant == 'immersive';
    final String heroTitle = immersiveHero
        ? 'Personalised telehealth, tailored to you.'
        : 'Clarity. Calm. Connection.';
    final String heroSubtitle = immersiveHero
        ? 'Meet clinicians and AI companions attuned to your wellness journey—whenever you need them.'
        : 'The Future of Mental Wellness is Here.';
    final String heroCta = immersiveHero
        ? 'Begin Telehealth'
        : 'Explore Therapies';

    final navItems = [
      MindWellNavItem(
        label: 'Our Concept',
        onTap: () => _scrollTo(_conceptKey),
      ),
      MindWellNavItem(
        label: 'Therapies',
        onTap: () => _scrollTo(_programmesKey),
      ),
      MindWellNavItem(
        label: 'Our Experts',
        onTap: () => _scrollTo(_expertsKey),
      ),
      MindWellNavItem(label: 'Telehealth', onTap: () => _scrollTo(_toolkitKey)),

      // ADD BEHAVIOR TRACKER HERE
      //MindWellNavItem(
      //  label: 'Behavior Tracker',
      //  onTap: () => _navigateToBehaviorTracker(),
      //),
      MindWellNavItem(label: 'Journal', onTap: () => _promptLogin('Journal')),
    ];
    if (immersiveHero) {
      navItems
        ..removeWhere((item) => item.label == 'Telehealth')
        ..insert(
          0,
          MindWellNavItem(
            label: 'Telehealth',
            onTap: () => _scrollTo(_toolkitKey),
          ),
        );
    }

    final sanctuaryCards = MindWellLandingContent.sanctuaries
        .map(
          (info) => MindWellSanctuary(
            title: info.title,
            description: info.description,
            imageUrl: info.imageUrl,
            onPressed: widget.onOpenBooking,
          ),
        )
        .toList();

    final programmeCards = MindWellLandingContent.programmes
        .map(
          (info) => MindWellProgramme(
            title: info.title,
            description: info.description,
            imageUrl: info.imageUrl,
            onPressed: widget.onOpenBooking,
          ),
        )
        .toList();

    final toolkitCards = MindWellLandingContent.toolkit.map((info) {
      final bool requiresLogin = _loginRequiredFeatures.contains(info.title);
      final bool isBooking = info.title == 'Appointments';
      final bool isChatbot = info.title == 'AI Chatbot';
      final bool isBehaviorTracker = info.title == 'Behavior Tracker';
      return MindWellToolkitFeature(
        title: info.title,
        description: info.description,
        icon: info.icon,
        onTap: isBooking
            ? () {
                setState(() => _menuOpen = false);
                widget.onOpenBooking();
              }
            : isChatbot
            ? () {
                setState(() => _menuOpen = false);
                widget.onOpenCompanionsPreview();
              }
            : isBehaviorTracker // Add this condition
            ? _navigateToBehaviorTracker // Use the new method
            : (requiresLogin ? () => _promptLogin(info.title) : null),
      );
    }).toList();

    return Scaffold(
      backgroundColor: MindWellColors.cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1024;
          final headerMaxExtent = isCompact && _menuOpen ? 320.0 : 110.0;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _MindWellHeaderDelegate(
                  minExtent: 96,
                  maxExtent: headerMaxExtent,
                  builder: (context, shrinkOffset, overlapsContent) {
                    final isCompact = MediaQuery.of(context).size.width < 1024;
                    return MindWellHeader(
                      isCompact: isCompact,
                      isMenuOpen: _menuOpen,
                      onMenuToggle: () =>
                          setState(() => _menuOpen = !_menuOpen),
                      navItems: navItems,
                      onBookPressed: () {
                        setState(() => _menuOpen = false);
                        widget.onOpenBooking();
                      },
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellHeroSection(
                  key: _heroKey,
                  imageUrl: MindWellLandingContent.heroImageUrl,
                  title: heroTitle,
                  subtitle: heroSubtitle,
                  ctaLabel: heroCta,
                  onExplore: immersiveHero
                      ? widget.onOpenBooking
                      : () => _scrollTo(_programmesKey),
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellMethodSection(
                  key: _conceptKey,
                  imageUrl: MindWellLandingContent.methodImageUrl,
                  onLearnMore: () => _scrollTo(_toolkitKey),
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellSanctuariesSection(
                  key: _sanctuariesKey,
                  sanctuaries: sanctuaryCards,
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellProgrammesSection(
                  key: _programmesKey,
                  programmes: programmeCards,
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellToolkitSection(
                  key: _toolkitKey,
                  features: toolkitCards,
                ),
              ),
              SliverToBoxAdapter(
                child: MindWellExpertsSection(
                  key: _expertsKey,
                  imageUrl: MindWellLandingContent.expertsImageUrl,
                  onMeetExperts: widget.onOpenBooking,
                ),
              ),
              SliverToBoxAdapter(child: MindWellFooter(key: _footerKey)),
            ],
          );
        },
      ),
    );
  }

  void _navigateToBehaviorTracker() {
    setState(() => _menuOpen = false);
    Navigator.pushNamed(context, AppRoutes.behavior);
  }

  void _promptLogin(String featureName) {
    setState(() => _menuOpen = false);
    final description =
        _loginDescriptions[featureName] ??
        'This feature is reserved for authenticated members.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Login Required',
          style: MindWellTypography.sectionSubtitle(
            color: MindWellColors.darkGray,
          ).copyWith(fontSize: 22),
        ),
        content: Text(
          description,
          style: MindWellTypography.body(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: MindWellTypography.body(color: MindWellColors.darkGray),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenLogin();
            },
            style: FilledButton.styleFrom(
              backgroundColor: MindWellColors.darkGray,
              foregroundColor: MindWellColors.cream,
            ),
            child: Text(
              'Login Now'.toUpperCase(),
              style: MindWellTypography.button(
                color: MindWellColors.cream,
              ).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MindWellHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MindWellHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget Function(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  )
  builder;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder(context, shrinkOffset, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _MindWellHeaderDelegate oldDelegate) {
    return true;
  }
}
