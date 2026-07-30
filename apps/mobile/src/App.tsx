import { APP_DISPLAY_NAME } from '@novella/client-core';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaView, StyleSheet, Text, View } from 'react-native';

export default function App() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" />
      <View style={styles.header}>
        <View style={styles.mark} />
        <Text style={styles.brand}>{APP_DISPLAY_NAME}</Text>
      </View>
      <View style={styles.content}>
        <Text style={styles.title}>轻书架</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F7F8FA',
  },
  header: {
    height: 56,
    paddingHorizontal: 20,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D9DDE3',
    backgroundColor: '#FFFFFF',
  },
  mark: {
    width: 18,
    height: 18,
    borderRadius: 4,
    backgroundColor: '#D9475D',
  },
  brand: {
    color: '#20242A',
    fontSize: 18,
    fontWeight: '700',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  title: {
    color: '#20242A',
    fontSize: 24,
    fontWeight: '700',
  },
});
