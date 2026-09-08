export const subject = "You’re on the Dayflower waitlist 🌷";
export const text = `You’re on the list.

Thanks for making a little room for Dayflower.

Your waitlist signup is saved. We’re building a private app for two, with little ways to stay close — starting on your home screen.

What happens next?
We’ll email you when Dayflower is ready to try. There’s no app account to create yet and no newsletter to keep up with.

While you wait, make a photo strip: https://mydayflower.com/photobooth

You received this confirmation because this address was entered on the Dayflower waitlist. If that wasn’t you, you can ignore this email.

Dayflower
https://mydayflower.com
Privacy: https://mydayflower.com/privacy`;

// Table layout and inline styles support email clients without web fonts/CSS.
// No recipient interpolation, tracking pixels, scripts, or external font requests.
export const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>You’re on the Dayflower waitlist</title></head>
<body style="margin:0;padding:0;background:#f8f6fb;color:#1c1024;font-family:Arial,Helvetica,sans-serif">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all">Your spot is saved. We’ll let you know when Dayflower is ready.</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f8f6fb"><tr><td align="center" style="padding:32px 16px">
<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="width:100%;max-width:560px;background:#ffffff;border:1px solid #eae5f0;border-radius:24px;overflow:hidden">
<tr><td style="padding:36px 32px;background:#100a1e;color:#f5f2f8">
<p style="margin:0 0 30px;font-size:19px;font-weight:bold;color:#f5f2f8">🌷 Dayflower</p>
<p style="margin:0 0 14px;color:#f0709f;font-size:12px;letter-spacing:2px;font-weight:bold">A LITTLE CLOSER</p>
<h1 style="margin:0;font-size:36px;line-height:1.15;color:#f5f2f8">You’re on the list.</h1>
<p style="margin:18px 0 0;font-size:17px;line-height:1.6;color:#d9d0e4">Thanks for making a little room for us.</p></td></tr>
<tr><td style="padding:32px">
<p style="margin:0 0 22px;font-size:16px;line-height:1.7;color:#564a5e">Your waitlist signup is saved. We’re building a private app for two, with little ways to stay close — starting on your home screen.</p>
<h2 style="margin:0 0 10px;font-size:20px;color:#1c1024">What happens next?</h2>
<p style="margin:0 0 26px;font-size:16px;line-height:1.7;color:#564a5e">We’ll email you when Dayflower is ready to try. There’s no app account to create yet and no newsletter to keep up with.</p>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td style="padding:24px;background:#fcedf4;border-radius:16px">
<h2 style="margin:0 0 10px;font-size:20px;color:#733952">A keepsake while you wait.</h2>
<p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#733952">Make a free photo strip, solo or together. Add your photos, pick a frame, and save the moment.</p>
<a href="https://mydayflower.com/photobooth" style="display:inline-block;background:#733952;color:#ffffff;text-decoration:none;font-weight:bold;font-size:15px;padding:14px 20px;border-radius:24px">Make a photo strip →</a>
</td></tr></table>
<p style="margin:28px 0 0;font-size:16px;line-height:1.6;color:#564a5e">See you soon,<br><strong>The Dayflower team</strong></p></td></tr>
<tr><td style="padding:24px 32px;border-top:1px solid #eae5f0;font-size:12px;line-height:1.7;color:#706479">You received this confirmation because this address was entered on the Dayflower waitlist. If that wasn’t you, you can ignore this email.<br><br><a href="https://mydayflower.com" style="color:#733952">Dayflower</a> &nbsp;·&nbsp; <a href="https://mydayflower.com/privacy" style="color:#733952">Privacy</a></td></tr>
</table></td></tr></table></body></html>`;
