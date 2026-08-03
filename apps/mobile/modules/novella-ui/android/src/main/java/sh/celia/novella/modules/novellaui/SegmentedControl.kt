package sh.celia.novella.modules.novellaui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ButtonGroupDefaults
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ToggleButton
import androidx.compose.material3.ToggleButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.res.painterResource
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.types.OptimizedRecord
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry

@OptimizedRecord
data class SegmentedControlOption(
  @Field val label: String = "",
  @Field val value: String = ""
) : Record

@OptimizedRecord
data class SegmentedControlChangeEvent(
  @Field val value: String = ""
) : Record

@OptimizedComposeProps
data class SegmentedControlProps(
  val options: List<SegmentedControlOption> = emptyList(),
  val selectedValue: String = "",
  val enabled: Boolean = true,
  val modifiers: ModifierList = emptyList()
) : ComposeProps

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun FunctionalComposableScope.SegmentedControlContent(
  props: SegmentedControlProps,
  onValueChange: (SegmentedControlChangeEvent) -> Unit
) {
  Row(
    modifier = ModifierRegistry
      .applyModifiers(props.modifiers, appContext, composableScope, globalEventDispatcher)
      .fillMaxWidth(),
    horizontalArrangement = Arrangement.spacedBy(ButtonGroupDefaults.ConnectedSpaceBetween)
  ) {
    props.options.forEachIndexed { index, option ->
      val selected = option.value == props.selectedValue
      ToggleButton(
        checked = selected,
        enabled = props.enabled,
        modifier = Modifier
          .weight(1f)
          .semantics { role = Role.RadioButton },
        onCheckedChange = { onValueChange(SegmentedControlChangeEvent(option.value)) },
        shapes = when (index) {
          0 -> ButtonGroupDefaults.connectedLeadingButtonShapes()
          props.options.lastIndex -> ButtonGroupDefaults.connectedTrailingButtonShapes()
          else -> ButtonGroupDefaults.connectedMiddleButtonShapes()
        }
      ) {
        if (selected) {
          Icon(
            contentDescription = null,
            painter = painterResource(R.drawable.ic_check_24)
          )
          Spacer(Modifier.size(ToggleButtonDefaults.IconSpacing))
        }
        Text(option.label)
      }
    }
  }
}
