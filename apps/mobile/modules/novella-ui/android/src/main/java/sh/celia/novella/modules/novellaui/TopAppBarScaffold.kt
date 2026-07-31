package sh.celia.novella.modules.novellaui

import android.graphics.Color
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.painterResource
import expo.modules.kotlin.records.Field
import expo.modules.kotlin.records.Record
import expo.modules.kotlin.types.Enumerable
import expo.modules.kotlin.types.OptimizedRecord
import expo.modules.ui.ModifierList
import expo.modules.ui.ModifierRegistry
import expo.modules.ui.UIComposableScope
import expo.modules.ui.composeOrNull
import expo.modules.kotlin.views.ComposeProps
import expo.modules.kotlin.views.FunctionalComposableScope
import expo.modules.kotlin.views.OptimizedComposeProps

@OptimizedRecord
data class BackPressedEvent(
  @Field val value: Boolean = true
) : Record

enum class TopAppBarActionIcon(val value: String) : Enumerable {
  PENCIL("pencil");

  val resourceId: Int
    get() = when (this) {
      PENCIL -> R.drawable.ic_pencil_24
    }
}

@OptimizedRecord
data class TopAppBarAction(
  @Field val id: String = "",
  @Field val icon: TopAppBarActionIcon = TopAppBarActionIcon.PENCIL,
  @Field val accessibilityLabel: String = "",
  @Field val enabled: Boolean = true
) : Record

@OptimizedRecord
data class TopAppBarActionEvent(
  @Field val id: String = ""
) : Record

@OptimizedComposeProps
data class TopAppBarScaffoldProps(
  val title: String = "",
  val containerColor: Color? = null,
  val contentColor: Color? = null,
  val largeTitle: Boolean = true,
  val showBackButton: Boolean = false,
  val actions: List<TopAppBarAction> = emptyList(),
  val modifiers: ModifierList = emptyList()
) : ComposeProps

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FunctionalComposableScope.TopAppBarScaffoldContent(
  props: TopAppBarScaffoldProps,
  onBackPressed: () -> Unit,
  onActionPressed: (TopAppBarActionEvent) -> Unit
) {
  val containerColor = props.containerColor.composeOrNull ?: MaterialTheme.colorScheme.surface
  val contentColor = props.contentColor.composeOrNull ?: MaterialTheme.colorScheme.onSurface
  val scrollBehavior = if (props.largeTitle) {
    TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
  } else {
    TopAppBarDefaults.pinnedScrollBehavior()
  }
  val modifier = ModifierRegistry
    .applyModifiers(props.modifiers, appContext, composableScope, globalEventDispatcher)
    .fillMaxSize()
    .nestedScroll(scrollBehavior.nestedScrollConnection)

  Scaffold(
    modifier = modifier,
    containerColor = containerColor,
    contentColor = contentColor,
    topBar = {
      if (props.largeTitle) {
        LargeTopAppBar(
          title = { Text(props.title) },
          navigationIcon = { BackButton(props.showBackButton, onBackPressed) },
          actions = { TopAppBarActions(props.actions, onActionPressed) },
          colors = topAppBarColors(containerColor, contentColor),
          scrollBehavior = scrollBehavior
        )
      } else {
        TopAppBar(
          title = { Text(props.title) },
          navigationIcon = { BackButton(props.showBackButton, onBackPressed) },
          actions = { TopAppBarActions(props.actions, onActionPressed) },
          colors = topAppBarColors(containerColor, contentColor),
          scrollBehavior = scrollBehavior
        )
      }
    }
  ) { innerPadding ->
    Box(
      modifier = Modifier
        .fillMaxSize()
        .padding(innerPadding)
    ) {
      Children(
        UIComposableScope(
          boxScope = this@Box,
          nestedScrollConnection = scrollBehavior.nestedScrollConnection
        )
      )
    }
  }
}

@Composable
private fun TopAppBarActions(
  actions: List<TopAppBarAction>,
  onActionPressed: (TopAppBarActionEvent) -> Unit
) {
  actions.take(3).forEach { action ->
    IconButton(
      enabled = action.enabled,
      onClick = { onActionPressed(TopAppBarActionEvent(action.id)) }
    ) {
      Icon(
        contentDescription = action.accessibilityLabel,
        painter = painterResource(action.icon.resourceId)
      )
    }
  }
}

@Composable
private fun BackButton(showBackButton: Boolean, onBackPressed: () -> Unit) {
  if (!showBackButton) return
  IconButton(onClick = onBackPressed) {
    Icon(
      contentDescription = "Back",
      painter = painterResource(R.drawable.ic_arrow_back_24)
    )
  }
}

@Composable
private fun topAppBarColors(
  containerColor: androidx.compose.ui.graphics.Color,
  contentColor: androidx.compose.ui.graphics.Color
) = TopAppBarDefaults.topAppBarColors(
  containerColor = containerColor,
  scrolledContainerColor = containerColor,
  navigationIconContentColor = contentColor,
  titleContentColor = contentColor,
  actionIconContentColor = contentColor
)
