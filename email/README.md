# Email Drafts (Zoho Mail)

This folder contains ready-to-send email drafts for sharing **free iOS promo codes** for nexios player.

## Files

- `email/ios-monthly-premium-code.html` / `email/ios-monthly-premium-code.txt`
- `email/ios-lifetime-premium-code.html` / `email/ios-lifetime-premium-code.txt`
- Collage images (optional): `email/email_collage.png` plus variants `email/email_collage-01.png` ... `email/email_collage-05.png`
- JPG collage variants (older set): `email/email_collage.jpg` plus `email/email_collage-01.jpg` ... `email/email_collage-05.jpg`

## Suggested subjects

- Monthly: `Your 1-month Premium code for nexios player (iOS)`
- Lifetime: `Your Lifetime access code for nexios player (iOS)`

## Placeholders to replace

- `{{RECIPIENT_NAME}}` (example: `Sam`)
- `{{PROMO_CODE}}` (example: `ABCD1234EFGH`)
- Optional: `{{EXPIRES_ON}}` (example: `(expires March 1, 2026)` or leave blank)

Sender/signature name in the templates is: `Team Nexios`

## Sending via Zoho Mail (HTML version)

1. Open Zoho Mail -> **New Mail / Compose**.
2. Add **To**, **Subject**, and set **From name** to `Team Nexios`.
3. In the composer, open the **HTML / Source** option (commonly shown as `</>` or **Insert HTML** in the formatting toolbar/menu).
4. Paste the contents of the `.html` template.
5. Replace placeholders (`{{...}}`) with real values (especially the promo code).
6. Send yourself a test email first, then send to the recipient.

Tip: If every recipient gets a different code, send **one email per person** (don't use a bulk To/BCC list unless the code is shared).

## Optional: Use the collage instead

The HTML templates currently show the tvOS screenshot: `https://nexios-player.github.io/AppImages/tvOS/0.png`

If you'd rather show the collage, change the image URL in the HTML template to:
`https://nexios-player.github.io/email/email_collage.png`

Note: `AppImages/tvOS/0.png` is a large 4K screenshot and may load slowly in some mail clients.

If the image does not show in your email, first confirm the file loads in your browser:
`https://nexios-player.github.io/email/email_collage.png`
If it returns `404 Not Found`, the site hasn't been redeployed with the new file yet.

## Regenerating collages

Run (iPhone-only PNG collage set):
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-email-collages.ps1 -Format png -PhoneOnly`

Run (JPG set):
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/generate-email-collages.ps1 -Format jpg`
