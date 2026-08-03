import { NativeTabs } from 'expo-router/unstable-native-tabs';

import { colors } from '@/theme/colors';

export default function TabsLayout() {
  return (
    <NativeTabs
      iconColor={{ default: colors.secondaryLabel, selected: colors.accent }}
      tintColor={colors.accent}
    >
      <NativeTabs.Trigger name="(discover)">
        <NativeTabs.Trigger.Icon
          drawable="ic_tabler_compass_24"
          sf="safari.fill"
        />
        <NativeTabs.Trigger.Label>Discover</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(shelf)">
        <NativeTabs.Trigger.Icon
          drawable="ic_tabler_books_24"
          sf="book.closed.fill"
        />
        <NativeTabs.Trigger.Label>Shelf</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(history)">
        <NativeTabs.Trigger.Icon
          drawable="ic_tabler_history_24"
          sf="clock.fill"
        />
        <NativeTabs.Trigger.Label>History</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(community)">
        <NativeTabs.Trigger.Icon
          drawable="ic_tabler_messages_24"
          sf="text.bubble.fill"
        />
        <NativeTabs.Trigger.Label>Community</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(search)">
        <NativeTabs.Trigger.Icon
          drawable="ic_tabler_search_24"
          sf="magnifyingglass"
        />
        <NativeTabs.Trigger.Label>Search</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
