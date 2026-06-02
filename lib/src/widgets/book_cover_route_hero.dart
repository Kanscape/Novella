import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:novella/src/widgets/book_cover_card.dart';

class BookCoverRouteHero extends StatefulWidget {
  static const int defaultMemCacheWidth = 350;

  final Object tag;
  final String coverUrl;
  final Widget child;
  final double elevation;
  final Color? shadowColor;
  final double borderRadius;
  final List<Widget> overlays;
  final bool precacheCover;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const BookCoverRouteHero({
    super.key,
    required this.tag,
    required this.coverUrl,
    required this.child,
    this.elevation = 2,
    this.shadowColor,
    this.borderRadius = 12,
    this.overlays = const [],
    this.precacheCover = true,
    this.memCacheWidth = defaultMemCacheWidth,
    this.memCacheHeight,
  });

  @override
  State<BookCoverRouteHero> createState() => _BookCoverRouteHeroState();
}

class _BookCoverRouteHeroState extends State<BookCoverRouteHero> {
  (String, int?, int?)? _lastPrecacheKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheCover();
  }

  @override
  void didUpdateWidget(BookCoverRouteHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _precacheCover();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.tag,
      flightShuttleBuilder: _buildFlightShuttle,
      child: widget.child,
    );
  }

  Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    if (flightDirection == HeroFlightDirection.push) {
      return _buildDefaultFlightShuttle(
        animation,
        fromHeroContext,
        toHeroContext,
      );
    }

    return BookCoverCard(
      coverUrl: widget.coverUrl,
      elevation: widget.elevation,
      shadowColor: widget.shadowColor,
      borderRadius: widget.borderRadius,
      enablePreview: false,
      showLoading: false,
      revealedBefore: true,
      animateSynchronouslyLoadedImage: false,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      overlays: widget.overlays,
    );
  }

  Widget _buildDefaultFlightShuttle(
    Animation<double> animation,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final toHero = toHeroContext.widget as Hero;
    final toMediaQueryData = MediaQuery.maybeOf(toHeroContext);
    final fromMediaQueryData = MediaQuery.maybeOf(fromHeroContext);

    if (toMediaQueryData == null || fromMediaQueryData == null) {
      return toHero.child;
    }

    final fromHeroPadding = fromMediaQueryData.padding;
    final toHeroPadding = toMediaQueryData.padding;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return MediaQuery(
          data: toMediaQueryData.copyWith(
            padding: EdgeInsetsTween(
              begin: fromHeroPadding,
              end: toHeroPadding,
            ).evaluate(animation),
          ),
          child: toHero.child,
        );
      },
    );
  }

  void _precacheCover() {
    if (!widget.precacheCover || widget.coverUrl.isEmpty) {
      return;
    }

    final key = (widget.coverUrl, widget.memCacheWidth, widget.memCacheHeight);
    if (_lastPrecacheKey == key) {
      return;
    }

    _lastPrecacheKey = key;
    final provider = CachedNetworkImageProvider(
      widget.coverUrl,
      maxWidth: widget.memCacheWidth,
      maxHeight: widget.memCacheHeight,
    );
    unawaited(precacheImage(provider, context, onError: (_, __) {}));
  }
}
