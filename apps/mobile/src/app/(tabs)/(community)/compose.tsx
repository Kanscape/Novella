import { useLocalSearchParams } from 'expo-router';

import { CommunityComposeScreen } from '@/screens/community-compose-screen';

export default function CommunityComposeRoute() {
  const params = useLocalSearchParams<{
    boardKey?: string | string[];
    subCategoryKey?: string | string[];
  }>();
  return (
    <CommunityComposeScreen
      initialBoardKey={firstParam(params.boardKey) ?? ''}
      initialSubCategoryKey={firstParam(params.subCategoryKey) ?? ''}
    />
  );
}

function firstParam(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}
