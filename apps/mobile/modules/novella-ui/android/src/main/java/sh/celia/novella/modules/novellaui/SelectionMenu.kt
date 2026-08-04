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
import androidx.compose.material3.IconButton
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
import expo.modules.kotlin.types.Enumerable
import expo.modules.kotlin.types.OptimizedRecord
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry

enum class SelectionMenuIcon(val value: String) : Enumerable {
  BOOKS("books"),
  EQUAL("equal"),
  SPARKLES("sparkles"),
  TAG("tag"),
  TEXT_SIZE("textSize"),
  USER("user"),
  DOTS("dots");

  val resourceId: Int
    get() = when (this) {
      BOOKS -> R.drawable.ic_tabler_books_24
      EQUAL -> R.drawable.ic_tabler_equal_24
      SPARKLES -> R.drawable.ic_tabler_sparkles_24
      TAG -> R.drawable.ic_tabler_tag_24
      TEXT_SIZE -> R.drawable.ic_tabler_text_size_24
      USER -> R.drawable.ic_tabler_user_24
      DOTS -> R.drawable.ic_tabler_dots_24
    }
}

@OptimizedRecord
data class SelectionMenuItem(
  @Field val label: String = "",
  @Field val enabled: Boolean = true,
  @Field val icon: SelectionMenuIcon? = null
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
data class SelectionMenuProps(
  val items: List<SelectionMenuItem> = emptyList(),
  val selectedIndex: Int = -1,
  val expanded: Boolean = false,
  val enabled: Boolean = true,
  /** When set, the trigger renders as a plain icon button instead of the
   *  selected-label row (header menu pattern). */
  val triggerIcon: SelectionMenuIcon? = null,
  val modifiers: ModifierList = emptyList()
) : ComposeProps

data class SelectionMenuEntry(
  val id: String,
  val label: String,
  val enabled: Boolean = true,
  val selected: Boolean = false,
  val icon: SelectionMenuIcon? = null
)

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun FunctionalComposableScope.SelectionMenuContent(
  props: SelectionMenuProps,
  onExpandedChange: (Boolean) -> Unit,
  onItemSelected: (Int) -> Unit
) {
  val modifier = ModifierRegistry
    .applyModifiers(props.modifiers, appContext, composableScope, globalEventDispatcher)
    .width(if (props.triggerIcon != null) 48.dp else 168.dp)

  Box(modifier = modifier) {
    val triggerIcon = props.triggerIcon
    if (triggerIcon != null) {
      IconButton(
        enabled = props.enabled,
        onClick = { onExpandedChange(!props.expanded) }
      ) {
        Icon(
          contentDescription = null,
          painter = painterResource(triggerIcon.resourceId),
          tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
      }
    } else {
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
    }

    SelectionDropdownMenu(
      enabled = props.enabled,
      entries = props.items.mapIndexed { index, item ->
        SelectionMenuEntry(
          id = index.toString(),
          label = item.label,
          enabled = item.enabled,
          selected = index == props.selectedIndex,
          icon = item.icon
        )
      },
      expanded = props.expanded,
      onDismissRequest = { onExpandedChange(false) },
      onSelected = { entry ->
        onItemSelected(entry.id.toInt())
        onExpandedChange(false)
      }
    )
  }
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun SelectionDropdownMenu(
  enabled: Boolean,
  entries: List<SelectionMenuEntry>,
  expanded: Boolean,
  onDismissRequest: () -> Unit,
  onSelected: (SelectionMenuEntry) -> Unit
) {
  if (!expanded || entries.isEmpty()) return
  DropdownMenuPopup(
    expanded = true,
    onDismissRequest = onDismissRequest
  ) {
    DropdownMenuGroup(shapes = MenuDefaults.groupShape(index = 0, count = 1)) {
      entries.forEachIndexed { index, entry ->
        DropdownMenuItem(
          selected = entry.selected,
          onClick = { onSelected(entry) },
          text = { Text(entry.label) },
          leadingIcon = entry.icon?.let { icon ->
            {
              Icon(
                contentDescription = null,
                painter = painterResource(icon.resourceId)
              )
            }
          },
          shapes = MenuDefaults.itemShape(index, entries.size),
          trailingIcon = if (entry.selected) {
            {
              Icon(
                contentDescription = null,
                painter = painterResource(R.drawable.ic_check_24)
              )
            }
          } else {
            null
          },
          enabled = enabled && entry.enabled,
          colors = MenuDefaults.selectableItemColors()
        )
      }
    }
  }
}
