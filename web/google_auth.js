// Prihlásenie do Google Disku cez Google Identity Services (token model).
// Nepotrebuje žiadny build ani npm balíčky. Skript sa načíta z index.html.
(function () {
  const SCOPE = 'https://www.googleapis.com/auth/drive';
  const SESSION_KEY = 'chordhub_google_token';
  const EMAIL_KEY = 'chordhub_google_email';

  let tokenClient = null;
  let pending = null; // { resolve, reject } práve prebiehajúcej žiadosti o token
  let inflight = null; // zdieľaný Promise, aby sa neotvorilo viac okien naraz
  let accessToken = null;
  let expiresAt = 0;
  let email = null;

  function readJson(storage, key) {
    try {
      return JSON.parse(storage.getItem(key) || 'null');
    } catch (_) {
      return null;
    }
  }

  function loadCachedToken() {
    const cached = readJson(window.sessionStorage, SESSION_KEY);
    if (cached && cached.token && cached.expiresAt > Date.now()) {
      accessToken = cached.token;
      expiresAt = cached.expiresAt;
    }
  }

  function saveToken() {
    try {
      window.sessionStorage.setItem(
        SESSION_KEY,
        JSON.stringify({ token: accessToken, expiresAt }),
      );
    } catch (_) {}
  }

  function clearToken() {
    accessToken = null;
    expiresAt = 0;
    try {
      window.sessionStorage.removeItem(SESSION_KEY);
    } catch (_) {}
  }

  function hasValidToken() {
    return accessToken !== null && Date.now() < expiresAt;
  }

  async function waitForGis() {
    for (let i = 0; i < 100; i++) {
      if (window.google && window.google.accounts && window.google.accounts.oauth2) {
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error('Nepodarilo sa načítať Google prihlasovaciu knižnicu.');
  }

  async function initialize(clientId) {
    if (!clientId) {
      throw new Error('Chýba Google client ID.');
    }
    await waitForGis();

    tokenClient = window.google.accounts.oauth2.initTokenClient({
      client_id: clientId,
      scope: SCOPE,
      callback: (response) => {
        const current = pending;
        pending = null;
        if (!current) return;
        if (response.error) {
          current.reject(new Error(response.error_description || response.error));
          return;
        }
        accessToken = response.access_token;
        expiresAt = Date.now() + (Number(response.expires_in) - 60) * 1000;
        saveToken();
        current.resolve(accessToken);
      },
      error_callback: (error) => {
        const current = pending;
        pending = null;
        if (current) {
          current.reject(
            new Error(
              error && error.type === 'popup_closed'
                ? 'Prihlasovacie okno bolo zatvorené.'
                : 'Prihlásenie do Google zlyhalo (' + ((error && error.type) || 'neznáma chyba') + ').',
            ),
          );
        }
      },
    });

    loadCachedToken();
    email = window.localStorage.getItem(EMAIL_KEY);
    return email;
  }

  function requestToken(options) {
    if (!tokenClient) {
      return Promise.reject(new Error('Google prihlásenie nie je inicializované.'));
    }
    if (inflight) return inflight;

    inflight = new Promise((resolve, reject) => {
      pending = { resolve, reject };
      try {
        tokenClient.requestAccessToken(options);
      } catch (error) {
        pending = null;
        reject(error);
      }
    }).finally(() => {
      inflight = null;
    });
    return inflight;
  }

  async function fetchEmail(token) {
    const response = await fetch(
      'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)',
      { headers: { Authorization: 'Bearer ' + token } },
    );
    if (!response.ok) return null;
    const data = await response.json();
    return (data.user && data.user.emailAddress) || null;
  }

  async function signIn() {
    const token = await requestToken({ prompt: 'select_account' });
    email = await fetchEmail(token);
    if (email) {
      window.localStorage.setItem(EMAIL_KEY, email);
    }
    return email;
  }

  async function acquireToken() {
    if (hasValidToken()) return accessToken;

    // Token vyprší po cca hodine. Pokúsime sa o tichú obnovu bez zobrazenia výberu účtu.
    const options = { prompt: '' };
    if (email) options.login_hint = email;
    return requestToken(options);
  }

  async function signOut() {
    const token = accessToken;
    clearToken();
    email = null;
    window.localStorage.removeItem(EMAIL_KEY);
    if (token && window.google && window.google.accounts) {
      await new Promise((resolve) =>
        window.google.accounts.oauth2.revoke(token, () => resolve()),
      );
    }
  }

  window.chordHubGoogleAuth = { initialize, signIn, acquireToken, signOut };
})();
