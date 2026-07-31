package sh.celia.novella.modules.novellaui

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.ui.ExpoUIView

class NovellaUiModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("NovellaUi")

    ExpoUIView<TopAppBarScaffoldProps>("TopAppBarScaffold") {
      val onActionPressed by Event<TopAppBarActionEvent>()
      val onBackPressed by Event<BackPressedEvent>()

      Content { props ->
        TopAppBarScaffoldContent(
          props,
          onBackPressed = { onBackPressed(BackPressedEvent()) },
          onActionPressed = { onActionPressed(it) }
        )
      }
    }

    ExpoUIView<M3ExpressiveDropdownProps>("M3ExpressiveDropdown") {
      val onExpandedChange by Event<ExpandedChangeEvent>()
      val onItemSelected by Event<DropdownItemSelectedEvent>()

      Content { props ->
        M3ExpressiveDropdownContent(
          props,
          onExpandedChange = { onExpandedChange(ExpandedChangeEvent(it)) },
          onItemSelected = { onItemSelected(DropdownItemSelectedEvent(it)) }
        )
      }
    }
  }
}
