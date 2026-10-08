// index.mjs -- Hope Community Church Decap CMS OAuth proxy
// ---------------------------------------------------------------------
// Implements GET /auth and GET /callback for Decap CMS's GitHub backend,
// standing in for the OAuth service Netlify would normally provide.
//
// PROTOCOL (verified against Decap's actual client-side listener code,
// decap-cms-lib-auth's netlify-auth.js -- Decap's own docs don't publish
// this directly):
//   1. Decap opens a popup at GET /auth.
//   2. /auth 302-redirects the popup to GitHub's authorize screen.
//   3. GitHub redirects the popup back to GET /callback?code=...&state=...
//   4. /callback exchanges the code + client secret for an access
//      token, server-side only -- the secret never reaches the browser.
//   5. /callback returns an HTML page whose script does a two-step
//      handshake with the opener window: it announces itself with
//      "authorizing:github", waits for Decap's own listener to echo
//      that back, and only then sends the real token as
//      "authorization:github:success:{...}". Skipping the handshake, or
//      getting a string prefix wrong, makes the popup silently do
//      nothing -- no visible error.
//
// SECURITY HARDENING (October 2026) -- three changes, each explained
// where it happens below:
//   A. ALLOWED_ORIGINS: the popup only hands the token to a window on
//      the church's own website. Before this, it replied to whichever
//      window echoed the handshake, so any other website that opened
//      /auth in a popup could receive a logged-in editor's token
//      (GitHub skips its consent screen for anyone who has already
//      approved this app, so the editor might never notice).
//   B. OAuth `state`: a random one-time value, stored in a short-lived
//      cookie on this API's own domain and checked when GitHub sends the
//      user back. Stops a "login CSRF" -- someone tricking a browser
//      into finishing a login that they started.
//   C. Scope `public_repo` instead of `repo`: the token can only touch
//      PUBLIC repositories. Before this, a leaked token could read and
//      write every repo the editor has, private ones included.
//      !! If hopecc-website is ever made PRIVATE, the CMS will stop
//      being able to save. Change OAUTH_SCOPE below to 'repo' (and
//      `auth_scope` in public/admin/config.yml) at the same time.
// ---------------------------------------------------------------------

import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { randomBytes, timingSafeEqual } from 'node:crypto';

const ssm = new SSMClient({});
const CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const CLIENT_SECRET_PARAM_NAME = process.env.GITHUB_CLIENT_SECRET_PARAM_NAME;
const REDIRECT_URI = process.env.REDIRECT_URI;

// EDIT (developer only): the only websites allowed to receive a login
// token. Exact origins -- scheme + host, no path, no trailing slash.
// /admin must be opened from one of these for login to work. (The
// CloudFront address, d3jmbi4qqbxnbe.cloudfront.net, is deliberately
// not listed: editors should always use hopecc.org.uk/admin.)
const ALLOWED_ORIGINS = ['https://hopecc.org.uk', 'https://www.hopecc.org.uk'];

// Fixed here on the server -- Decap asks for a scope in its /auth URL,
// but that's ignored, so nothing on the browser side can widen it.
const OAUTH_SCOPE = 'public_repo';

const STATE_COOKIE = 'decap_oauth_state';
const STATE_MAX_AGE_SECONDS = 900; // 15 minutes to finish signing in to GitHub (incl. 2FA)

let cachedSecret; // reused across warm invocations of the same execution environment

async function getClientSecret() {
  if (cachedSecret) return cachedSecret;
  const result = await ssm.send(new GetParameterCommand({
    Name: CLIENT_SECRET_PARAM_NAME,
    WithDecryption: true,
  }));
  cachedSecret = result.Parameter.Value;
  return cachedSecret;
}

// Every popup response carries these. `no-store` matters most: the
// callback page contains a live token and must never be cached.
const SECURITY_HEADERS = {
  'Cache-Control': 'no-store',
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
};

// The cookie is scoped to /callback on this API's own domain, so it is
// only ever sent back to the one route that checks it. HttpOnly keeps
// page scripts away from it; SameSite=Lax still lets it ride along on
// GitHub's top-level redirect back to /callback.
function stateCookie(value, maxAge) {
  return `${STATE_COOKIE}=${value}; Path=/callback; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Lax`;
}
const CLEAR_STATE_COOKIE = stateCookie('', 0);

function htmlResponse(statusCode, html, cookies = []) {
  return {
    statusCode,
    headers: { 'Content-Type': 'text/html; charset=utf-8', ...SECURITY_HEADERS },
    // HTTP API (payload v2) sets response cookies from this array.
    cookies,
    body: html,
  };
}

function redirectResponse(location, cookies = []) {
  return {
    statusCode: 302,
    headers: { Location: location, ...SECURITY_HEADERS },
    cookies,
  };
}

// HTTP API (payload v2) delivers request cookies as an array of
// "name=value" strings in event.cookies.
function readCookie(event, name) {
  for (const pair of event.cookies || []) {
    const i = pair.indexOf('=');
    if (i > 0 && pair.slice(0, i).trim() === name) return pair.slice(i + 1).trim();
  }
  return undefined;
}

// Constant-time comparison, so response timing can't leak how much of a
// guessed state value was right.
function sameValue(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  return bufA.length === bufB.length && timingSafeEqual(bufA, bufB);
}

