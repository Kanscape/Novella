import { IconDownload, IconShare, IconX } from '@tabler/icons-react-native';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { Image } from 'expo-image';
import {
  ActivityIndicator,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions,
} from 'react-native';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { showAlert } from '@/components/native-alert-dialog';
import { resolveReaderImageUrl } from '@/services/reader-image-dimensions';
import {
  ReaderImageActionError,
  saveReaderImage,
  shareReaderImage,
  type ReaderImageActionErrorCode,
} from '@/services/reader-image-actions';

const READER_IMAGE_PREVIEW_MAX_ZOOM = 6;
const ACTION_BUTTON_SIZE = 44;

export interface ReaderImagePreviewSource {
  uri: string;
  alt?: string;
}

export interface ReaderImagePreviewProps {
  source: ReaderImagePreviewSource;
  onClose: () => void;
}

/** Full-screen reader image preview with Flutter-equivalent actions and zoom. */
export function ReaderImagePreview({ source, onClose }: ReaderImagePreviewProps) {
  const { width, height } = useWindowDimensions();
  const imageUri = resolveReaderImageUrl(source.uri);
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isSharing, setIsSharing] = useState(false);
  const mountedRef = useRef(true);

  const scale = useSharedValue(1);
  const savedScale = useSharedValue(1);
  const pinchStartScale = useSharedValue(1);
  const translationX = useSharedValue(0);
  const translationY = useSharedValue(0);
  const panStartX = useSharedValue(0);
  const panStartY = useSharedValue(0);

  useEffect(() => () => {
    mountedRef.current = false;
  }, []);

  const closeFromGesture = useCallback(() => {
    onClose();
  }, [onClose]);

  const pinch = Gesture.Pinch()
    .onBegin(() => {
      pinchStartScale.value = savedScale.value;
    })
    .onUpdate((event) => {
      scale.value = clamp(
        pinchStartScale.value * event.scale,
        1,
        READER_IMAGE_PREVIEW_MAX_ZOOM,
      );
    })
    .onEnd(() => {
      savedScale.value = scale.value;
      if (scale.value <= 1) {
        translationX.value = withTiming(0, { duration: 160 });
        translationY.value = withTiming(0, { duration: 160 });
      }
    });

  const pan = Gesture.Pan()
    .onBegin(() => {
      panStartX.value = translationX.value;
      panStartY.value = translationY.value;
    })
    .onUpdate((event) => {
      if (scale.value <= 1) return;
      const maxX = Math.max(0, (width * (scale.value - 1)) / 2);
      const maxY = Math.max(0, (height * (scale.value - 1)) / 2);
      translationX.value = clamp(panStartX.value + event.translationX, -maxX, maxX);
      translationY.value = clamp(panStartY.value + event.translationY, -maxY, maxY);
    })
    .onEnd(() => {
      if (scale.value <= 1) {
        translationX.value = withTiming(0, { duration: 160 });
        translationY.value = withTiming(0, { duration: 160 });
      }
    });

  const tap = Gesture.Tap().onEnd((_event, success) => {
    if (success && scale.value <= 1.01) {
      runOnJS(closeFromGesture)();
    }
  });

  const gesture = Gesture.Simultaneous(pinch, pan, tap);
  const imageStyle = useAnimatedStyle(() => ({
    transform: [
      { scale: scale.value },
      { translateX: translationX.value },
      { translateY: translationY.value },
    ],
  }));

  const showActionMessage = useCallback((message: string) => {
    showAlert('提示', message);
  }, []);

  const handleSave = useCallback(async () => {
    if (isSaving || isSharing) return;
    setIsSaving(true);
    try {
      await saveReaderImage(imageUri);
      showActionMessage('图片已保存到相册');
    } catch (error) {
      showActionMessage(readerImageActionMessage(error, 'save'));
    } finally {
      if (mountedRef.current) setIsSaving(false);
    }
  }, [imageUri, isSaving, isSharing, showActionMessage]);

  const handleShare = useCallback(async () => {
    if (isSaving || isSharing) return;
    setIsSharing(true);
    try {
      await shareReaderImage(imageUri);
    } catch (error) {
      showActionMessage(readerImageActionMessage(error, 'share'));
    } finally {
      if (mountedRef.current) setIsSharing(false);
    }
  }, [imageUri, isSaving, isSharing, showActionMessage]);

  return (
    <Modal
      animationType="fade"
      hardwareAccelerated
      onRequestClose={onClose}
      navigationBarTranslucent
      presentationStyle="overFullScreen"
      statusBarTranslucent
      transparent
      visible
    >
      <GestureHandlerRootView style={styles.modalRoot}>
        <View style={styles.backdrop}>
          <StatusBar style="light" />
          <GestureDetector gesture={gesture}>
            <Animated.View style={[styles.imageFrame, imageStyle]}>
              {hasError ? (
                <View style={styles.errorState}>
                  <Text style={styles.errorText}>图片加载失败</Text>
                </View>
              ) : (
                <Image
                  accessibilityLabel={source.alt?.trim() || 'Chapter illustration'}
                  cachePolicy="memory-disk"
                  contentFit="contain"
                  onError={() => {
                    if (!mountedRef.current) return;
                    setHasError(true);
                    setIsLoading(false);
                  }}
                  onLoad={() => {
                    if (!mountedRef.current) return;
                    setHasError(false);
                    setIsLoading(false);
                  }}
                  onLoadStart={() => {
                    if (!mountedRef.current) return;
                    setHasError(false);
                    setIsLoading(true);
                  }}
                  source={{ uri: imageUri }}
                  style={styles.image}
                />
              )}
              {isLoading && !hasError ? (
                <View pointerEvents="none" style={styles.loadingState}>
                  <ActivityIndicator color="rgba(255,255,255,0.92)" size="small" />
                </View>
              ) : null}
            </Animated.View>
          </GestureDetector>
          <SafeAreaView edges={['top']} pointerEvents="box-none" style={styles.toolbarSafeArea}>
            <View style={styles.toolbar}>
              <PreviewActionButton
                accessibilityLabel="分享图片"
                disabled={isSaving || isSharing}
                onPress={handleShare}
              >
                {isSharing ? <ActivityIndicator color="#FFFFFF" size="small" /> : <IconShare color="#FFFFFF" size={21} />}
              </PreviewActionButton>
              <PreviewActionButton accessibilityLabel="关闭图片预览" onPress={onClose}>
                <IconX color="#FFFFFF" size={21} />
              </PreviewActionButton>
              <PreviewActionButton
                accessibilityLabel="保存图片"
                disabled={isSaving || isSharing}
                onPress={handleSave}
              >
                {isSaving ? <ActivityIndicator color="#FFFFFF" size="small" /> : <IconDownload color="#FFFFFF" size={21} />}
              </PreviewActionButton>
            </View>
          </SafeAreaView>
        </View>
      </GestureHandlerRootView>
    </Modal>
  );
}

