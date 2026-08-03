export interface RegistrationFlowDraft {
  email: string;
  inviteCode: string;
  password: string;
  passwordConfirmation: string;
  userName: string;
}

export interface PasswordResetFlowDraft {
  code: string;
  email: string;
}

let registration: RegistrationFlowDraft | null = null;
let passwordReset: PasswordResetFlowDraft | null = null;

export const authFlowSession = Object.freeze({
  clearPasswordReset() {
    passwordReset = null;
  },
  clearRegistration() {
    registration = null;
  },
  getPasswordReset() {
    return passwordReset;
  },
  getRegistration() {
    return registration;
  },
  setPasswordReset(next: PasswordResetFlowDraft) {
    passwordReset = { ...next };
  },
  setRegistration(next: RegistrationFlowDraft) {
    registration = { ...next };
  },
});
