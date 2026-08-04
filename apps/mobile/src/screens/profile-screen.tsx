import * as Clipboard from 'expo-clipboard';
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';


import { showAlert } from '@/components/native-alert-dialog';

import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { ProfileAvatar } from '@/components/profile-avatar';
import { DisclosureIcon, NativeListValue } from '@/components/settings-row-accessories';
import { useAuthentication } from '@/hooks/use-authentication';
import { useProfile } from '@/hooks/use-profile';
import { authentication, profile as profileUseCase } from '@/services/client';

type CopyableProfileField = 'email' | 'inviteCode' | 'uid' | 'userName';

export function ProfileScreen() {
  const auth = useAuthentication();
  const { error, profile, reload, status } = useProfile();
  const [copiedField, setCopiedField] = useState<CopyableProfileField | null>(null);
  const [checkingIn, setCheckingIn] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const copyTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => () => {
    if (copyTimer.current) clearTimeout(copyTimer.current);
  }, []);

  async function copy(field: CopyableProfileField, value: string) {
    const normalized = value.trim();
    if (!normalized) return;
    await Clipboard.setStringAsync(normalized);
    if (copyTimer.current) clearTimeout(copyTimer.current);
    setCopiedField(field);
    copyTimer.current = setTimeout(() => setCopiedField(null), 1_200);
  }

  async function checkIn() {
    if (!profile || profile.growth.signedToday || checkingIn) return;
    setCheckingIn(true);
    try {
      const outcome = await profileUseCase.checkIn();
      showAlert(
        'Checked in',
        `Day ${outcome.result.streak} · +${outcome.result.reward} experience`,
      );
    } catch (checkInError) {
      showAlert(
        'Unable to check in',
        checkInError instanceof Error ? checkInError.message : 'Please try again.',
      );
    } finally {
      setCheckingIn(false);
    }
  }

  function confirmSignOut() {
    if (signingOut || auth.status === 'signingOut') return;
    showAlert('Sign out?', 'Your synchronized account data will remain on the server.', [
      { style: 'cancel', text: 'Cancel' },
      {
        style: 'destructive',
        text: 'Sign out',
        onPress: () => {
          setSigningOut(true);
          void authentication.signOut().catch((signOutError) => {
            setSigningOut(false);
            showAlert(
              'Unable to sign out',
              signOutError instanceof Error ? signOutError.message : 'Please try again.',
            );
          });
        },
      },
    ]);
  }

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="profile-screen"
      title="Profile"
    >
      {!profile ? (
        <NativeGroupedListSection title="Profile">
          <NativeGroupedListRow
            description={error ?? 'Retrieving your LightNovelShelf account information'}
            disabled={status === 'loading'}
            icon={error ? 'error' : 'account'}
            {...(status === 'loading' ? {} : { onPress: () => void reload() })}
            title={status === 'loading' ? 'Loading profile…' : 'Unable to load profile'}
            trailing={status === 'loading' ? undefined : <DisclosureIcon />}
          />
        </NativeGroupedListSection>
      ) : (
        <>
          <NativeGroupedListSection title="Personal information">
            <NativeGroupedListRow
              description="Change your profile picture"
              icon="avatar"
              onPress={() => router.push('/settings/avatar')}
              title="Avatar"
              trailing={(
                <ProfileAvatar
                  avatarUrl={profile.avatarUrl}
                  size={42}
                  userName={profile.userName}
                />
              )}
            />
            <CopyableValueRow
              copied={copiedField === 'uid'}
              icon="uid"
              label="UID"
              onCopy={() => void copy('uid', String(profile.id))}
              value={String(profile.id)}
            />
            <CopyableValueRow
              copied={copiedField === 'userName'}
              icon="userName"
              label="Username"
              onCopy={() => void copy('userName', profile.userName)}
              value={displayValue(profile.userName)}
            />
            <CopyableValueRow
              copied={copiedField === 'email'}
              icon="email"
              label="Email"
              onCopy={() => void copy('email', profile.email)}
              value={displayValue(profile.email)}
            />
            <CopyableValueRow
              copied={copiedField === 'inviteCode'}
              disabled={!profile.inviteCode.trim()}
              icon="inviteCode"
              label="Invite code"
              onCopy={() => void copy('inviteCode', profile.inviteCode)}
              value={profile.inviteCode.trim()
                ? '•'.repeat(profile.inviteCode.trim().length)
                : 'Not available'}
            />
            <StaticValueRow icon="userGroup" label="User group" value={displayValue(profile.groupName)} />
            <StaticValueRow icon="registered" label="Registered" value={formatDate(profile.registeredAt)} />
          </NativeGroupedListSection>

          <NativeGroupedListSection title="Growth">
            <StaticValueRow icon="level" label="Level" value={`Lv${profile.growth.level}`} />
            <StaticValueRow icon="experience" label="Experience" value={String(profile.growth.experience)} />
            <StaticValueRow icon="points" label="Points" value={String(profile.point)} />
            <NativeGroupedListRow
              description={profile.growth.signedToday
                ? `${profile.growth.signInStreak}-day streak · Signed today`
                : `${profile.growth.signInStreak}-day streak · Check in for experience`}
              disabled={profile.growth.signedToday || checkingIn}
              icon="checkIn"
              {...(profile.growth.signedToday ? {} : { onPress: () => void checkIn() })}
              title={checkingIn ? 'Checking in…' : 'Daily check-in'}
              trailing={<NativeListValue>{profile.growth.signedToday ? 'Done' : 'Check in'}</NativeListValue>}
            />
          </NativeGroupedListSection>
        </>
      )}

      <NativeGroupedListSection title="Account">
        <NativeGroupedListRow
          description="Remove this account session from the device"
          disabled={signingOut || auth.status === 'signingOut'}
          icon="signOut"
          onPress={confirmSignOut}
          title={signingOut || auth.status === 'signingOut' ? 'Signing out…' : 'Sign out'}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}

function CopyableValueRow({
  copied,
  disabled = false,
  icon,
  label,
  onCopy,
  value,
}: {
  copied: boolean;
  disabled?: boolean;
  icon: 'email' | 'inviteCode' | 'uid' | 'userName';
  label: string;
  onCopy: () => void;
  value: string;
}) {
  return (
    <NativeGroupedListRow
      {...(disabled ? {} : { description: copied ? 'Copied' : 'Tap to copy' })}
      disabled={disabled}
      icon={icon}
      onPress={onCopy}
      title={label}
      trailing={<NativeListValue>{copied ? 'Copied' : value}</NativeListValue>}
    />
  );
}

function StaticValueRow({
  icon,
  label,
  value,
}: {
  icon: 'experience' | 'level' | 'points' | 'registered' | 'userGroup';
  label: string;
  value: string;
}) {
  return (
    <NativeGroupedListRow
      icon={icon}
      title={label}
      trailing={<NativeListValue>{value}</NativeListValue>}
    />
  );
}

function displayValue(value: string): string {
  return value.trim() || 'Not available';
}

function formatDate(value: string | null): string {
  if (!value) return 'Not available';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not available';
  const year = String(date.getFullYear()).padStart(4, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}
