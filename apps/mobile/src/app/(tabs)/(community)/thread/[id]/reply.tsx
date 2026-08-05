import { useLocalSearchParams } from 'expo-router';

import { CommunityReplySheetScreen } from '@/screens/community-reply-sheet-screen';

export default function CommunityReplySheetRoute() {
  const params = useLocalSearchParams<{
    id?: string | string[];
    parentReplyId?: string | string[];
    replyId?: string | string[];
    replyToName?: string | string[];
  }>();
  const threadId = parsePositiveInteger(params.id);
  const parentReplyId = parsePositiveInteger(params.parentReplyId);
  const replyId = parsePositiveInteger(params.replyId);
  const replyToName = firstParam(params.replyToName) ?? null;

  return (
    <CommunityReplySheetScreen
      parentReplyId={parentReplyId || null}
      replyId={replyId || null}
      replyToName={replyToName}
      threadId={threadId}
    />
  );
}

function firstParam(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function parsePositiveInteger(value: string | string[] | undefined): number {
  const parsed = Number.parseInt(firstParam(value) ?? '', 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 0;
}
