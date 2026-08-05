import {
  IconBook,
  IconDeviceGamepad2,
  IconLanguage,
  IconMessageCircle,
  IconMessages,
  IconMovie,
  IconNotes,
  IconPalette,
  IconPhoto,
  IconSpeakerphone,
  IconStar,
  IconVideo,
} from '@tabler/icons-react-native';
import type { ComponentType } from 'react';

import { resolveCommunityBoardIconKey } from '@/services/community-board-icon-keys';

type IconComponent = ComponentType<{ color?: string; size?: number; strokeWidth?: number }>;

const BOARD_ICON_COMPONENTS: Readonly<Record<string, IconComponent>> = {
  book: IconBook,
  'gamepad-2': IconDeviceGamepad2,
  language: IconLanguage,
  'message-circle': IconMessageCircle,
  messages: IconMessages,
  movie: IconMovie,
  notes: IconNotes,
  palette: IconPalette,
  photo: IconPhoto,
  speakerphone: IconSpeakerphone,
  star: IconStar,
  video: IconVideo,
};

/**
 * Resolves a board icon name/fallback text to a Tabler icon component.
 * Unknown server icon names deliberately fall back to `IconMessages`, so RN
 * content never renders a Material/SF-symbol substitute or a text glyph.
 */
export function resolveCommunityBoardIcon(
  rawName: string,
  fallbackText: string,
): IconComponent {
  const key = resolveCommunityBoardIconKey(rawName, fallbackText);
  return key ? BOARD_ICON_COMPONENTS[key] ?? IconMessages : IconMessages;
}
