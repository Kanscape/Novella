package sh.celia.novella.modules.novellaui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.DropdownMenuGroup
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.DropdownMenuPopup
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.types.OptimizedRecord
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry
import expo.modules.ui.composeOrNull
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps

@OptimizedRecord
data class M3ExpressiveDropdownItem(
  @Field val label: String = "",
  @Field val enabled: Boolean = true
) : Record

@OptimizedRecord
data class ExpandedChangeEvent(
  @Field val value: Boolean = false
) : Record

@OptimizedRecord
data class DropdownItemSelectedEvent(
  @Field val index: Int = -1
) : Record

@OptimizedComposeProps
data class M3ExpressiveDropdownProps(
  val items: List<M3ExpressiveDropdownItem> = emptyList(),
  val selectedIndex: Int = -1,
  val expanded: Boolean = false,
  val enabled: Boolean = true,
  val modifiers: ModifierList = emptyList()
) : ComposeProps

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun FunctionalComposableScope.M3ExpressiveDropdownContent(
  props: M3ExpressiveDropdownProps,
  onExpandedChange: (Boolean) -> Unit,
  onItemSelected: (Int) -> Unit
) {
  val modifier = ModifierRegistry
    .applyModifiers(props.modifiers, appContext, composableScope, globalEventDispatcher)
    .width(168.dp)

  Box(modifier = modifier) {
    val selectedLabel = props.items.getOrNull(props.selectedIndex)?.label.orEmpty()

    Row(
      modifier = Modifier
        .fillMaxWidth()
        .padding(start = 8.dp, top = 8.dp, end = 0.dp, bottom = 8.dp),
      horizontalArrangement = Arrangement.End,
      verticalAlignment = Alignment.CenterVertically
    ) {
      Text(
        text = selectedLabel,
        color = MaterialTheme.colorScheme.onSurface,
        style = MaterialTheme.typography.bodyLarge
      )
      Icon(
        contentDescription = null,
        painter = painterResource(R.drawable.ic_keyboard_arrow_down_24),
        tint = MaterialTheme.colorScheme.onSurfaceVariant
      )
    }

    if (props.expanded && props.items.isNotEmpty()) {
      DropdownMenuPopup(
        expanded = true,
        onDismissRequest = { onExpandedChange(false) }
      ) {
        DropdownMenuGroup(shapes = MenuDefaults.groupShape(index = 0, count = 1)) {
          props.items.forEachIndexed { index, item ->
            DropdownMenuItem(
              selected = index == props.selectedIndex,
              onClick = {
                onItemSelected(index)
                onExpandedChange(false)
              },
              text = { Text(item.label) },
              shapes = MenuDefaults.itemShape(index, props.items.size),
              trailingIcon = if (index == props.selectedIndex) {
                {
                  Icon(
                    contentDescription = null,
                    painter = painterResource(R.drawable.ic_check_24)
                  )
                }
              } else {
                null
              },
              enabled = props.enabled && item.enabled,
              colors = MenuDefaults.selectableItemColors()
            )
          }
        }
      }
    }
  }
}
