// Prihlásenie do Google Disku cez Google Identity Services (token model).
// Nepotrebuje žiadny build ani npm balíčky. Skript sa načíta z index.html.
(function () {
  const SCOPE = 'https://www.googleapis.com/auth/drive';
  const TOKEN_KEY = 'chordhub_google_token';
  const EMAIL_KEY = 'chordhub_google_email';
  const SILENT_TIMEOUT_MS = 20 * 1000;
  const INTERACTIVE_TIMEOUT_MS = 3 * 60 * 1000;

  let tokenClient = null;
  let currentClientId = null;
  let pending = null; // { resolve, reject } práve prebiehajúcej žiadosti o token
  let silentInflight = null; // zdieľaná tichá obnova tokenu
  let accessToken = null;
  let expiresAt = 0;
  let email = null;

  function readJson(key) {
    try {
      return JSON.parse(window.localStorage.getItem(key) || 'null');
    } catch (_) {
      return null;
    }
  }

  function loadCachedToken() {
    const cached = readJson(TOKEN_KEY);
    if (cached && cached.token && cached.expiresAt > Date.now()) {
      accessToken = cached.token;
      expiresAt = cached.expiresAt;
    }
  }

  function saveToken() {
    try {
      window.localStorage.setItem(
        TOKEN_KEY,
        JSON.stringify({ token: accessToken, expiresAt }),
      );
    } catch (_) {}
  }

  function clearToken() {
    accessToken = null;
    expiresAt = 0;
    try {
      window.localStorage.removeItem(TOKEN_KEY);
    } catch (_) {}
  }

  // minValidityMs: ako dlho ešte má token platiť, aby sme ho považovali za použiteľný.
  function hasValidToken(minValidityMs) {
    return (
      accessToken !== null && Date.now() + (minValidityMs || 0) < expiresAt
    );
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

  function settle(error) {
    const current = pending;
    pending = null;
    if (current) current.reject(error);
  }

  async function initialize(clientId) {
    if (!clientId) {
      throw new Error('Chýba Google client ID.');
    }
    await waitForGis();

    if (!tokenClient || currentClientId !== clientId) {
      currentClientId = clientId;
      tokenClient = window.google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: SCOPE,
        callback: (response) => {
          if (response.error) {
            settle(new Error(response.error_description || response.error));
            return;
          }
          // Token uložíme aj vtedy, keď žiadosť medzitým vypršala:
          // používateľ sa tak nemusí prihlasovať druhýkrát.
          accessToken = response.access_token;
          expiresAt = Date.now() + (Number(response.expires_in) - 60) * 1000;
          saveToken();
          const current = pending;
          pending = null;
          if (current) current.resolve(accessToken);
        },
        error_callback: (error) => {
          const type = (error && error.type) || 'unknown';
          settle(
            new Error(
              type === 'popup_closed'
                ? 'Prihlasovacie okno bolo zatvorené.'
                : type === 'popup_failed_to_open'
                ? 'Prehliadač zablokoval prihlasovacie okno. Povoľ vyskakovacie okná a skús to znova.'
                : 'Prihlásenie do Google zlyhalo (' + type + ').',
            ),
          );
        },
      });
    }

    loadCachedToken();
    email = window.localStorage.getItem(EMAIL_KEY);
    return email;
  }

  // Každá nová žiadosť nahradí starú nedokončenú, aby sa nič nezaseklo.
  function requestToken(options, timeoutMs) {
    if (!tokenClient) {
      return Promise.reject(new Error('Google prihlásenie nie je inicializované.'));
    }
    settle(new Error('Žiadosť o prihlásenie bola nahradená novšou.'));

    return new Promise((resolve, reject) => {
      const entry = {
        resolve: (value) => {
          clearTimeout(timer);
          resolve(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          reject(error);
        },
      };
      const timer = setTimeout(() => {
        if (pending === entry) pending = null;
        reject(new Error('Prihlásenie do Google vypršalo. Prihlás sa znova.'));
      }, timeoutMs);

      pending = entry;
      try {
        tokenClient.requestAccessToken(options);
      } catch (error) {
        if (pending === entry) pending = null;
        clearTimeout(timer);
        reject(error);
      }
    });
  }

  async function fetchEmail(token) {
    try {
      const response = await fetch(
        'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)',
        { headers: { Authorization: 'Bearer ' + token } },
      );
      if (!response.ok) return null;
      const data = await response.json();
      return (data.user && data.user.emailAddress) || null;
    } catch (_) {
      return null;
    }
  }

  // Musí sa volať priamo z kliknutia, inak prehliadač zablokuje okno.
  async function signIn() {
    const options = email
      ? { prompt: '', hint: email }
      : { prompt: 'select_account' };
    const token = await requestToken(options, INTERACTIVE_TIMEOUT_MS);
    email = (await fetchEmail(token)) || email || 'Google účet';
    window.localStorage.setItem(EMAIL_KEY, email);
    return email;
  }

  function silentRefresh() {
    if (!email) {
      return Promise.reject(new Error('Najprv sa prihlás do Google účtu.'));
    }
    if (silentInflight) return silentInflight;
    silentInflight = requestToken({ prompt: '', hint: email }, SILENT_TIMEOUT_MS).finally(
      () => {
        silentInflight = null;
      },
    );
    return silentInflight;
  }

  async function acquireToken(minValidityMs) {
    if (hasValidToken(minValidityMs)) return accessToken;
    try {
      await silentRefresh();
    } catch (error) {
      // Obnova sa nepodarila, ale starý token ešte platí, tak ho použijeme.
      if (hasValidToken(0)) return accessToken;
      throw error;
    }
    return accessToken;
  }

  function isSignedIn() {
    return hasValidToken(0);
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

  window.chordHubGoogleAuth = { initialize, signIn, acquireToken, isSignedIn, signOut };
})();
