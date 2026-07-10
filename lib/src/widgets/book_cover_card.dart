import 'package:flutter/material.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/src/widgets/book_cover_image.dart';
import 'package:novella/src/widgets/book_cover_previewer.dart';

final Map<Object, Set<Object>> _activeBookCoverHeroFlights = {};

class BookCoverHero extends StatelessWidget {
  final Object tag;
  final Widget child;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  const BookCoverHero({
    super.key,
    required this.tag,
    required this.child,
    this.flightShuttleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      placeholderBuilder: bookCoverHeroPlaceholderBuilder,
      flightShuttleBuilder: _buildFlightShuttle,
      child: child,
    );
  }

  Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromRoute = ModalRoute.of(fromHeroContext);
    final isOverlappingPop =
        flightDirection == HeroFlightDirection.pop &&
        (fromRoute?.secondaryAnimation?.status.isAnimating ?? false);
    if (isOverlappingPop) {
      return const SizedBox.shrink();
    }

    final shuttle =
        flightShuttleBuilder?.call(
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) ??
        _buildDefaultFlightShuttle(
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        );
    final token = Object();

    return _TrackedBookCoverHeroFlight(
      key: ObjectKey(token),
      tag: tag,
      token: token,
      child: shuttle,
    );
  }

  Widget _buildDefaultFlightShuttle(
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final toHero = toHeroContext.widget as Hero;
    final fromMediaQuery = MediaQuery.maybeOf(fromHeroContext);
    final toMediaQuery = MediaQuery.maybeOf(toHeroContext);
    if (fromMediaQuery == null || toMediaQuery == null) {
      return toHero.child;
    }

    final paddingTween = EdgeInsetsTween(
      begin: flightDirection == HeroFlightDirection.push
          ? fromMediaQuery.padding
          : toMediaQuery.padding,
      end: flightDirection == HeroFlightDirection.push
          ? toMediaQuery.padding
          : fromMediaQuery.padding,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => MediaQuery(
        data: toMediaQuery.copyWith(padding: paddingTween.evaluate(animation)),
        child: toHero.child,
      ),
    );
  }
}

class _TrackedBookCoverHeroFlight extends StatefulWidget {
  final Object tag;
  final Object token;
  final Widget child;

  const _TrackedBookCoverHeroFlight({
    super.key,
    required this.tag,
    required this.token,
    required this.child,
  });

  @override
  State<_TrackedBookCoverHeroFlight> createState() =>
      _TrackedBookCoverHeroFlightState();
}

class _TrackedBookCoverHeroFlightState
    extends State<_TrackedBookCoverHeroFlight> {
  @override
  void initState() {
    super.initState();
    _activeBookCoverHeroFlights
        .putIfAbsent(widget.tag, () => <Object>{})
        .add(widget.token);
  }

  @override
  void dispose() {
    final flights = _activeBookCoverHeroFlights[widget.tag];
    flights?.remove(widget.token);
    if (flights?.isEmpty ?? false) {
      _activeBookCoverHeroFlights.remove(widget.tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps a stranded source Hero visible when no matching Hero is in flight.
Widget bookCoverHeroPlaceholderBuilder(
  BuildContext context,
  Size heroSize,
  Widget child,
) {
  final route = ModalRoute.of(context);
  final hero = context.widget;
  return AnimatedBuilder(
    animation: Listenable.merge([route?.animation, route?.secondaryAnimation]),
    builder: (context, _) {
      final hasActiveFlight =
          hero is Hero &&
          (_activeBookCoverHeroFlights[hero.tag]?.isNotEmpty ?? false);
      final isVisible = (route?.isCurrent ?? true) && !hasActiveFlight;

      return SizedBox.fromSize(
        size: heroSize,
        child: Offstage(
          offstage: !isVisible,
          child: TickerMode(enabled: isVisible, child: child),
        ),
      );
    },
  );
}

class BookCoverCard extends StatelessWidget {
  final String coverUrl;
  final double elevation;
  final Color? shadowColor;
  final double borderRadius;
  final bool enablePreview;
  final bool showLoading;
  final bool resolveNetworkImage;
  final bool revealedBefore;
  final VoidCallback? onRevealed;
  final bool animateSynchronouslyLoadedImage;
  final Widget? placeholder;
  final Widget? cardForeground;
  final List<Widget> overlays;

  const BookCoverCard({
    super.key,
    required this.coverUrl,
    this.elevation = 2,
    this.shadowColor,
    this.borderRadius = 12,
    this.enablePreview = true,
    this.showLoading = true,
    this.resolveNetworkImage = true,
    this.revealedBefore = false,
    this.onRevealed,
    this.animateSynchronouslyLoadedImage = false,
    this.placeholder,
    this.cardForeground,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Card(
          elevation: elevation,
          shadowColor: shadowColor ?? colorScheme.shadow.withValues(alpha: 0.3),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isNotEmpty)
                _buildCoverImage()
              else
                placeholder ?? _BookCoverCardPlaceholder(colorScheme),
              if (cardForeground != null) cardForeground!,
            ],
          ),
        ),
        ...overlays,
      ],
    );
  }

  Widget _buildCoverImage() {
    final image = BookCoverImage(
      imageUrl: coverUrl,
      width: double.infinity,
      height: double.infinity,
      showLoading: showLoading,
      resolveNetworkImage: resolveNetworkImage,
      revealedBefore: revealedBefore,
      onRevealed: onRevealed,
      animateSynchronouslyLoadedImage: animateSynchronouslyLoadedImage,
    );

    if (!enablePreview) {
      return image;
    }

    return BookCoverPreviewer(coverUrl: coverUrl, child: image);
  }
}

class _BookCoverCardPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;

  const _BookCoverCardPlaceholder(this.colorScheme);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: M3ELoadingIndicator(size: 28, color: colorScheme.primary),
      ),
    );
  }
}
