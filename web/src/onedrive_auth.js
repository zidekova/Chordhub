import {
  InteractionRequiredAuthError,
  PublicClientApplication,
} from '@azure/msal-browser';

const graphScopes = ['Files.ReadWrite'];
let application;
let redirectUri;

function currentAccount() {
  const active = application.getActiveAccount();
  if (active) return active;

  const accounts = application.getAllAccounts();
  if (accounts.length === 1) {
    application.setActiveAccount(accounts[0]);
    return accounts[0];
  }
  return null;
}

async function initialize(clientId, callbackUri) {
  if (!clientId) {
    throw new Error('Chýba MSAL client ID.');
  }

  redirectUri = callbackUri;
  application = new PublicClientApplication({
    auth: {
      clientId,
      authority: 'https://login.microsoftonline.com/common',
      redirectUri,
    },
    cache: {
      cacheLocation: 'localStorage',
    },
  });
  await application.initialize();

  return currentAccount()?.username ?? null;
}

async function signIn() {
  const response = await application.loginPopup({
    scopes: graphScopes,
    redirectUri,
  });
  application.setActiveAccount(response.account);
  return response.account?.username ?? null;
}

async function acquireToken() {
  let account = currentAccount();
  if (!account) {
    await signIn();
    account = currentAccount();
  }

  try {
    const response = await application.acquireTokenSilent({
      account,
      scopes: graphScopes,
      redirectUri,
    });
    return response.accessToken;
  } catch (error) {
    if (!(error instanceof InteractionRequiredAuthError)) throw error;
    const response = await application.acquireTokenPopup({
      account,
      scopes: graphScopes,
      redirectUri,
    });
    return response.accessToken;
  }
}

async function signOut() {
  const account =
    application.getActiveAccount() ?? application.getAllAccounts()[0] ?? null;
  if (!account) return;
  await application.logoutPopup({ account, postLogoutRedirectUri: redirectUri });
}

window.chordHubOneDriveAuth = {
  acquireToken,
  initialize,
  signIn,
  signOut,
};