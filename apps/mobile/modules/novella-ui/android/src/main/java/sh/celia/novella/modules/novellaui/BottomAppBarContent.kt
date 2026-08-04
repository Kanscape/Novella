package sh.celia.novella.modules.novellaui

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import android.graphics.Color
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.types.OptimizedRecord
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry
import expo.modules.ui.composeOrNull

@OptimizedRecord
data class BottomBarPressEvent(
  @Field val value: Boolean = true
) : Record

@OptimizedComposeProps
data class BottomAppBarProps(
  val containerColor: Color? = null,
  val contentColor: Color? = null,
  val counterText: String = "",
  val previousEnabled: Boolean = true,
  val nextEnabled: Boolean = true,
  val previousAccessibilityLabel: String = "",
  val nextAccessibilityLabel: String = "",
  // Bar height in dp, controlled from the JS side so callers can tune it.
  val height: Float = 56f,
  val modifiers: ModifierList = emptyList()
) : ComposeProps

/**
 * Material 3 style bottom bar (previous / counter / next) rendered as a
 * Surface + Row so the bar height is exactly the caller-provided `height`
 * value — the M3 BottomAppBar component sizes itself from internal padding
 * and ignores height modifiers.
 */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun FunctionalComposableScope.BottomAppBarContent(
  props: BottomAppBarProps,
  onPreviousPressed: () -> Unit,
  onNextPressed: () -> Unit
) {
  val containerColor = props.containerColor.composeOrNull
    ?: MaterialTheme.colorScheme.surfaceContainer
  val contentColor = props.contentColor.composeOrNull
    ?: MaterialTheme.colorScheme.onSurface

  // Total bar height = caller height + system navigation-bar inset: the
  // Surface background fills down into the gesture-bar area (immersive),
  // while the Row content gets the same inset as bottom padding so buttons
  // and the counter never sit under the gesture bar.
  val navBarInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
  val totalHeight = props.height.dp + navBarInset

  Surface(
    color = containerColor,
    contentColor = contentColor,
    modifier = ModifierRegistry
      .applyModifiers(props.modifiers, appContext, composableScope, globalEventDispatcher)
      .fillMaxWidth()
      .height(totalHeight)
  ) {
    Row(
      modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 8.dp)
        .padding(bottom = navBarInset),
      verticalAlignment = Alignment.CenterVertically
    ) {
      IconButton(
        enabled = props.previousEnabled,
        onClick = onPreviousPressed
      ) {
        Icon(
          painter = painterResource(R.drawable.ic_chevron_left_24),
          contentDescription = props.previousAccessibilityLabel.ifBlank { null }
        )
      }
      Spacer(modifier = Modifier.weight(1f))
      Text(
        text = props.counterText,
        style = MaterialTheme.typography.labelMedium,
        color = contentColor
      )
      Spacer(modifier = Modifier.weight(1f))
      IconButton(
        enabled = props.nextEnabled,
        onClick = onNextPressed
      ) {
        Icon(
          painter = painterResource(R.drawable.ic_chevron_right_24),
          contentDescription = props.nextAccessibilityLabel.ifBlank { null }
        )
      }
    }
  }
}