function PreviewActionButton({
  accessibilityLabel,
  children,
  disabled = false,
  onPress,
}: {
  accessibilityLabel: string;
  children: ReactNode;
  disabled?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.actionButton,
        disabled ? styles.actionButtonDisabled : null,
        pressed && !disabled ? styles.actionButtonPressed : null,
      ]}
    >
      {children}
    </Pressable>
  );
}

function readerImageActionMessage(
  error: unknown,
  action: 'save' | 'share',
): string {
  if (error instanceof ReaderImageActionError) {
    const messages: Partial<Record<ReaderImageActionErrorCode, string>> = {
      'access-denied': '未获得相册访问权限',
      'not-enough-space': '设备剩余空间不足',
      'unsupported-format': '图片格式暂不支持保存',
    };
    const knownMessage = messages[error.code];
    if (knownMessage) return knownMessage;
  }
  return action === 'save' ? '保存图片失败' : '分享图片失败';
}

function clamp(value: number, minimum: number, maximum: number): number {
  'worklet';
  return Math.min(maximum, Math.max(minimum, value));
}

const styles = StyleSheet.create({
  modalRoot: {
    flex: 1,
  },
  backdrop: {
    backgroundColor: 'rgba(0,0,0,0.96)',
    flex: 1,
  },
  imageFrame: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  image: {
    height: '100%',
    width: '100%',
  },
  loadingState: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  errorText: {
    color: 'rgba(255,255,255,0.86)',
    fontSize: 16,
  },
  toolbarSafeArea: {
    left: 0,
    position: 'absolute',
    right: 0,
    top: 0,
  },
  toolbar: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingTop: 8,
  },
  actionButton: {
    alignItems: 'center',
    backgroundColor: 'rgba(40,40,40,0.68)',
    borderRadius: ACTION_BUTTON_SIZE / 2,
    height: ACTION_BUTTON_SIZE,
    justifyContent: 'center',
    width: ACTION_BUTTON_SIZE,
  },
  actionButtonDisabled: {
    opacity: 0.55,
  },
  actionButtonPressed: {
    opacity: 0.72,
  },
});
