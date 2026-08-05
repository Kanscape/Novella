import { router, Stack } from 'expo-router';

export function CommunityHomeNavigation() {
  return (
    <Stack.Toolbar placement="right">
      <Stack.Toolbar.Button
        accessibilityLabel="New Community post"
        icon="square.and.pencil"
        onPress={() => router.push('/compose')}
      />
      <Stack.Toolbar.Button
        accessibilityLabel="Community notifications"
        icon="bell"
        onPress={() => router.push('/notifications')}
      />
      <Stack.Toolbar.Menu accessibilityLabel="Community menu" icon="ellipsis">
        <Stack.Toolbar.MenuAction
          icon="person.crop.circle"
          onPress={() => router.push('/mine')}
        >
          My Community
        </Stack.Toolbar.MenuAction>
        <Stack.Toolbar.MenuAction
          icon="trophy"
          onPress={() => router.push('/community-rankings')}
        >
          Rankings
        </Stack.Toolbar.MenuAction>
      </Stack.Toolbar.Menu>
    </Stack.Toolbar>
  );
}

export function CommunityPublishNavigation({
  disabled,
  onPublish,
}: {
  disabled: boolean;
  onPublish(): void;
}) {
  return (
    <Stack.Toolbar placement="right">
      <Stack.Toolbar.Button
        accessibilityLabel="Publish discussion"
        disabled={disabled}
        icon="checkmark"
        onPress={onPublish}
      />
    </Stack.Toolbar>
  );
}

export function CommunityNotificationsNavigation({
  hidden,
  onMarkAll,
}: {
  hidden: boolean;
  onMarkAll(): void;
}) {
  return (
    <Stack.Toolbar placement="right">
      <Stack.Toolbar.Button hidden={hidden} onPress={onMarkAll}>
        Mark all read
      </Stack.Toolbar.Button>
    </Stack.Toolbar>
  );
}
