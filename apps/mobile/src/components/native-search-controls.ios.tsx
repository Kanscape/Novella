import { Stack } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { NativeSearchBar } from '../../modules/novella-ui';

import { NativeSegmentedControl } from '@/components/native-segmented-control';
import {
  BOOK_SEARCH_MODE_OPTIONS,
  type NativeSearchControlsProps,
} from '@/components/native-search-controls.types';

const FORMAT_OPTIONS = [
  { label: 'Novel', value: 'Novel' },
  { label: 'Comic', value: 'Comic' },
] as const;

export function NativeSearchControls({
  format,
  mode,
  onFormatChange,
  onModeChange,
  onQueryChange,
  onSubmit,
  query,
}: NativeSearchControlsProps) {
  return (
    <>
      <View style={styles.searchBar}>
        <NativeSearchBar
          onQueryChange={onQueryChange}
          onSearch={onSubmit}
          placeholder="Search novels and comics"
          query={query}
        />
      </View>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu accessibilityLabel="Search mode" icon="slider.horizontal.3">
          {BOOK_SEARCH_MODE_OPTIONS.map((option) => (
            <Stack.Toolbar.MenuAction
              icon={option.iosIcon}
              isOn={mode === option.value}
              key={option.value}
              onPress={() => onModeChange(option.value)}
            >
              {option.label}
            </Stack.Toolbar.MenuAction>
          ))}
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>
      <NativeSegmentedControl
        onValueChange={onFormatChange}
        options={FORMAT_OPTIONS}
        selectedValue={format}
      />
    </>
  );
}

const styles = StyleSheet.create({
  searchBar: { height: 56, width: '100%' },
});
