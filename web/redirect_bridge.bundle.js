(() => {
  var __defProp = Object.defineProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };

  // node_modules/@azure/msal-common/dist-browser/constants/AADServerParamKeys.mjs
  var CLIENT_ID = "client_id";
  var REDIRECT_URI = "redirect_uri";
  var RESPONSE_TYPE = "response_type";
  var RESPONSE_MODE = "response_mode";
  var GRANT_TYPE = "grant_type";
  var CLAIMS = "claims";
  var SCOPE = "scope";
  var REFRESH_TOKEN = "refresh_token";
  var STATE = "state";
  var NONCE = "nonce";
  var PROMPT = "prompt";
  var CODE = "code";
  var CODE_CHALLENGE = "code_challenge";
  var CODE_CHALLENGE_METHOD = "code_challenge_method";
  var CODE_VERIFIER = "code_verifier";
  var CLIENT_REQUEST_ID = "client-request-id";
  var X_CLIENT_SKU = "x-client-SKU";
  var X_CLIENT_VER = "x-client-VER";
  var X_CLIENT_OS = "x-client-OS";
  var X_CLIENT_CPU = "x-client-CPU";
  var X_CLIENT_CURR_TELEM = "x-client-current-telemetry";
  var X_CLIENT_LAST_TELEM = "x-client-last-telemetry";
  var X_MS_LIB_CAPABILITY = "x-ms-lib-capability";
  var X_APP_NAME = "x-app-name";
  var X_APP_VER = "x-app-ver";
  var POST_LOGOUT_URI = "post_logout_redirect_uri";
  var ID_TOKEN_HINT = "id_token_hint";
  var DEVICE_CODE = "device_code";
  var CLIENT_SECRET = "client_secret";
  var CLIENT_ASSERTION = "client_assertion";
  var CLIENT_ASSERTION_TYPE = "client_assertion_type";
  var TOKEN_TYPE = "token_type";
  var REQ_CNF = "req_cnf";
  var OBO_ASSERTION = "assertion";
  var REQUESTED_TOKEN_USE = "requested_token_use";
  var NATIVE_BROKER = "nativebroker";
  var LOGOUT_HINT = "logout_hint";
  var SID = "sid";
  var LOGIN_HINT = "login_hint";
  var DOMAIN_HINT = "domain_hint";
  var BROKER_CLIENT_ID = "brk_client_id";
  var BROKER_REDIRECT_URI = "brk_redirect_uri";
  var INSTANCE_AWARE = "instance_aware";
  var EAR_JWK = "ear_jwk";
  var EAR_JWE_CRYPTO = "ear_jwe_crypto";
  var RESOURCE = "resource";
  var CLI_DATA = "clidata";
  var ATTRIBUTE_TOKENS = "attribute_tokens";
  var POPUP_ORIGIN_CHECK_DONE = "pocd";

  // node_modules/@azure/msal-common/dist-browser/utils/Constants.mjs
  var Constants_exports = {};
  __export(Constants_exports, {
    AADAuthority: () => AADAuthority,
    AAD_INSTANCE_DISCOVERY_ENDPT: () => AAD_INSTANCE_DISCOVERY_ENDPT,
    AAD_TENANT_DOMAIN_SUFFIX: () => AAD_TENANT_DOMAIN_SUFFIX,
    ADFS: () => ADFS,
    APP_METADATA: () => APP_METADATA,
    AUTHORITY_METADATA_CACHE_KEY: () => AUTHORITY_METADATA_CACHE_KEY,
    AUTHORITY_METADATA_REFRESH_TIME_SECONDS: () => AUTHORITY_METADATA_REFRESH_TIME_SECONDS,
    AUTHORIZATION_PENDING: () => AUTHORIZATION_PENDING,
    AZURE_REGION_AUTO_DISCOVER_FLAG: () => AZURE_REGION_AUTO_DISCOVER_FLAG,
    AuthenticationScheme: () => AuthenticationScheme,
    AuthorityMetadataSource: () => AuthorityMetadataSource,
    CACHE_ACCOUNT_TYPE_ADFS: () => CACHE_ACCOUNT_TYPE_ADFS,
    CACHE_ACCOUNT_TYPE_GENERIC: () => CACHE_ACCOUNT_TYPE_GENERIC,
    CACHE_ACCOUNT_TYPE_MSAV1: () => CACHE_ACCOUNT_TYPE_MSAV1,
    CACHE_ACCOUNT_TYPE_MSSTS: () => CACHE_ACCOUNT_TYPE_MSSTS,
    CACHE_KEY_SEPARATOR: () => CACHE_KEY_SEPARATOR,
    CIAM_AUTH_URL: () => CIAM_AUTH_URL,
    CLIENT_INFO: () => CLIENT_INFO,
    CLIENT_INFO_SEPARATOR: () => CLIENT_INFO_SEPARATOR,
    CLIENT_MISMATCH_ERROR: () => CLIENT_MISMATCH_ERROR,
    CODE_GRANT_TYPE: () => CODE_GRANT_TYPE,
    CONSUMER_UTID: () => CONSUMER_UTID,
    CacheOutcome: () => CacheOutcome,
    CacheType: () => CacheType,
    ClaimsRequestKeys: () => ClaimsRequestKeys,
    CodeChallengeMethodValues: () => CodeChallengeMethodValues,
    CredentialType: () => CredentialType,
    DEFAULT_AUTHORITY: () => DEFAULT_AUTHORITY,
    DEFAULT_AUTHORITY_HOST: () => DEFAULT_AUTHORITY_HOST,
    DEFAULT_COMMON_TENANT: () => DEFAULT_COMMON_TENANT,
    DEFAULT_MAX_THROTTLE_TIME_SECONDS: () => DEFAULT_MAX_THROTTLE_TIME_SECONDS,
    DEFAULT_THROTTLE_TIME_SECONDS: () => DEFAULT_THROTTLE_TIME_SECONDS,
    DEFAULT_TOKEN_RENEWAL_OFFSET_SEC: () => DEFAULT_TOKEN_RENEWAL_OFFSET_SEC,
    EMAIL_SCOPE: () => EMAIL_SCOPE,
    EncodingTypes: () => EncodingTypes,
    FORWARD_SLASH: () => FORWARD_SLASH,
    GrantType: () => GrantType,
    HTTP_BAD_REQUEST: () => HTTP_BAD_REQUEST,
    HTTP_CLIENT_ERROR: () => HTTP_CLIENT_ERROR,
    HTTP_CLIENT_ERROR_RANGE_END: () => HTTP_CLIENT_ERROR_RANGE_END,
    HTTP_CLIENT_ERROR_RANGE_START: () => HTTP_CLIENT_ERROR_RANGE_START,
    HTTP_GATEWAY_TIMEOUT: () => HTTP_GATEWAY_TIMEOUT,
    HTTP_GONE: () => HTTP_GONE,
    HTTP_MULTI_SIDED_ERROR: () => HTTP_MULTI_SIDED_ERROR,
    HTTP_NOT_FOUND: () => HTTP_NOT_FOUND,
    HTTP_REDIRECT: () => HTTP_REDIRECT,
    HTTP_REQUEST_TIMEOUT: () => HTTP_REQUEST_TIMEOUT,
    HTTP_SERVER_ERROR: () => HTTP_SERVER_ERROR,
    HTTP_SERVER_ERROR_RANGE_END: () => HTTP_SERVER_ERROR_RANGE_END,
    HTTP_SERVER_ERROR_RANGE_START: () => HTTP_SERVER_ERROR_RANGE_START,
    HTTP_SERVICE_UNAVAILABLE: () => HTTP_SERVICE_UNAVAILABLE,
    HTTP_SUCCESS: () => HTTP_SUCCESS,
    HTTP_SUCCESS_RANGE_END: () => HTTP_SUCCESS_RANGE_END,
    HTTP_SUCCESS_RANGE_START: () => HTTP_SUCCESS_RANGE_START,
    HTTP_TOO_MANY_REQUESTS: () => HTTP_TOO_MANY_REQUESTS,
    HTTP_UNAUTHORIZED: () => HTTP_UNAUTHORIZED,
    HeaderNames: () => HeaderNames,
    HttpMethod: () => HttpMethod,
    IMDS_ENDPOINT: () => IMDS_ENDPOINT,
    IMDS_TIMEOUT: () => IMDS_TIMEOUT,
    IMDS_VERSION: () => IMDS_VERSION,
    INVALID_GRANT_ERROR: () => INVALID_GRANT_ERROR,
    INVALID_INSTANCE: () => INVALID_INSTANCE,
    JsonWebTokenTypes: () => JsonWebTokenTypes,
    KNOWN_PUBLIC_CLOUDS: () => KNOWN_PUBLIC_CLOUDS,
    NOT_APPLICABLE: () => NOT_APPLICABLE,
    NOT_AVAILABLE: () => NOT_AVAILABLE,
    OAuthResponseType: () => OAuthResponseType,
    OFFLINE_ACCESS_SCOPE: () => OFFLINE_ACCESS_SCOPE,
    OIDC_DEFAULT_SCOPES: () => OIDC_DEFAULT_SCOPES,
    OIDC_SCOPES: () => OIDC_SCOPES,
    ONE_DAY_IN_MS: () => ONE_DAY_IN_MS,
    OPENID_SCOPE: () => OPENID_SCOPE,
    PROFILE_SCOPE: () => PROFILE_SCOPE,
    PasswordGrantConstants: () => PasswordGrantConstants,
    PersistentCacheKeys: () => PersistentCacheKeys,
    PromptValue: () => PromptValue,
    REGIONAL_AUTH_PUBLIC_CLOUD_SUFFIX: () => REGIONAL_AUTH_PUBLIC_CLOUD_SUFFIX,
    RESOURCE_DELIM: () => RESOURCE_DELIM,
    RegionDiscoveryOutcomes: () => RegionDiscoveryOutcomes,
    RegionDiscoverySources: () => RegionDiscoverySources,
    ResponseMode: () => ResponseMode,
    S256_CODE_CHALLENGE_METHOD: () => S256_CODE_CHALLENGE_METHOD,
    SERVER_TELEM_CACHE_KEY: () => SERVER_TELEM_CACHE_KEY,
    SERVER_TELEM_CATEGORY_SEPARATOR: () => SERVER_TELEM_CATEGORY_SEPARATOR,
    SERVER_TELEM_MAX_CACHED_ERRORS: () => SERVER_TELEM_MAX_CACHED_ERRORS,
    SERVER_TELEM_MAX_CUR_HEADER_BYTES: () => SERVER_TELEM_MAX_CUR_HEADER_BYTES,
    SERVER_TELEM_MAX_LAST_HEADER_BYTES: () => SERVER_TELEM_MAX_LAST_HEADER_BYTES,
    SERVER_TELEM_OVERFLOW_FALSE: () => SERVER_TELEM_OVERFLOW_FALSE,
    SERVER_TELEM_OVERFLOW_TRUE: () => SERVER_TELEM_OVERFLOW_TRUE,
    SERVER_TELEM_SCHEMA_VERSION: () => SERVER_TELEM_SCHEMA_VERSION,
    SERVER_TELEM_UNKNOWN_ERROR: () => SERVER_TELEM_UNKNOWN_ERROR,
    SERVER_TELEM_VALUE_SEPARATOR: () => SERVER_TELEM_VALUE_SEPARATOR,
    SHR_NONCE_VALIDITY: () => SHR_NONCE_VALIDITY,
    SKU: () => SKU,
    THE_FAMILY_ID: () => THE_FAMILY_ID,
    THROTTLING_PREFIX: () => THROTTLING_PREFIX,
    URL_FORM_CONTENT_TYPE: () => URL_FORM_CONTENT_TYPE,
    X_MS_LIB_CAPABILITY_VALUE: () => X_MS_LIB_CAPABILITY_VALUE
  });
  var SKU = "msal.js.common";
  var DEFAULT_AUTHORITY = "https://login.microsoftonline.com/common/";
  var DEFAULT_AUTHORITY_HOST = "login.microsoftonline.com";
  var DEFAULT_COMMON_TENANT = "common";
  var ADFS = "adfs";
  var AAD_INSTANCE_DISCOVERY_ENDPT = `${DEFAULT_AUTHORITY}discovery/instance?api-version=1.1&authorization_endpoint=`;
  var CIAM_AUTH_URL = ".ciamlogin.com";
  var AAD_TENANT_DOMAIN_SUFFIX = ".onmicrosoft.com";
  var RESOURCE_DELIM = "|";
  var CONSUMER_UTID = "9188040d-6c67-4c5b-b112-36a304b66dad";
  var OPENID_SCOPE = "openid";
  var PROFILE_SCOPE = "profile";
  var OFFLINE_ACCESS_SCOPE = "offline_access";
  var EMAIL_SCOPE = "email";
  var CODE_GRANT_TYPE = "authorization_code";
  var S256_CODE_CHALLENGE_METHOD = "S256";
  var URL_FORM_CONTENT_TYPE = "application/x-www-form-urlencoded;charset=utf-8";
  var AUTHORIZATION_PENDING = "authorization_pending";
  var NOT_APPLICABLE = "N/A";
  var NOT_AVAILABLE = "Not Available";
  var FORWARD_SLASH = "/";
  var IMDS_ENDPOINT = "http://169.254.169.254/metadata/instance/compute";
  var IMDS_VERSION = "2021-02-01";
  var IMDS_TIMEOUT = 2e3;
  var AZURE_REGION_AUTO_DISCOVER_FLAG = "TryAutoDetect";
  var REGIONAL_AUTH_PUBLIC_CLOUD_SUFFIX = "login.microsoft.com";
  var KNOWN_PUBLIC_CLOUDS = [
    "login.microsoftonline.com",
    "login.windows.net",
    "login.microsoft.com",
    "sts.windows.net"
  ];
  var SHR_NONCE_VALIDITY = 240;
  var INVALID_INSTANCE = "invalid_instance";
  var HTTP_SUCCESS = 200;
  var HTTP_SUCCESS_RANGE_START = 200;
  var HTTP_SUCCESS_RANGE_END = 299;
  var HTTP_REDIRECT = 302;
  var HTTP_CLIENT_ERROR = 400;
  var HTTP_CLIENT_ERROR_RANGE_START = 400;
  var HTTP_BAD_REQUEST = 400;
  var HTTP_UNAUTHORIZED = 401;
  var HTTP_NOT_FOUND = 404;
  var HTTP_REQUEST_TIMEOUT = 408;
  var HTTP_GONE = 410;
  var HTTP_TOO_MANY_REQUESTS = 429;
  var HTTP_CLIENT_ERROR_RANGE_END = 499;
  var HTTP_SERVER_ERROR = 500;
  var HTTP_SERVER_ERROR_RANGE_START = 500;
  var HTTP_SERVICE_UNAVAILABLE = 503;
  var HTTP_GATEWAY_TIMEOUT = 504;
  var HTTP_SERVER_ERROR_RANGE_END = 599;
  var HTTP_MULTI_SIDED_ERROR = 600;
  var HttpMethod = {
    GET: "GET",
    POST: "POST"
  };
  var OIDC_DEFAULT_SCOPES = [
    OPENID_SCOPE,
    PROFILE_SCOPE,
    OFFLINE_ACCESS_SCOPE
  ];
  var OIDC_SCOPES = [...OIDC_DEFAULT_SCOPES, EMAIL_SCOPE];
  var HeaderNames = {
    CONTENT_TYPE: "Content-Type",
    CONTENT_LENGTH: "Content-Length",
    DPOP: "DPoP",
    RETRY_AFTER: "Retry-After",
    CCS_HEADER: "X-AnchorMailbox",
    WWWAuthenticate: "WWW-Authenticate",
    AuthenticationInfo: "Authentication-Info",
    X_MS_REQUEST_ID: "x-ms-request-id",
    X_MS_HTTP_VERSION: "x-ms-httpver"
  };
  var PersistentCacheKeys = {
    ACTIVE_ACCOUNT_FILTERS: "active-account-filters"
    // new cache entry for active_account for a more robust version for browser
  };
  var AADAuthority = {
    COMMON: "common",
    ORGANIZATIONS: "organizations",
    CONSUMERS: "consumers"
  };
  var ClaimsRequestKeys = {
    ACCESS_TOKEN: "access_token",
    XMS_CC: "xms_cc",
    ID_TOKEN: "id_token",
    SIGNIN_STATE: "signin_state",
    LOGIN_HINT: "login_hint",
    TENANT_REGION_SUB_SCOPE: "tenant_region_sub_scope"
  };
  var PromptValue = {
    LOGIN: "login",
    SELECT_ACCOUNT: "select_account",
    CONSENT: "consent",
    NONE: "none",
    CREATE: "create",
    NO_SESSION: "no_session"
  };
  var CodeChallengeMethodValues = {
    PLAIN: "plain",
    S256: "S256"
  };
  var OAuthResponseType = {
    CODE: "code",
    IDTOKEN_TOKEN: "id_token token",
    IDTOKEN_TOKEN_REFRESHTOKEN: "id_token token refresh_token"
  };
  var ResponseMode = {
    QUERY: "query",
    FRAGMENT: "fragment",
    FORM_POST: "form_post"
  };
  var GrantType = {
    IMPLICIT_GRANT: "implicit",
    AUTHORIZATION_CODE_GRANT: "authorization_code",
    CLIENT_CREDENTIALS_GRANT: "client_credentials",
    RESOURCE_OWNER_PASSWORD_GRANT: "password",
    REFRESH_TOKEN_GRANT: "refresh_token",
    DEVICE_CODE_GRANT: "device_code",
    JWT_BEARER: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    USER_FIC: "user_fic"
  };
  var CACHE_ACCOUNT_TYPE_MSSTS = "MSSTS";
  var CACHE_ACCOUNT_TYPE_ADFS = "ADFS";
  var CACHE_ACCOUNT_TYPE_MSAV1 = "MSA";
  var CACHE_ACCOUNT_TYPE_GENERIC = "Generic";
  var CACHE_KEY_SEPARATOR = "-";
  var CLIENT_INFO_SEPARATOR = ".";
  var CredentialType = {
    ID_TOKEN: "IdToken",
    ACCESS_TOKEN: "AccessToken",
    ACCESS_TOKEN_WITH_AUTH_SCHEME: "AccessToken_With_AuthScheme",
    REFRESH_TOKEN: "RefreshToken"
  };
  var CacheType = {
    ADFS: 1001,
    MSA: 1002,
    MSSTS: 1003,
    GENERIC: 1004,
    ACCESS_TOKEN: 2001,
    REFRESH_TOKEN: 2002,
    ID_TOKEN: 2003,
    APP_METADATA: 3001,
    UNDEFINED: 9999
  };
  var APP_METADATA = "appmetadata";
  var CLIENT_INFO = "client_info";
  var THE_FAMILY_ID = "1";
  var AUTHORITY_METADATA_CACHE_KEY = "authority-metadata";
  var AUTHORITY_METADATA_REFRESH_TIME_SECONDS = 3600 * 24;
  var AuthorityMetadataSource = {
    CONFIG: "config",
    CACHE: "cache",
    NETWORK: "network",
    HARDCODED_VALUES: "hardcoded_values"
  };
  var SERVER_TELEM_SCHEMA_VERSION = 5;
  var SERVER_TELEM_MAX_CUR_HEADER_BYTES = 80;
  var SERVER_TELEM_MAX_LAST_HEADER_BYTES = 330;
  var SERVER_TELEM_MAX_CACHED_ERRORS = 50;
  var SERVER_TELEM_CACHE_KEY = "server-telemetry";
  var SERVER_TELEM_CATEGORY_SEPARATOR = "|";
  var SERVER_TELEM_VALUE_SEPARATOR = ",";
  var SERVER_TELEM_OVERFLOW_TRUE = "1";
  var SERVER_TELEM_OVERFLOW_FALSE = "0";
  var SERVER_TELEM_UNKNOWN_ERROR = "unknown_error";
  var AuthenticationScheme = {
    BEARER: "Bearer",
    POP: "pop",
    DPOP: "DPoP",
    SSH: "ssh-cert"
  };
  var DEFAULT_THROTTLE_TIME_SECONDS = 60;
  var DEFAULT_MAX_THROTTLE_TIME_SECONDS = 3600;
  var THROTTLING_PREFIX = "throttling";
  var X_MS_LIB_CAPABILITY_VALUE = "retry-after, h429";
  var INVALID_GRANT_ERROR = "invalid_grant";
  var CLIENT_MISMATCH_ERROR = "client_mismatch";
  var PasswordGrantConstants = {
    username: "username",
    password: "password"
  };
  var RegionDiscoverySources = {
    FAILED_AUTO_DETECTION: "1",
    INTERNAL_CACHE: "2",
    ENVIRONMENT_VARIABLE: "3",
    IMDS: "4"
  };
  var RegionDiscoveryOutcomes = {
    CONFIGURED_MATCHES_DETECTED: "1",
    CONFIGURED_NO_AUTO_DETECTION: "2",
    CONFIGURED_NOT_DETECTED: "3",
    AUTO_DETECTION_REQUESTED_SUCCESSFUL: "4",
    AUTO_DETECTION_REQUESTED_FAILED: "5"
  };
  var CacheOutcome = {
    // When a token is found in the cache or the cache is not supposed to be hit when making the request
    NOT_APPLICABLE: "0",
    // When the token request goes to the identity provider because force_refresh was set to true. Also occurs if claims were requested
    FORCE_REFRESH_OR_CLAIMS: "1",
    // When the token request goes to the identity provider because no cached access token exists
    NO_CACHED_ACCESS_TOKEN: "2",
    // When the token request goes to the identity provider because cached access token expired
    CACHED_ACCESS_TOKEN_EXPIRED: "3",
    // When the token request goes to the identity provider because refresh_in was used and the existing token needs to be refreshed
    PROACTIVELY_REFRESHED: "4"
  };
  var JsonWebTokenTypes = {
    Jwt: "JWT",
    Jwk: "JWK",
    Pop: "pop",
    Dpop: "dpop+jwt"
  };
  var ONE_DAY_IN_MS = 864e5;
  var DEFAULT_TOKEN_RENEWAL_OFFSET_SEC = 300;
  var EncodingTypes = {
    BASE64: "base64",
    HEX: "hex",
    UTF8: "utf-8"
  };

  // node_modules/@azure/msal-common/dist-browser/error/AuthError.mjs
  function getDefaultErrorMessage(code) {
    return `See https://aka.ms/msal.js.errors#${code} for details`;
  }
  var AuthError = class _AuthError extends Error {
    constructor(errorCode, correlationId, errorMessage, suberror) {
      const message = errorMessage || (errorCode ? getDefaultErrorMessage(errorCode) : "");
      const errorString = message ? `${errorCode}: ${message}` : errorCode;
      super(errorString);
      Object.setPrototypeOf(this, _AuthError.prototype);
      this.errorCode = errorCode || "";
      this.errorMessage = message || "";
      this.subError = suberror || "";
      this.correlationId = correlationId;
      this.name = "AuthError";
    }
  };

  // node_modules/@azure/msal-common/dist-browser/error/ClientAuthError.mjs
  var ClientAuthError = class _ClientAuthError extends AuthError {
    constructor(errorCode, correlationId, additionalMessage) {
      super(errorCode, correlationId, additionalMessage);
      this.name = "ClientAuthError";
      Object.setPrototypeOf(this, _ClientAuthError.prototype);
    }
  };
  function createClientAuthError(errorCode, correlationId, additionalMessage) {
    return new ClientAuthError(errorCode, correlationId, additionalMessage);
  }

  // node_modules/@azure/msal-common/dist-browser/error/ClientAuthErrorCodes.mjs
  var invalidState = "invalid_state";
  var cannotRemoveEmptyScope = "cannot_remove_empty_scope";
  var cannotAppendScopeSet = "cannot_append_scopeset";
  var emptyInputScopeSet = "empty_input_scopeset";
  var noCryptoObject = "no_crypto_object";

  // node_modules/@azure/msal-common/dist-browser/error/ClientConfigurationError.mjs
  var ClientConfigurationError = class _ClientConfigurationError extends AuthError {
    constructor(errorCode, correlationId) {
      super(errorCode, correlationId);
      this.name = "ClientConfigurationError";
      Object.setPrototypeOf(this, _ClientConfigurationError.prototype);
    }
  };
  function createClientConfigurationError(errorCode, correlationId) {
    return new ClientConfigurationError(errorCode, correlationId);
  }

  // node_modules/@azure/msal-common/dist-browser/error/ClientConfigurationErrorCodes.mjs
  var authorityUriInsecure = "authority_uri_insecure";
  var urlParseError = "url_parse_error";
  var urlEmptyError = "empty_url_error";
  var emptyInputScopesError = "empty_input_scopes_error";
  var invalidClaims = "invalid_claims";
  var pkceParamsMissing = "pkce_params_missing";

  // node_modules/@azure/msal-common/dist-browser/utils/StringUtils.mjs
  var StringUtils = class {
    /**
     * Check if stringified object is empty
     * @param strObj
     */
    static isEmptyObj(strObj) {
      if (strObj) {
        try {
          const obj = JSON.parse(strObj);
          return Object.keys(obj).length === 0;
        } catch (e) {
        }
      }
      return true;
    }
    static startsWith(str, search) {
      return str.indexOf(search) === 0;
    }
    static endsWith(str, search) {
      return str.length >= search.length && str.lastIndexOf(search) === str.length - search.length;
    }
    /**
     * Parses string into an object.
     *
     * @param query
     */
    static queryStringToObject(query) {
      const obj = {};
      const params = query.split("&");
      const decode = (s) => decodeURIComponent(s.replace(/\+/g, " "));
      params.forEach((pair) => {
        if (pair.trim()) {
          const [key, value] = pair.split(/=(.+)/g, 2);
          if (key && value) {
            obj[decode(key)] = decode(value);
          }
        }
      });
      return obj;
    }
    /**
     * Trims entries in an array.
     *
     * @param arr
     */
    static trimArrayEntries(arr) {
      return arr.map((entry) => entry.trim());
    }
    /**
     * Removes empty strings from array
     * @param arr
     */
    static removeEmptyStringsFromArray(arr) {
      return arr.filter((entry) => {
        return !!entry;
      });
    }
    /**
     * Attempts to parse a string into JSON
     * @param str
     */
    static jsonParseHelper(str) {
      try {
        return JSON.parse(str);
      } catch (e) {
        return null;
      }
    }
  };

  // node_modules/@azure/msal-common/dist-browser/url/UrlString.mjs
  var UrlString = class _UrlString {
    get urlString() {
      return this._urlString;
    }
    constructor(url, correlationId) {
      this._urlString = url;
      this.correlationId = correlationId;
      if (!this._urlString) {
        throw createClientConfigurationError(urlEmptyError, correlationId);
      }
      if (!url.includes("#")) {
        this._urlString = _UrlString.canonicalizeUri(url);
      }
    }
    /**
     * Ensure urls are lower case and end with a / character.
     * @param url
     */
    static canonicalizeUri(url) {
      if (url) {
        let lowerCaseUrl = url.toLowerCase();
        if (StringUtils.endsWith(lowerCaseUrl, "?")) {
          lowerCaseUrl = lowerCaseUrl.slice(0, -1);
        } else if (StringUtils.endsWith(lowerCaseUrl, "?/")) {
          lowerCaseUrl = lowerCaseUrl.slice(0, -2);
        }
        if (!StringUtils.endsWith(lowerCaseUrl, "/")) {
          lowerCaseUrl += "/";
        }
        return lowerCaseUrl;
      }
      return url;
    }
    /**
     * Throws if urlString passed is not a valid authority URI string.
     */
    validateAsUri() {
      let components;
      try {
        components = this.getUrlComponents();
      } catch (e) {
        throw createClientConfigurationError(urlParseError, this.correlationId);
      }
      if (!components.HostNameAndPort || !components.PathSegments) {
        throw createClientConfigurationError(urlParseError, this.correlationId);
      }
      if (!components.Protocol || components.Protocol.toLowerCase() !== "https:") {
        throw createClientConfigurationError(authorityUriInsecure, this.correlationId);
      }
    }
    /**
     * Given a url and a query string return the url with provided query string appended
     * @param url
     * @param queryString
     */
    static appendQueryString(url, queryString) {
      if (!queryString) {
        return url;
      }
      return url.indexOf("?") < 0 ? `${url}?${queryString}` : `${url}&${queryString}`;
    }
    /**
     * Returns a url with the hash removed
     * @param url
     */
    static removeHashFromUrl(url) {
      return _UrlString.canonicalizeUri(url.split("#")[0]);
    }
    /**
     * Given a url like https://a:b/common/d?e=f#g, and a tenantId, returns https://a:b/tenantId/d
     * @param href The url
     * @param tenantId The tenant id to replace
     */
    replaceTenantPath(tenantId) {
      const urlObject = this.getUrlComponents();
      const pathArray = urlObject.PathSegments;
      if (tenantId && pathArray.length !== 0 && (pathArray[0] === AADAuthority.COMMON || pathArray[0] === AADAuthority.ORGANIZATIONS)) {
        pathArray[0] = tenantId;
      }
      return _UrlString.constructAuthorityUriFromObject(urlObject, this.correlationId);
    }
    /**
     * Parses out the components from a url string.
     * @returns An object with the various components. Please cache this value insted of calling this multiple times on the same url.
     */
    getUrlComponents() {
      const regEx = RegExp("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?");
      const match = this.urlString.match(regEx);
      if (!match) {
        throw createClientConfigurationError(urlParseError, this.correlationId);
      }
      const urlComponents = {
        Protocol: match[1],
        HostNameAndPort: match[4],
        AbsolutePath: match[5],
        QueryString: match[7]
      };
      let pathSegments = urlComponents.AbsolutePath.split("/");
      pathSegments = pathSegments.filter((val) => val && val.length > 0);
      urlComponents.PathSegments = pathSegments;
      if (urlComponents.QueryString && urlComponents.QueryString.endsWith("/")) {
        urlComponents.QueryString = urlComponents.QueryString.substring(0, urlComponents.QueryString.length - 1);
      }
      return urlComponents;
    }
    static getDomainFromUrl(url, correlationId) {
      const regEx = RegExp("^([^:/?#]+://)?([^/?#]*)");
      const match = url.match(regEx);
      if (!match) {
        throw createClientConfigurationError(urlParseError, correlationId);
      }
      return match[2];
    }
    static getAbsoluteUrl(relativeUrl, baseUrl, correlationId) {
      if (relativeUrl[0] === FORWARD_SLASH) {
        const url = new _UrlString(baseUrl, correlationId);
        const baseComponents = url.getUrlComponents();
        return baseComponents.Protocol + "//" + baseComponents.HostNameAndPort + relativeUrl;
      }
      return relativeUrl;
    }
    static constructAuthorityUriFromObject(urlObject, correlationId) {
      return new _UrlString(urlObject.Protocol + "//" + urlObject.HostNameAndPort + "/" + urlObject.PathSegments.join("/"), correlationId);
    }
  };

  // node_modules/@azure/msal-common/dist-browser/cache/utils/CacheHelpers.mjs
  function serializeAttributeTokens(attributeTokens) {
    if (!attributeTokens || attributeTokens.length === 0) {
      return void 0;
    }
    return [...attributeTokens].sort().join(" ");
  }

  // node_modules/@azure/msal-common/dist-browser/request/RequestParameterBuilder.mjs
  var RequestParameterBuilder_exports = {};
  __export(RequestParameterBuilder_exports, {
    addApplicationTelemetry: () => addApplicationTelemetry,
    addAttributeTokens: () => addAttributeTokens,
    addAuthorizationCode: () => addAuthorizationCode,
    addBrokerParameters: () => addBrokerParameters,
    addCcsOid: () => addCcsOid,
    addCcsUpn: () => addCcsUpn,
    addClaims: () => addClaims,
    addCliData: () => addCliData,
    addClientAssertion: () => addClientAssertion,
    addClientAssertionType: () => addClientAssertionType,
    addClientId: () => addClientId,
    addClientInfo: () => addClientInfo,
    addClientSecret: () => addClientSecret,
    addCodeChallengeParams: () => addCodeChallengeParams,
    addCodeVerifier: () => addCodeVerifier,
    addCorrelationId: () => addCorrelationId,
    addDeviceCode: () => addDeviceCode,
    addDomainHint: () => addDomainHint,
    addEARParameters: () => addEARParameters,
    addExtraParameters: () => addExtraParameters,
    addGrantType: () => addGrantType,
    addIdTokenHint: () => addIdTokenHint,
    addInstanceAware: () => addInstanceAware,
    addLibraryInfo: () => addLibraryInfo,
    addLoginHint: () => addLoginHint,
    addLogoutHint: () => addLogoutHint,
    addNativeBroker: () => addNativeBroker,
    addNonce: () => addNonce,
    addOboAssertion: () => addOboAssertion,
    addPassword: () => addPassword,
    addPopToken: () => addPopToken,
    addPopupOriginCheckDone: () => addPopupOriginCheckDone,
    addPostLogoutRedirectUri: () => addPostLogoutRedirectUri,
    addPrompt: () => addPrompt,
    addRedirectUri: () => addRedirectUri,
    addRefreshToken: () => addRefreshToken,
    addRequestTokenUse: () => addRequestTokenUse,
    addResource: () => addResource,
    addResponseMode: () => addResponseMode,
    addResponseType: () => addResponseType,
    addScopes: () => addScopes,
    addServerTelemetry: () => addServerTelemetry,
    addSid: () => addSid,
    addSshJwk: () => addSshJwk,
    addState: () => addState,
    addThrottling: () => addThrottling,
    addUsername: () => addUsername,
    buildMergedClaims: () => buildMergedClaims,
    instrumentBrokerParams: () => instrumentBrokerParams
  });

  // node_modules/@azure/msal-common/dist-browser/request/ScopeSet.mjs
  var ScopeSet = class _ScopeSet {
    constructor(inputScopes, correlationId) {
      this.correlationId = correlationId;
      const scopeArr = inputScopes ? StringUtils.trimArrayEntries([...inputScopes]) : [];
      const filteredInput = scopeArr ? StringUtils.removeEmptyStringsFromArray(scopeArr) : [];
      if (!filteredInput || !filteredInput.length) {
        throw createClientConfigurationError(emptyInputScopesError, correlationId);
      }
      this.scopes = /* @__PURE__ */ new Set();
      filteredInput.forEach((scope) => this.scopes.add(scope));
    }
    /**
     * Factory method to create ScopeSet from space-delimited string
     * @param inputScopeString
     * @param appClientId
     * @param scopesRequired
     */
    static fromString(inputScopeString, correlationId) {
      const scopeString = inputScopeString || "";
      const inputScopes = scopeString.split(" ");
      return new _ScopeSet(inputScopes, correlationId);
    }
    /**
     * Creates the set of scopes to search for in cache lookups
     * @param inputScopeString
     * @returns
     */
    static createSearchScopes(inputScopeString, correlationId) {
      const scopesToUse = inputScopeString && inputScopeString.length > 0 ? inputScopeString : [...OIDC_DEFAULT_SCOPES];
      const scopeSet = new _ScopeSet(scopesToUse, correlationId);
      if (!scopeSet.containsOnlyOIDCScopes()) {
        scopeSet.removeOIDCScopes();
      } else {
        scopeSet.removeScope(OFFLINE_ACCESS_SCOPE);
      }
      return scopeSet;
    }
    /**
     * Check if a given scope is present in this set of scopes.
     * @param scope
     */
    containsScope(scope) {
      const lowerCaseScopes = this.printScopesLowerCase().split(" ");
      const lowerCaseScopesSet = new _ScopeSet(lowerCaseScopes, this.correlationId);
      return scope ? lowerCaseScopesSet.scopes.has(scope.toLowerCase()) : false;
    }
    /**
     * Check if a set of scopes is present in this set of scopes.
     * @param scopeSet
     */
    containsScopeSet(scopeSet) {
      if (!scopeSet || scopeSet.scopes.size <= 0) {
        return false;
      }
      return this.scopes.size >= scopeSet.scopes.size && scopeSet.asArray().every((scope) => this.containsScope(scope));
    }
    /**
     * Check if set of scopes contains only the defaults
     */
    containsOnlyOIDCScopes() {
      let defaultScopeCount = 0;
      OIDC_SCOPES.forEach((defaultScope) => {
        if (this.containsScope(defaultScope)) {
          defaultScopeCount += 1;
        }
      });
      return this.scopes.size === defaultScopeCount;
    }
    /**
     * Appends single scope if passed
     * @param newScope
     */
    appendScope(newScope) {
      if (newScope) {
        this.scopes.add(newScope.trim());
      }
    }
    /**
     * Appends multiple scopes if passed
     * @param newScopes
     */
    appendScopes(newScopes) {
      try {
        newScopes.forEach((newScope) => this.appendScope(newScope));
      } catch (e) {
        throw createClientAuthError(cannotAppendScopeSet, this.correlationId);
      }
    }
    /**
     * Removes element from set of scopes.
     * @param scope
     */
    removeScope(scope) {
      if (!scope) {
        throw createClientAuthError(cannotRemoveEmptyScope, this.correlationId);
      }
      this.scopes.delete(scope.trim());
    }
    /**
     * Removes default scopes from set of scopes
     * Primarily used to prevent cache misses if the default scopes are not returned from the server
     */
    removeOIDCScopes() {
      OIDC_SCOPES.forEach((defaultScope) => {
        this.scopes.delete(defaultScope);
      });
    }
    /**
     * Combines an array of scopes with the current set of scopes.
     * @param otherScopes
     */
    unionScopeSets(otherScopes) {
      if (!otherScopes) {
        throw createClientAuthError(emptyInputScopeSet, this.correlationId);
      }
      const unionScopes = /* @__PURE__ */ new Set();
      otherScopes.scopes.forEach((scope) => unionScopes.add(scope.toLowerCase()));
      this.scopes.forEach((scope) => unionScopes.add(scope.toLowerCase()));
      return unionScopes;
    }
    /**
     * Check if scopes intersect between this set and another.
     * @param otherScopes
     */
    intersectingScopeSets(otherScopes) {
      if (!otherScopes) {
        throw createClientAuthError(emptyInputScopeSet, this.correlationId);
      }
      if (!otherScopes.containsOnlyOIDCScopes()) {
        otherScopes.removeOIDCScopes();
      }
      const unionScopes = this.unionScopeSets(otherScopes);
      const sizeOtherScopes = otherScopes.getScopeCount();
      const sizeThisScopes = this.getScopeCount();
      const sizeUnionScopes = unionScopes.size;
      return sizeUnionScopes < sizeThisScopes + sizeOtherScopes;
    }
    /**
     * Returns size of set of scopes.
     */
    getScopeCount() {
      return this.scopes.size;
    }
    /**
     * Returns the scopes as an array of string values
     */
    asArray() {
      const array = [];
      this.scopes.forEach((val) => array.push(val));
      return array;
    }
    /**
     * Prints scopes into a space-delimited string
     */
    printScopes() {
      if (this.scopes) {
        const scopeArr = this.asArray();
        return scopeArr.join(" ");
      }
      return "";
    }
    /**
     * Prints scopes into a space-delimited lower-case string (used for caching)
     */
    printScopesLowerCase() {
      return this.printScopes().toLowerCase();
    }
  };

  // node_modules/@azure/msal-common/dist-browser/request/RequestParameterBuilder.mjs
  function instrumentBrokerParams(parameters, correlationId, performanceClient) {
    if (!correlationId) {
      return;
    }
    const clientId = parameters.get(CLIENT_ID);
    if (clientId && parameters.has(BROKER_CLIENT_ID)) {
      performanceClient?.addFields({
        embeddedClientId: clientId,
        embeddedRedirectUri: parameters.get(REDIRECT_URI)
      }, correlationId);
    }
  }
  function addResponseType(parameters, responseType) {
    parameters.set(RESPONSE_TYPE, responseType);
  }
  function addResponseMode(parameters, responseMode) {
    parameters.set(RESPONSE_MODE, responseMode ? responseMode : ResponseMode.QUERY);
  }
  function addNativeBroker(parameters) {
    parameters.set(NATIVE_BROKER, "1");
  }
  function addScopes(parameters, scopes, correlationId, addOidcScopes = true, defaultScopes = OIDC_DEFAULT_SCOPES) {
    if (addOidcScopes && !defaultScopes.includes("openid") && !scopes.includes("openid")) {
      defaultScopes.push("openid");
    }
    const requestScopes = addOidcScopes ? [...scopes || [], ...defaultScopes] : scopes || [];
    const scopeSet = new ScopeSet(requestScopes, correlationId);
    parameters.set(SCOPE, scopeSet.printScopes());
  }
  function addClientId(parameters, clientId) {
    parameters.set(CLIENT_ID, clientId);
  }
  function addRedirectUri(parameters, redirectUri) {
    parameters.set(REDIRECT_URI, redirectUri);
  }
  function addPostLogoutRedirectUri(parameters, redirectUri) {
    parameters.set(POST_LOGOUT_URI, redirectUri);
  }
  function addIdTokenHint(parameters, idTokenHint) {
    parameters.set(ID_TOKEN_HINT, idTokenHint);
  }
  function addDomainHint(parameters, domainHint) {
    parameters.set(DOMAIN_HINT, domainHint);
  }
  function addLoginHint(parameters, loginHint) {
    parameters.set(LOGIN_HINT, loginHint);
  }
  function addCcsUpn(parameters, loginHint) {
    parameters.set(HeaderNames.CCS_HEADER, `UPN:${loginHint}`);
  }
  function addCcsOid(parameters, clientInfo) {
    parameters.set(HeaderNames.CCS_HEADER, `Oid:${clientInfo.uid}@${clientInfo.utid}`);
  }
  function addSid(parameters, sid) {
    parameters.set(SID, sid);
  }
  function addClaims(parameters, correlationId, claims, clientCapabilities, skipBrokerClaims, claimsToMerge) {
    const configClaims = skipBrokerClaims && parameters.has(BROKER_CLIENT_ID) ? void 0 : clientCapabilities;
    const mergedClaims = buildMergedClaims(claims, configClaims, correlationId, claimsToMerge);
    parameters.set(CLAIMS, mergedClaims);
  }
  function addCorrelationId(parameters, correlationId) {
    parameters.set(CLIENT_REQUEST_ID, correlationId);
  }
  function addLibraryInfo(parameters, libraryInfo) {
    parameters.set(X_CLIENT_SKU, libraryInfo.sku);
    parameters.set(X_CLIENT_VER, libraryInfo.version);
    if (libraryInfo.os) {
      parameters.set(X_CLIENT_OS, libraryInfo.os);
    }
    if (libraryInfo.cpu) {
      parameters.set(X_CLIENT_CPU, libraryInfo.cpu);
    }
  }
  function addApplicationTelemetry(parameters, appTelemetry) {
    if (appTelemetry?.appName) {
      parameters.set(X_APP_NAME, appTelemetry.appName);
    }
    if (appTelemetry?.appVersion) {
      parameters.set(X_APP_VER, appTelemetry.appVersion);
    }
  }
  function addPrompt(parameters, prompt) {
    parameters.set(PROMPT, prompt);
  }
  function addState(parameters, state) {
    if (state) {
      parameters.set(STATE, state);
    }
  }
  function addNonce(parameters, nonce) {
    parameters.set(NONCE, nonce);
  }
  function addCodeChallengeParams(parameters, codeChallenge, codeChallengeMethod) {
    if (codeChallenge && codeChallengeMethod) {
      parameters.set(CODE_CHALLENGE, codeChallenge);
      parameters.set(CODE_CHALLENGE_METHOD, codeChallengeMethod);
    } else {
      throw createClientConfigurationError(pkceParamsMissing, "");
    }
  }
  function addAuthorizationCode(parameters, code) {
    parameters.set(CODE, code);
  }
  function addDeviceCode(parameters, code) {
    parameters.set(DEVICE_CODE, code);
  }
  function addRefreshToken(parameters, refreshToken) {
    parameters.set(REFRESH_TOKEN, refreshToken);
  }
  function addCodeVerifier(parameters, codeVerifier) {
    parameters.set(CODE_VERIFIER, codeVerifier);
  }
  function addClientSecret(parameters, clientSecret) {
    parameters.set(CLIENT_SECRET, clientSecret);
  }
  function addClientAssertion(parameters, clientAssertion) {
    if (clientAssertion) {
      parameters.set(CLIENT_ASSERTION, clientAssertion);
    }
  }
  function addClientAssertionType(parameters, clientAssertionType) {
    if (clientAssertionType) {
      parameters.set(CLIENT_ASSERTION_TYPE, clientAssertionType);
    }
  }
  function addOboAssertion(parameters, oboAssertion) {
    parameters.set(OBO_ASSERTION, oboAssertion);
  }
  function addRequestTokenUse(parameters, tokenUse) {
    parameters.set(REQUESTED_TOKEN_USE, tokenUse);
  }
  function addGrantType(parameters, grantType) {
    parameters.set(GRANT_TYPE, grantType);
  }
  function addClientInfo(parameters) {
    parameters.set(CLIENT_INFO, "1");
  }
  function addCliData(parameters) {
    parameters.set(CLI_DATA, "1");
  }
  function addInstanceAware(parameters) {
    if (!parameters.has(INSTANCE_AWARE)) {
      parameters.set(INSTANCE_AWARE, "true");
    }
  }
  function addPopupOriginCheckDone(parameters) {
    if (!parameters.has(POPUP_ORIGIN_CHECK_DONE)) {
      parameters.set(POPUP_ORIGIN_CHECK_DONE, "1");
    }
  }
  function addExtraParameters(parameters, extraParams) {
    Object.entries(extraParams).forEach(([key, value]) => {
      if (!parameters.has(key) && value) {
        parameters.set(key, value);
      }
    });
  }
  var DEFAULT_ID_TOKEN_CLAIMS = {
    [ClaimsRequestKeys.SIGNIN_STATE]: { essential: false },
    [ClaimsRequestKeys.LOGIN_HINT]: { essential: false },
    [ClaimsRequestKeys.TENANT_REGION_SUB_SCOPE]: {
      essential: false
    }
  };
  function parseClaims(claims, correlationId = "") {
    let parsed;
    try {
      parsed = JSON.parse(claims);
    } catch (e) {
      throw createClientConfigurationError(invalidClaims, correlationId);
    }
    if (!isPlainObject(parsed)) {
      throw createClientConfigurationError(invalidClaims, correlationId);
    }
    return parsed;
  }
  function isPlainObject(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
  }
  function deepMergeClaims(baseClaims, claimsToMerge) {
    const merged = { ...baseClaims };
    for (const [key, mergeInValue] of Object.entries(claimsToMerge)) {
      const baseValue = merged[key];
      if (isPlainObject(baseValue) && isPlainObject(mergeInValue)) {
        merged[key] = deepMergeClaims(baseValue, mergeInValue);
      } else {
        merged[key] = mergeInValue;
      }
    }
    return merged;
  }
  function buildMergedClaims(claims, clientCapabilities, correlationId = "", claimsToMerge) {
    let mergedClaims = claims ? parseClaims(claims, correlationId) : {};
    if (claimsToMerge?.trim()) {
      mergedClaims = deepMergeClaims(mergedClaims, parseClaims(claimsToMerge, correlationId));
    }
    if (!Object.prototype.hasOwnProperty.call(mergedClaims, ClaimsRequestKeys.ID_TOKEN)) {
      mergedClaims[ClaimsRequestKeys.ID_TOKEN] = {};
    }
    const idTokenClaims = mergedClaims[ClaimsRequestKeys.ID_TOKEN];
    for (const [key, value] of Object.entries(DEFAULT_ID_TOKEN_CLAIMS)) {
      if (!(key in idTokenClaims)) {
        idTokenClaims[key] = value;
      }
    }
    if (clientCapabilities && clientCapabilities.length > 0) {
      if (!Object.prototype.hasOwnProperty.call(mergedClaims, ClaimsRequestKeys.ACCESS_TOKEN)) {
        mergedClaims[ClaimsRequestKeys.ACCESS_TOKEN] = {};
      }
      mergedClaims[ClaimsRequestKeys.ACCESS_TOKEN][ClaimsRequestKeys.XMS_CC] = {
        values: clientCapabilities
      };
    }
    return JSON.stringify(mergedClaims);
  }
  function addUsername(parameters, username) {
    parameters.set(PasswordGrantConstants.username, username);
  }
  function addPassword(parameters, password) {
    parameters.set(PasswordGrantConstants.password, password);
  }
  function addPopToken(parameters, cnfString) {
    if (cnfString) {
      parameters.set(TOKEN_TYPE, AuthenticationScheme.POP);
      parameters.set(REQ_CNF, cnfString);
    }
  }
  function addSshJwk(parameters, sshJwkString) {
    if (sshJwkString) {
      parameters.set(TOKEN_TYPE, AuthenticationScheme.SSH);
      parameters.set(REQ_CNF, sshJwkString);
    }
  }
  function addServerTelemetry(parameters, serverTelemetryManager) {
    parameters.set(X_CLIENT_CURR_TELEM, serverTelemetryManager.generateCurrentRequestHeaderValue());
    parameters.set(X_CLIENT_LAST_TELEM, serverTelemetryManager.generateLastRequestHeaderValue());
  }
  function addThrottling(parameters) {
    parameters.set(X_MS_LIB_CAPABILITY, X_MS_LIB_CAPABILITY_VALUE);
  }
  function addLogoutHint(parameters, logoutHint) {
    parameters.set(LOGOUT_HINT, logoutHint);
  }
  function addBrokerParameters(parameters, brokerClientId, brokerRedirectUri) {
    if (!parameters.has(BROKER_CLIENT_ID)) {
      parameters.set(BROKER_CLIENT_ID, brokerClientId);
    }
    if (!parameters.has(BROKER_REDIRECT_URI)) {
      parameters.set(BROKER_REDIRECT_URI, brokerRedirectUri);
    }
  }
  function addEARParameters(parameters, jwk) {
    parameters.set(EAR_JWK, encodeURIComponent(jwk));
    const jweCryptoB64Encoded = "eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0";
    parameters.set(EAR_JWE_CRYPTO, jweCryptoB64Encoded);
  }
  function addResource(parameters, resource) {
    if (resource) {
      parameters.set(RESOURCE, resource);
    }
  }
  function addAttributeTokens(parameters, attributeTokens) {
    const serialized = serializeAttributeTokens(attributeTokens);
    if (serialized) {
      parameters.set(ATTRIBUTE_TOKENS, serialized);
    } else {
      parameters.delete(ATTRIBUTE_TOKENS);
    }
  }

  // node_modules/@azure/msal-common/dist-browser/utils/ProtocolUtils.mjs
  var ProtocolUtils_exports = {};
  __export(ProtocolUtils_exports, {
    generateLibraryState: () => generateLibraryState,
    parseRequestState: () => parseRequestState,
    setRequestState: () => setRequestState
  });
  function setRequestState(cryptoObj, userState, meta, correlationId) {
    const libraryState = generateLibraryState(cryptoObj, correlationId, meta);
    return userState ? `${libraryState}${RESOURCE_DELIM}${userState}` : libraryState;
  }
  function generateLibraryState(cryptoObj, correlationId, meta) {
    if (!cryptoObj) {
      throw createClientAuthError(noCryptoObject, correlationId);
    }
    const stateObj = {
      id: cryptoObj.createNewGuid()
    };
    if (meta) {
      stateObj.meta = meta;
    }
    const stateString = JSON.stringify(stateObj);
    return cryptoObj.base64Encode(stateString);
  }
  function parseRequestState(base64Decode2, state, correlationId) {
    if (!base64Decode2) {
      throw createClientAuthError(noCryptoObject, correlationId);
    }
    if (!state) {
      throw createClientAuthError(invalidState, correlationId);
    }
    try {
      const splitState = state.split(RESOURCE_DELIM);
      const libraryState = splitState[0];
      const userState = splitState.length > 1 ? splitState.slice(1).join(RESOURCE_DELIM) : "";
      const libraryStateString = base64Decode2(libraryState);
      const libraryStateObj = JSON.parse(libraryStateString);
      return {
        userRequestState: userState || "",
        libraryState: libraryStateObj
      };
    } catch (e) {
      throw createClientAuthError(invalidState, correlationId);
    }
  }

  // node_modules/@azure/msal-browser/dist/error/BrowserAuthError.mjs
  function getDefaultErrorMessage2(code) {
    return `See https://aka.ms/msal.js.errors#${code} for details`;
  }
  var BrowserAuthError = class _BrowserAuthError extends AuthError {
    constructor(errorCode, correlationId, subError) {
      super(errorCode, correlationId, getDefaultErrorMessage2(errorCode), subError);
      Object.setPrototypeOf(this, _BrowserAuthError.prototype);
      this.name = "BrowserAuthError";
    }
  };
  function createBrowserAuthError(errorCode, correlationId, subError) {
    return new BrowserAuthError(errorCode, correlationId, subError);
  }

  // node_modules/@azure/msal-browser/dist/error/BrowserAuthErrorCodes.mjs
  var noStateInHash = "no_state_in_hash";
  var unableToParseState = "unable_to_parse_state";
  var invalidBase64String = "invalid_base64_string";
  var timedOut = "timed_out";
  var emptyResponse = "empty_response";

  // node_modules/@azure/msal-browser/dist/encode/Base64Decode.mjs
  function base64Decode(input) {
    return new TextDecoder().decode(base64DecToArr(input));
  }
  function base64DecToArr(base64String) {
    let encodedString = base64String.replace(/-/g, "+").replace(/_/g, "/");
    switch (encodedString.length % 4) {
      case 0:
        break;
      case 2:
        encodedString += "==";
        break;
      case 3:
        encodedString += "=";
        break;
      default:
        throw createBrowserAuthError(invalidBase64String, "");
    }
    const binString = atob(encodedString);
    return Uint8Array.from(binString, (m) => m.codePointAt(0) || 0);
  }

  // node_modules/@azure/msal-browser/dist/utils/BrowserConstants.mjs
  var INTERACTION_TYPE = {
    SIGNIN: "signin",
    SIGNOUT: "signout"
  };
  var TemporaryCacheKeys = {
    ORIGIN_URI: "request.origin",
    URL_HASH: "urlHash",
    REQUEST_PARAMS: "request.params",
    VERIFIER: "code.verifier",
    INTERACTION_STATUS_KEY: "interaction.status",
    NATIVE_REQUEST: "request.native"
  };
  var ApiId = {
    acquireTokenRedirect: 861,
    acquireTokenPopup: 862,
    ssoSilent: 863,
    acquireTokenSilent_authCode: 864,
    handleRedirectPromise: 865,
    acquireTokenByCode: 866,
    acquireTokenSilent_silentFlow: 61,
    logout: 961,
    logoutPopup: 962,
    hydrateCache: 963,
    loadExternalTokens: 964
  };
  var InteractionType;
  (function(InteractionType2) {
    InteractionType2["Redirect"] = "redirect";
    InteractionType2["Popup"] = "popup";
    InteractionType2["Silent"] = "silent";
    InteractionType2["None"] = "none";
  })(InteractionType || (InteractionType = {}));
  var DEFAULT_REQUEST = {
    scopes: Constants_exports.OIDC_DEFAULT_SCOPES
  };
  var DB_NAME = "msal.db";
  var DB_TABLE_NAME = `${DB_NAME}.keys`;
  var CacheLookupPolicy = {
    /*
     * acquireTokenSilent will attempt to retrieve an access token from the cache. If the access token is expired
     * or cannot be found the refresh token will be used to acquire a new one. Finally, if the refresh token
     * is expired acquireTokenSilent will attempt to acquire new access and refresh tokens.
     */
    Default: 0,
    /*
     * acquireTokenSilent will only look for access tokens in the cache. It will not attempt to renew access or
     * refresh tokens.
     */
    AccessToken: 1,
    /*
     * acquireTokenSilent will attempt to retrieve an access token from the cache. If the access token is expired or
     * cannot be found, the refresh token will be used to acquire a new one. If the refresh token is expired, it
     * will not be renewed and acquireTokenSilent will fail.
     */
    AccessTokenAndRefreshToken: 2,
    /*
     * acquireTokenSilent will not attempt to retrieve access tokens from the cache and will instead attempt to
     * exchange the cached refresh token for a new access token. If the refresh token is expired, it will not be
     * renewed and acquireTokenSilent will fail.
     */
    RefreshToken: 3,
    /*
     * acquireTokenSilent will not look in the cache for the access token. It will go directly to network with the
     * cached refresh token. If the refresh token is expired an attempt will be made to renew it. This is equivalent to
     * setting "forceRefresh: true".
     */
    RefreshTokenAndNetwork: 4,
    /*
     * acquireTokenSilent will attempt to renew both access and refresh tokens. It will not look in the cache. This will
     * always fail if 3rd party cookies are blocked by the browser.
     */
    Skip: 5
  };
  var iFrameRenewalPolicies = [
    CacheLookupPolicy.Default,
    CacheLookupPolicy.Skip,
    CacheLookupPolicy.RefreshTokenAndNetwork
  ];

  // node_modules/@azure/msal-browser/dist/utils/BrowserUtils.mjs
  function parseAuthResponseFromUrl() {
    const urlHash = window.location.hash;
    const urlQuery = window.location.search;
    let hasResponseInHash = false;
    let hasResponseInQuery = false;
    let payload = "";
    let params = void 0;
    if (urlHash && urlHash.length > 1) {
      const hashContent = urlHash.charAt(0) === "#" ? urlHash.substring(1) : urlHash;
      const hashParams = new URLSearchParams(hashContent);
      if (hashParams.has("state")) {
        hasResponseInHash = true;
        payload = hashContent;
        params = hashParams;
      }
    }
    if (urlQuery && urlQuery.length > 1) {
      const queryContent = urlQuery.charAt(0) === "?" ? urlQuery.substring(1) : urlQuery;
      const queryParams = new URLSearchParams(queryContent);
      if (queryParams.has("state")) {
        hasResponseInQuery = true;
        payload = queryContent;
        params = queryParams;
      }
    }
    if (hasResponseInHash && hasResponseInQuery) {
      const queryContent = urlQuery.charAt(0) === "?" ? urlQuery.substring(1) : urlQuery;
      const hashContent = urlHash.charAt(0) === "#" ? urlHash.substring(1) : urlHash;
      payload = `${queryContent}${hashContent}`;
      params = new URLSearchParams(payload);
    }
    if (!payload || !params) {
      throw createBrowserAuthError(emptyResponse, "");
    }
    const state = params.get("state");
    if (!state) {
      throw createBrowserAuthError(noStateInHash, "");
    }
    const { libraryState } = ProtocolUtils_exports.parseRequestState(base64Decode, state, "");
    const { id, meta } = libraryState;
    if (!id || !meta) {
      throw createBrowserAuthError(unableToParseState, "", "missing_library_state");
    }
    return {
      params,
      payload,
      urlHash,
      urlQuery,
      hasResponseInHash,
      hasResponseInQuery,
      libraryState: {
        id,
        meta
      }
    };
  }
  function clearAuthResponseFromUrl(contentWindow) {
    if (typeof contentWindow.history?.replaceState === "function") {
      contentWindow.history.replaceState(null, "", `${contentWindow.location.origin}${contentWindow.location.pathname}`);
    }
  }
  function getHomepage(correlationId) {
    const currentUrl = new UrlString(window.location.href, correlationId || "");
    const urlComponents = currentUrl.getUrlComponents();
    return `${urlComponents.Protocol}//${urlComponents.HostNameAndPort}/`;
  }
  var buildMergedClaims2 = RequestParameterBuilder_exports.buildMergedClaims;

  // node_modules/@azure/msal-browser/dist/navigation/NavigationClient.mjs
  var NavigationClient = class _NavigationClient {
    /**
     * Navigates to other pages within the same web application
     * @param url
     * @param options
     */
    navigateInternal(url, options) {
      return _NavigationClient.defaultNavigateWindow(url, options);
    }
    /**
     * Navigates to other pages outside the web application i.e. the Identity Provider
     * @param url
     * @param options
     */
    navigateExternal(url, options) {
      return _NavigationClient.defaultNavigateWindow(url, options);
    }
    /**
     * Default navigation implementation invoked by the internal and external functions
     * @param url
     * @param options
     */
    static defaultNavigateWindow(url, options) {
      if (options.noHistory) {
        window.location.replace(url);
      } else {
        window.location.assign(url);
      }
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          reject(createBrowserAuthError(timedOut, "", "failed_to_redirect"));
        }, options.timeout);
      });
    }
  };

  // node_modules/@azure/msal-browser/dist/config/Configuration.mjs
  var DEFAULT_REDIRECT_TIMEOUT_MS = 3e4;

  // node_modules/@azure/msal-browser/dist/cache/CacheKeys.mjs
  var PREFIX = "msal";
  var BROWSER_PREFIX = "browser";
  var LOG_LEVEL_CACHE_KEY = `${PREFIX}.${BROWSER_PREFIX}.log.level`;
  var LOG_PII_CACHE_KEY = `${PREFIX}.${BROWSER_PREFIX}.log.pii`;
  var BROWSER_PERF_ENABLED_KEY = `${PREFIX}.${BROWSER_PREFIX}.performance.enabled`;
  var VERSION_CACHE_KEY = `${PREFIX}.version`;
  var SSO_CAPABLE = `${PREFIX}.${BROWSER_PREFIX}.sso.capable`;

  // node_modules/@azure/msal-browser/dist/redirect_bridge/index.mjs
  async function broadcastResponseToMainFrame(navigationClient) {
    document.title = "Microsoft Authentication";
    let parsedResponse;
    try {
      parsedResponse = parseAuthResponseFromUrl();
    } catch (error) {
      clearAuthResponseFromUrl(window);
      throw error;
    }
    const { payload, urlHash, urlQuery, hasResponseInHash, hasResponseInQuery, libraryState } = parsedResponse;
    const { id, meta } = libraryState;
    if (meta["interactionType"] === InteractionType.Redirect) {
      const navClient = navigationClient || new NavigationClient();
      let navigateToUrl = "";
      let clientId = "";
      let interactionType = "";
      const interactionKey = `${PREFIX}.${TemporaryCacheKeys.INTERACTION_STATUS_KEY}`;
      try {
        const rawInteractionStatus = window.sessionStorage.getItem(interactionKey);
        const interactionStatus = JSON.parse(rawInteractionStatus || "");
        clientId = interactionStatus.clientId || "";
        interactionType = interactionStatus.type;
        if (clientId) {
          const originKey = `${PREFIX}.${clientId}.${TemporaryCacheKeys.ORIGIN_URI}`;
          navigateToUrl = window.sessionStorage.getItem(originKey) || "";
        }
      } catch {
      }
      const navigationOptions = {
        apiId: interactionType === INTERACTION_TYPE.SIGNOUT ? ApiId.logout : ApiId.handleRedirectPromise,
        noHistory: true,
        timeout: DEFAULT_REDIRECT_TIMEOUT_MS
      };
      if (clientId) {
        try {
          window.sessionStorage.setItem(`${PREFIX}.${clientId}.${TemporaryCacheKeys.URL_HASH}`, payload);
        } catch {
        }
      }
      const url = navigateToUrl || getHomepage();
      const navigationUrl = url.endsWith("?") ? url.slice(0, -1) : url;
      await navClient.navigateInternal(navigationUrl, navigationOptions);
      return;
    }
    if (typeof window.history.replaceState === "function") {
      let newUrl = `${window.location.origin}${window.location.pathname}`;
      if (!hasResponseInHash && urlHash) {
        newUrl += urlHash;
      }
      if (!hasResponseInQuery && urlQuery) {
        newUrl += urlQuery;
      }
      window.history.replaceState(null, "", newUrl);
    }
    const channel = new BroadcastChannel(id);
    channel.postMessage({
      v: 1,
      payload
    });
    channel.close();
    try {
      window.close();
    } catch {
    }
  }

  // web/src/redirect_bridge.js
  broadcastResponseToMainFrame();
})();
/*! Bundled license information:

@azure/msal-common/dist-browser/constants/AADServerParamKeys.mjs:
@azure/msal-common/dist-browser/utils/Constants.mjs:
@azure/msal-common/dist-browser/error/AuthError.mjs:
@azure/msal-common/dist-browser/error/ClientAuthError.mjs:
@azure/msal-common/dist-browser/error/ClientAuthErrorCodes.mjs:
@azure/msal-common/dist-browser/error/ClientConfigurationError.mjs:
@azure/msal-common/dist-browser/error/ClientConfigurationErrorCodes.mjs:
@azure/msal-common/dist-browser/utils/StringUtils.mjs:
@azure/msal-common/dist-browser/url/UrlString.mjs:
@azure/msal-common/dist-browser/cache/utils/CacheHelpers.mjs:
@azure/msal-common/dist-browser/request/ScopeSet.mjs:
@azure/msal-common/dist-browser/request/RequestParameterBuilder.mjs:
@azure/msal-common/dist-browser/utils/ProtocolUtils.mjs:
@azure/msal-common/dist-browser/index-browser.mjs:
  (*! @azure/msal-common v16.16.1 2026-11-06 *)

@azure/msal-browser/dist/error/BrowserAuthError.mjs:
@azure/msal-browser/dist/error/BrowserAuthErrorCodes.mjs:
@azure/msal-browser/dist/encode/Base64Decode.mjs:
@azure/msal-browser/dist/utils/BrowserConstants.mjs:
@azure/msal-browser/dist/utils/BrowserUtils.mjs:
@azure/msal-browser/dist/navigation/NavigationClient.mjs:
@azure/msal-browser/dist/config/Configuration.mjs:
@azure/msal-browser/dist/cache/CacheKeys.mjs:
@azure/msal-browser/dist/redirect_bridge/index.mjs:
  (*! @azure/msal-browser v5.29.0 2026-11-06 *)
*/
