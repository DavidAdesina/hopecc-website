// index.mjs -- Hope Community Church contact form backend
// ---------------------------------------------------------------------
// WHAT THIS DOES
//   Receives the POST from contact.astro's fetch('/api/contact') call,
//   validates it server-side (never trust the browser -- this endpoint
//   is public and can be hit directly, bypassing the site's own JS
//   validation entirely), and emails it to info@hopecc.org.uk via SES.
//
// WHY VALIDATE AGAIN, WHEN contact.astro ALREADY DOES?
//   The frontend's checks only stop an accidental empty submission from
//   a real visitor using the real form. They do nothing against a bot or
//   script that POSTs directly to this URL, so the same checks (plus a
//   couple more) are repeated here, where they can't be skipped.
//
// ANTI-SPAM: HONEYPOT FIELD
//   If contact.astro is ever updated to include a hidden field named
//   "website" (invisible to real visitors via CSS, but visible to bots
//   that blindly fill in every field they find), this function silently
//   pretends success without sending an email whenever that field
//   arrives non-empty. Until that field exists in the form, this check
//   simply never triggers -- it's safe to ship ahead of that change.
// ---------------------------------------------------------------------

import { SESv2Client, SendEmailCommand } from '@aws-sdk/client-sesv2';

const ses = new SESv2Client({});
const CONTACT_EMAIL = process.env.CONTACT_FORM_EMAIL;

const MAX_LENGTHS = { fname: 100, lname: 100, email: 200, phone: 30, subject: 200, message: 5000 };
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ALLOWED_ORIGIN = 'https://hopecc.org.uk';

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
    },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body || '', 'base64').toString('utf-8')
    : event.body || '{}';

  let data;
  try {
    data = JSON.parse(rawBody);
  } catch {
    return response(400, { error: 'Invalid request body' });
  }

  // Honeypot -- see file header. Bots get a fake success, no email sent.
  if (data.website) {
    return response(200, { ok: true });
  }

  const fields = {
    fname: (data.fname || '').trim(),
    lname: (data.lname || '').trim(),
    email: (data.email || '').trim(),
    phone: (data.phone || '').trim(),
    subject: (data.subject || '').trim(),
    message: (data.message || '').trim(),
  };

  if (!fields.fname || !fields.email || !fields.message) {
    return response(400, { error: 'Missing required fields' });
  }
  if (!EMAIL_RE.test(fields.email)) {
    return response(400, { error: 'Invalid email address' });
  }
  for (const [key, value] of Object.entries(fields)) {
    if (value.length > MAX_LENGTHS[key]) {
      return response(400, { error: `${key} is too long` });
    }
  }

  const subjectLine = fields.subject
    ? `Contact form: ${fields.subject}`
    : 'New contact form message';
  const bodyText = [
    `Name: ${fields.fname} ${fields.lname}`.trim(),
    `Email: ${fields.email}`,
    `Phone: ${fields.phone || '(not provided)'}`,
    '',
    fields.message,
  ].join('\n');

  try {
    await ses.send(new SendEmailCommand({
      FromEmailAddress: CONTACT_EMAIL,
      Destination: { ToAddresses: [CONTACT_EMAIL] },
      ReplyToAddresses: [fields.email],
      Content: {
        Simple: {
          Subject: { Data: subjectLine, Charset: 'UTF-8' },
          Body: { Text: { Data: bodyText, Charset: 'UTF-8' } },
        },
      },
    }));
  } catch (err) {
    console.error('SES send failed:', err);
    return response(502, { error: 'Failed to send message' });
  }

  return response(200, { ok: true });
};
