/**
 * The email a gift arrives in.
 *
 * ⚠️ **The subject and the body never say what is inside.** It lands in a
 * notification on a lock screen before it is opened, and the surprise is the
 * whole point — the same rule the link preview follows. No "bouquet", no
 * "flowers".
 *
 * Built the same way as the waitlist confirmation: tables and inline styles,
 * no web fonts, no scripts, no tracking pixel. The one image is the gift's
 * own preview card, served from the same endpoint the chat apps use, so a
 * client that blocks images still gets a complete email from the text alone.
 *
 * ⚠️ `from` is always our own domain. The sender's name goes in the body,
 * never the From header — letting a stranger put any name and address on mail
 * we send is how a nice feature becomes a phishing tool.
 */

const ESCAPES: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
function escape(value: string) {
  return value.replace(/[&<>"']/g, character => ESCAPES[character]);
}

export type GiftEmail = { url: string; imageUrl: string; to: string; from: string; note: string };

export function subjectFor({ from }: { from: string }) {
  const who = from.trim();
  return who ? `${who} left you something 🌷` : "Someone left you something 🌷";
}

export function textFor({ url, to, from, note }: GiftEmail) {
  const greeting = to.trim() ? `${to.trim()},` : "Hello,";
  const signed = from.trim() ? `${from.trim()} made it for you.` : "Someone made it for you.";
  return `${greeting}

There's a little something waiting for you.

${signed}
${note.trim() ? `\nThey wrote: "${note.trim()}"\n` : ""}
Open it here:
${url}

This link was sent from Dayflower because someone entered this address to send you a gift. If that wasn't meant for you, you can ignore this email — we don't keep the address.

Dayflower
https://mydayflower.com
Privacy: https://mydayflower.com/privacy`;
}

export function htmlFor({ url, imageUrl, to, from, note }: GiftEmail) {
  const greeting = to.trim() ? `${escape(to.trim())},` : "Hello,";
  const signed = from.trim() ? `${escape(from.trim())} made it for you.` : "Someone made it for you.";
  const written = note.trim()
    ? `<tr><td style="padding:0 32px 26px">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#fcedf4;border-radius:18px">
          <tr><td style="padding:22px 24px;font-family:Georgia,'Times New Roman',serif;font-style:italic;font-size:17px;line-height:1.6;color:#6d3f58">&ldquo;${escape(note.trim())}&rdquo;</td></tr>
        </table>
      </td></tr>`
    : "";

  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(subjectFor({ from }))}</title></head>
<body style="margin:0;padding:0;background:#f8f6fb;color:#1c1024;font-family:Arial,Helvetica,sans-serif">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all">Open it when you have a minute.</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8f6fb"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="width:100%;max-width:560px;background:#ffffff;border:1px solid #eae5f0;border-radius:24px;overflow:hidden">

<tr><td style="padding:34px 32px 26px;background:#100a1e;color:#f5f2f8">
  <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 0 26px"><tr>
    <td style="padding-right:10px;vertical-align:middle"><img src="https://mydayflower.com/mark.png" width="32" height="32" alt="" style="display:block;border:0;width:32px;height:32px"></td>
    <td style="vertical-align:middle;font-size:18px;font-weight:bold;color:#f5f2f8">Dayflower</td>
  </tr></table>
  <p style="margin:0 0 12px;color:#f0709f;font-size:12px;letter-spacing:2px;font-weight:bold">A LITTLE SOMETHING</p>
  <h1 style="margin:0;font-size:32px;line-height:1.2;color:#f5f2f8">${greeting}<br>this is for you.</h1>
</td></tr>

<tr><td style="padding:28px 32px 8px">
  <a href="${escape(url)}" style="text-decoration:none"><img src="${escape(imageUrl)}" width="496" alt="" style="display:block;border:0;width:100%;max-width:496px;border-radius:18px"></a>
</td></tr>

<tr><td style="padding:22px 32px 8px;font-size:16px;line-height:1.7;color:#574a66">
  There&rsquo;s a little something waiting for you. ${signed}
</td></tr>

${written}

<tr><td align="center" style="padding:4px 32px 34px">
  <a href="${escape(url)}" style="display:inline-block;padding:15px 34px;border-radius:999px;background:#d5568f;color:#ffffff;font-size:16px;font-weight:bold;text-decoration:none">Open your gift</a>
  <p style="margin:16px 0 0;font-size:13px;line-height:1.6;color:#8e8698">Or paste this into your browser:<br><span style="color:#8b72e0;word-break:break-all">${escape(url)}</span></p>
</td></tr>

<tr><td style="padding:20px 32px 28px;border-top:1px solid #eae5f0;font-size:12px;line-height:1.7;color:#8e8698">
  This was sent from Dayflower because someone entered this address to send you a gift. If it wasn&rsquo;t meant for you, you can ignore it &mdash; we don&rsquo;t keep the address.<br>
  <a href="https://mydayflower.com" style="color:#8b72e0">mydayflower.com</a> &middot; <a href="https://mydayflower.com/privacy" style="color:#8b72e0">Privacy</a>
</td></tr>

</table></td></tr></table></body></html>`;
}
