// index.mjs -- Hope Community Church Decap CMS OAuth proxy
// ---------------------------------------------------------------------
// Implements GET /auth and GET /callback for Decap CMS's GitHub backend,
// standing in for the OAuth service Netlify would normally provide.
//
// PROTOCOL (verified against Decap's actual client-side listener code
// and the most widely-used community reference implementation -- Decap's
// own docs don't publish this directly):
//   1. Decap opens a popup at GET /auth.
//   2. /auth 302-redirects the popup to GitHub's authorize screen.
//   3. GitHub redirects the popup back to GET /callback?code=...
//   4. /callback exchanges the code + client secret for an access
//      token, server-side only -- the secret never reaches the browser.
//   5. /callback returns an HTML page whose script does a two-step
//      handshake with the opener window: it announces itself with
//      "authorizing:github", waits for Decap's own listener to echo
//      that back, and only then sends the real token as
//      "authorization:github:success:{...}". Skipping the handshake, or
//      getting a string prefix wrong, makes the popup silently do
//      nothing -- no visible error.
// ---------------------------------------------------------------------

import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssm = new SSMClient({});
const CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const CLIENT_SECRET_PARAM_NAME = process.env.GITHUB_CLIENT_SECRET_PARAM_NAME;
const REDIRECT_URI = process.env.REDIRECT_URI;

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

function htmlResponse(statusCode, html) {
  return {
    statusCode,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
    body: html,
  };
}

function redirectResponse(location) {
  return { statusCode: 302, headers: { Location: location } };
}

// `message` is the full string, e.g. 'authorization:github:success:{"token":"...","provider":"github"}'
function handshakePage(message) {
  return `<!DOCTYPE html>
<html>
  <body>
    <script>
      (function() {
        function receiveMessage(e) {
          window.opener.postMessage(${JSON.stringify(message)}, e.origin);
        }
        window.addEventListener('message', receiveMessage, false);
        window.opener.postMessage('authorizing:github', '*');
      })();
    </script>
  </body>
</html>`;
}

export const handler = async (event) => {
  const path = event.rawPath || '/';

  if (path === '/auth') {
    const authorizeUrl = new URL('https://github.com/login/oauth/authorize');
    authorizeUrl.searchParams.set('client_id', CLIENT_ID);
    authorizeUrl.searchParams.set('redirect_uri', REDIRECT_URI);
    authorizeUrl.searchParams.set('scope', 'repo');
    return redirectResponse(authorizeUrl.toString());
  }

  if (path === '/callback') {
    const code = event.queryStringParameters?.code;
    if (!code) {
      return htmlResponse(400, handshakePage(
        'authorization:github:error:' + JSON.stringify({ message: 'Missing authorization code' })
      ));
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
        console.error('GitHub token exchange failed:', tokenData);
        return htmlResponse(400, handshakePage(
          'authorization:github:error:' + JSON.stringify({ message: tokenData.error_description || 'Token exchange failed' })
        ));
      }

      return htmlResponse(200, handshakePage(
        'authorization:github:success:' + JSON.stringify({ token: tokenData.access_token, provider: 'github' })
      ));
    } catch (err) {
      console.error('OAuth callback error:', err);
      return htmlResponse(500, handshakePage(
        'authorization:github:error:' + JSON.stringify({ message: 'Internal error during authentication' })
      ));
    }
  }

  return { statusCode: 404, body: 'Not found' };
};
