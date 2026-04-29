import 'package:flutter/material.dart';

class BookGridTitle extends StatelessWidget {
  static const double height = 36;

  final String title;
  final bool animated;

  const BookGridTitle({super.key, required this.title, this.animated = false});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final titleText = _BookGridTitleText(
      key: ValueKey(title),
      title: title,
      style: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurface,
        height: 1.2,
      ),
    );

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child:
            animated
                ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren.map(
                          (child) => Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: double.infinity,
                              child: child,
                            ),
                          ),
                        ),
                        if (currentChild != null)
                          Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: double.infinity,
                              child: currentChild,
                            ),
                          ),
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation);

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: titleText,
                )
                : Align(
                  alignment: Alignment.center,
                  child: SizedBox(width: double.infinity, child: titleText),
                ),
      ),
    );
  }
}

class _BookGridTitleText extends StatelessWidget {
  final String title;
  final TextStyle? style;

  const _BookGridTitleText({super.key, required this.title, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
      textAlign: TextAlign.center,
    );
  }
}
