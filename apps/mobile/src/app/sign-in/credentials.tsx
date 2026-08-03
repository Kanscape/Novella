import { useLocalSearchParams } from 'expo-router';

import { SignInCredentialsScreen } from '@/screens/sign-in-screen';

export default function SignInCredentialsRoute() {
  const { email } = useLocalSearchParams<{ email?: string }>();
  return <SignInCredentialsScreen initialEmail={typeof email === 'string' ? email : ''} />;
}
