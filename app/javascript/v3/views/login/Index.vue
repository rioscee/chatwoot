<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import { useBranding } from 'shared/composables/useBranding';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    const { replaceInstallationName } = useBranding();
    return {
      replaceInstallationName,
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          // Check if sessions limit reached
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }

          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        ...extraParams,
      };

      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main class="login-layout-wrapper">
    <!-- Left side: Login form -->
    <div class="login-form-container">
      <!-- Logo centered at the very top -->
      <div class="logo-container">
        <img
          :src="globalConfig.logo"
          :alt="globalConfig.installationName"
          class="brand-logo light-mode-logo"
        />
        <img
          v-if="globalConfig.logoDark"
          :src="globalConfig.logoDark"
          :alt="globalConfig.installationName"
          class="brand-logo dark-mode-logo"
        />
      </div>

      <div class="login-form-box">
        <header class="login-header">
          <h1 class="login-title">
            Iniciar Sesión
          </h1>
          <p class="login-subtitle">
            Ingresa tus credenciales para acceder al CRM.
          </p>
        </header>

        <!-- Session Limit Section -->
        <section v-if="sessionsLimitReached" class="auth-section">
          <SessionLimitOverlay
            :sessions="limitedSessions"
            @revoke="handleSessionRevoke"
            @revoke-all="handleSessionRevokeAll"
            @cancel="handleSessionLimitCancel"
          />
        </section>

        <!-- MFA Verification Section -->
        <section v-else-if="mfaRequired" class="auth-section">
          <MfaVerification
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />
        </section>

        <!-- Regular Login Section -->
        <section v-else class="auth-section">
          <div v-if="!email">
            <div class="oauth-container">
              <GoogleOAuthButton v-if="showGoogleOAuth" />
              <div v-if="showSamlLogin" class="saml-container">
                <router-link
                  to="/app/login/sso"
                  class="saml-button"
                >
                  <Icon
                    icon="i-lucide-lock-keyhole"
                    class="saml-icon"
                  />
                  <span class="saml-text">
                    {{ $t('LOGIN.SAML.LABEL') }}
                  </span>
                </router-link>
              </div>
              <SimpleDivider
                v-if="showGoogleOAuth || showSamlLogin"
                :label="$t('COMMON.OR')"
                class="uppercase divider"
              />
            </div>
            <form class="login-form" @submit.prevent="submitFormLogin">
              <FormInput
                v-model="credentials.email"
                name="email_address"
                type="text"
                data-testid="email_input"
                :tabindex="1"
                required
                :label="$t('LOGIN.EMAIL.LABEL')"
                :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                :has-error="v$.credentials.email.$error"
                @input="v$.credentials.email.$touch"
              />
              <FormInput
                v-model="credentials.password"
                type="password"
                name="password"
                data-testid="password_input"
                required
                :tabindex="2"
                :label="$t('LOGIN.PASSWORD.LABEL')"
                :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                :has-error="v$.credentials.password.$error"
                @input="v$.credentials.password.$touch"
              >
                <p v-if="!globalConfig.disableUserProfileUpdate" class="forgot-password-container">
                  <router-link
                    to="auth/reset/password"
                    class="forgot-password-link"
                    tabindex="4"
                  >
                    {{ $t('LOGIN.FORGOT_PASSWORD') }}
                  </router-link>
                </p>
              </FormInput>

              <div class="remember-me-container">
                <label class="remember-me-label">
                  <input type="checkbox" class="remember-me-checkbox" />
                  <span>Recordarme</span>
                </label>
              </div>

              <div class="form-actions-row">
                <NextButton
                  lg
                  type="submit"
                  data-testid="submit_button"
                  class="submit-button"
                  :tabindex="3"
                  :label="$t('LOGIN.SUBMIT')"
                  :disabled="loginApi.showLoading"
                  :is-loading="loginApi.showLoading"
                />
                
                <router-link v-if="showSignupLink" to="auth/signup" class="create-account-button">
                  Crear cuenta
                </router-link>
              </div>
            </form>
          </div>
          <div v-else class="spinner-container">
            <Spinner color-scheme="primary" size="" />
          </div>
        </section>
      </div>

      <footer class="login-footer">
        <p>Al ingresar aceptas nuestros términos y políticas de datos.</p>
      </footer>
    </div>

    <!-- Right side: Visual decoration -->
    <div class="login-visual-container">
      <div class="visual-image-wrapper">
        <img :src="'/login_sidebar_crm.webp'" alt="CRM Visual" class="visual-image" />
        <div class="visual-overlay"></div>
        <div class="visual-content">
          <h2 class="visual-title">Gestión de Clientes en un solo lugar</h2>
          <p class="visual-description">
            Conecta tus canales de comunicación preferidos y potencia tus ventas.
          </p>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.login-layout-wrapper {
  display: flex;
  min-height: 100vh;
  width: 100vw;
  background-color: var(--white, #ffffff);
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  overflow: hidden;
  box-sizing: border-box;
}

.login-form-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: center;
  padding: 4rem 2rem;
  background-color: var(--white, #ffffff);
  box-sizing: border-box;
  min-height: 100vh;
}

.logo-container {
  display: flex;
  justify-content: center;
  align-items: center;
}

.brand-logo {
  height: 48px;
  width: auto;
}

.login-form-box {
  width: 100%;
  max-width: 440px;
  display: flex;
  flex-direction: column;
  gap: 2rem;
  margin: auto 0;
}

.login-header {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  text-align: center;
}

.dark-mode-logo {
  display: none;
}

.login-title {
  font-size: clamp(24px, 3vw, 32px);
  font-weight: 700;
  color: var(--s-900, #0f172a);
  margin: 0.5rem 0 0 0;
  letter-spacing: -0.025em;
  line-height: 1.2;
}

.login-subtitle {
  font-size: clamp(14px, 1.2vw, 16px);
  color: var(--s-500, #64748b);
  margin: 0;
}

.auth-section {
  width: 100%;
}

.oauth-container {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.saml-container {
  width: 100%;
}

.saml-button {
  display: inline-flex;
  justify-content: center;
  width: 100%;
  padding: 0.75rem 1rem;
  align-items: center;
  background-color: var(--s-50, #f8fafc);
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 6px;
  text-decoration: none;
  transition: background-color 0.2s ease;
}

.saml-button:hover {
  background-color: var(--s-100, #f1f5f9);
}

.saml-icon {
  font-size: 20px;
  color: var(--s-500, #64748b);
}

.saml-text {
  margin-left: 0.5rem;
  font-weight: 500;
  color: var(--s-800, #1e293b);
}

.divider {
  margin: 0.5rem 0;
}

.login-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.forgot-password-container {
  margin: 0.25rem 0 0 0;
  text-align: right;
}

.forgot-password-link {
  font-size: 13px;
  color: var(--b-600, #2563eb);
  text-decoration: none;
  font-weight: 500;
}

.forgot-password-link:hover {
  text-decoration: underline;
}

.remember-me-container {
  display: flex;
  align-items: center;
  margin-top: -0.25rem;
}

.remember-me-label {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 14px;
  color: var(--s-600, #475569);
  user-select: none;
}

.remember-me-checkbox {
  width: 16px;
  height: 16px;
  border-radius: 4px;
  border: 1px solid var(--s-300, #cbd5e1);
  accent-color: var(--b-600, #2563eb);
}

.form-actions-row {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
  width: 100%;
}

.submit-button {
  flex: 1;
}

.create-account-button {
  flex: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.75rem 1rem;
  border: 1px solid var(--s-200, #e2e8f0);
  border-radius: 6px;
  color: var(--s-800, #1e293b);
  font-weight: 500;
  text-decoration: none;
  background-color: var(--white, #ffffff);
  transition: background-color 0.2s ease, border-color 0.2s ease;
  box-sizing: border-box;
}

.create-account-button:hover {
  background-color: var(--s-50, #f8fafc);
  border-color: var(--s-300, #cbd5e1);
}

.spinner-container {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.login-footer {
  font-size: clamp(11px, 0.9vw, 13px);
  color: var(--s-400, #94a3b8);
  line-height: 1.4;
  text-align: center;
}

/* Right Side: Visual Section */
.login-visual-container {
  flex: 1;
  display: none;
  position: relative;
  overflow: hidden;
}

@media (min-width: 768px) {
  .login-visual-container {
    display: block;
  }
}

.visual-image-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
}

.visual-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 10s ease;
}

.visual-image-wrapper:hover .visual-image {
  transform: scale(1.05);
}

.visual-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.1) 0%, rgba(21, 128, 61, 0.4) 100%);
  mix-blend-mode: multiply;
}

.visual-content {
  position: absolute;
  bottom: 10%;
  left: 8%;
  right: 8%;
  z-index: 2;
  color: var(--white, #ffffff);
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  text-shadow: 0 2px 4px rgba(0,0,0,0.3);
}

.visual-title {
  font-size: clamp(24px, 2.5vw, 36px);
  font-weight: 700;
  margin: 0;
  line-height: 1.2;
}

.visual-description {
  font-size: clamp(14px, 1.2vw, 18px);
  opacity: 0.9;
  margin: 0;
  line-height: 1.4;
}

/* Dark Mode integration */
@media (prefers-color-scheme: dark) {
  .login-layout-wrapper {
    background-color: var(--s-950, #030712);
  }
  .login-form-container {
    background-color: var(--s-950, #030712);
  }
  .login-title {
    color: var(--s-50, #f9fafb);
  }
  .login-subtitle {
    color: var(--s-400, #9ca3af);
  }
  .saml-button {
    background-color: var(--s-900, #111827);
    border-color: var(--s-800, #1f2937);
  }
  .saml-button:hover {
    background-color: var(--s-800, #1f2937);
  }
  .saml-text {
    color: var(--s-100, #f3f4f6);
  }
  .remember-me-label {
    color: var(--s-400, #9ca3af);
  }
  .create-account-button {
    background-color: var(--s-900, #111827);
    border-color: var(--s-800, #1f2937);
    color: var(--s-100, #f3f4f6);
  }
  .create-account-button:hover {
    background-color: var(--s-800, #1f2937);
    border-color: var(--s-700, #374151);
  }
  .light-mode-logo {
    display: none;
  }
  .dark-mode-logo {
    display: block;
  }
}
</style>