// `message` is the full string, e.g. 'authorization:github:success:{"token":"...","provider":"github"}'
function handshakePage(message) {
  // JSON.stringify doesn't escape "<", so a value containing "</script>"
  // (e.g. a strange error message from GitHub) could otherwise end the
  // script block early. < is the same character to JavaScript.
  const safe = (value) => JSON.stringify(value).replace(/</g, '\\u003c');
  return `<!DOCTYPE html>
<html>
  <head><meta charset="utf-8"><title>Signing in…</title></head>
  <body>
    <p id="status">Finishing sign-in… this window should close by itself.</p>
    <script>
      (function() {
        var ALLOWED = ${safe(ALLOWED_ORIGINS)};
        var MESSAGE = ${safe(message)};
        var status = document.getElementById('status');

        if (!window.opener) {
          status.textContent = 'Sign-in can only be finished from the website\\u2019s /admin page. You can close this window.';
          return;
        }

        function receiveMessage(e) {
          // (A) Only answer the church website's own /admin window: the
          // echo must come from the window that opened this popup, carry
          // exactly the handshake text, and come from an allowed origin.
          // Anything else is ignored -- the token is never sent.
          if (e.source !== window.opener) return;
          if (e.data !== 'authorizing:github') return;
          if (ALLOWED.indexOf(e.origin) === -1) return;
          window.removeEventListener('message', receiveMessage, false);
          // Second lock: targetOrigin means the browser itself refuses to
          // deliver this if the opener has navigated somewhere else.
          window.opener.postMessage(MESSAGE, e.origin);
        }
        window.addEventListener('message', receiveMessage, false);

        // The announcement carries no secret, so it can go to any
        // origin -- the opener's origin is only checked on its reply.
        window.opener.postMessage('authorizing:github', '*');

        // If nothing valid answers (e.g. /admin opened from an address
        // not in the list above), say so instead of hanging silently.
        setTimeout(function() {
          status.textContent = 'Sign-in could not be completed. Please open the website at https://hopecc.org.uk/admin and try again.';
        }, 10000);
      })();
    </script>
  </body>
</html>`;
}

function errorPage(statusCode, message, cookies = []) {
  return htmlResponse(statusCode, handshakePage(
    'authorization:github:error:' + JSON.stringify({ message })
  ), cookies);
}

export const handler = async (event) => {
  const path = event.rawPath || '/';

  if (path === '/auth') {
    // (B) Fresh random state for this sign-in attempt.
    const state = randomBytes(32).toString('base64url');
    const authorizeUrl = new URL('https://github.com/login/oauth/authorize');
    authorizeUrl.searchParams.set('client_id', CLIENT_ID);
    authorizeUrl.searchParams.set('redirect_uri', REDIRECT_URI);
    authorizeUrl.searchParams.set('scope', OAUTH_SCOPE); // (C)
    authorizeUrl.searchParams.set('state', state);
    return redirectResponse(authorizeUrl.toString(), [stateCookie(state, STATE_MAX_AGE_SECONDS)]);
  }

  if (path === '/callback') {
    const params = event.queryStringParameters || {};

    // (B) The state GitHub hands back must match the cookie set by /auth
    // in this same browser. Checked before anything else, so a forged or
    // replayed callback never reaches the token exchange. The cookie is
    // cleared on every outcome -- each state value works once.
    const expectedState = readCookie(event, STATE_COOKIE);
    if (!expectedState || !sameValue(params.state, expectedState)) {
      console.warn('OAuth callback rejected: state missing or mismatched');
      return errorPage(400, 'Sign-in expired or was interrupted. Please close this window and try again.', [CLEAR_STATE_COOKIE]);
    }

    // e.g. the user pressed "Cancel" on GitHub's screen.
    if (params.error) {
      return errorPage(400, params.error_description || 'Sign-in was cancelled.', [CLEAR_STATE_COOKIE]);
    }

    const code = params.code;
    if (!code) {
      return errorPage(400, 'Missing authorization code', [CLEAR_STATE_COOKIE]);
    }

    try {
      const clientSecret = await getClientSecret();
      const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({
          client_id: CLIENT_ID,
          client_secret: clientSecret,
          code,
          redirect_uri: REDIRECT_URI,
        }),
      });
      const tokenData = await tokenRes.json();

      if (!tokenData.access_token) {
        // Log only GitHub's error code/description -- never the whole
        // response object, in case it ever contains anything sensitive.
        console.error('GitHub token exchange failed:', tokenData.error, tokenData.error_description);
        return errorPage(400, tokenData.error_description || 'Token exchange failed', [CLEAR_STATE_COOKIE]);
      }

      return htmlResponse(200, handshakePage(
        'authorization:github:success:' + JSON.stringify({ token: tokenData.access_token, provider: 'github' })
      ), [CLEAR_STATE_COOKIE]);
    } catch (err) {
      console.error('OAuth callback error:', err?.name, err?.message);
      return errorPage(500, 'Internal error during authentication', [CLEAR_STATE_COOKIE]);
    }
  }

  return { statusCode: 404, headers: SECURITY_HEADERS, body: 'Not found' };
};
