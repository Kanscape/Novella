import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/book/book_detail_loading_policy.dart';

void main() {
  test(
    'defers uncached initial content while the detail route is animating',
    () {
      expect(
        shouldDeferBookDetailContentApply(
          forceRefresh: false,
          usedCache: false,
          routeTransitionActive: true,
        ),
        isTrue,
      );
    },
  );

  test('does not defer cached content or visible refreshes', () {
    expect(
      shouldDeferBookDetailContentApply(
        forceRefresh: false,
        usedCache: true,
        routeTransitionActive: true,
      ),
      isFalse,
    );
    expect(
      shouldDeferBookDetailContentApply(
        forceRefresh: true,
        usedCache: false,
        routeTransitionActive: true,
      ),
      isFalse,
    );
    expect(
      shouldDeferBookDetailContentApply(
        forceRefresh: false,
        usedCache: false,
        routeTransitionActive: false,
      ),
      isFalse,
    );
  });
}
