# HTML Email Drafts

Draft an email with a styled HTML body in macOS Mail. Useful for newsletter-style
updates, reports, formatted summaries, branded announcements, or anything that
benefits from headings, tables, lists, and color.

## TL;DR

Use Mail's `html content` AppleScript property. Set it on the message at
creation time and Mail renders the HTML in the compose window:

```applescript
set htmlContent to read POSIX file "/path/to/body.html" as «class utf8»
tell application "Mail"
    activate
    set newMsg to make new outgoing message with properties {subject:"Weekly update", html content:htmlContent, visible:true}
    tell newMsg
        make new to recipient at end of to recipients with properties {address:"team@example.com"}
    end tell
end tell
```

The compose window stays open for review. Nothing is sent until the user
clicks Send.

## About the AppleScript dictionary

`sdef /System/Applications/Mail.app` marks `html content` as
`hidden="yes" description="Does nothing at all (deprecated)"`. **This is wrong /
stale.** Verified live on Darwin 25.5: the property renders HTML in outgoing
messages. Trust live behavior over the dictionary description for this property.

The `content` property is for plain text. Setting HTML there results in the
literal HTML source being shown in the body.

## Why this is separate from PDF generation

The skill has two distinct ways to deliver agent-authored HTML:

| Output    | Renderer                     | When to use                                   |
|-----------|------------------------------|-----------------------------------------------|
| PDF file  | Swift + WebKit (compiled `html2pdf`) | User wants a document to save, share, or print. Multi-page, paginated. |
| Email draft | Mail's `html content` property      | User wants to send styled content. Single-flow rich text, no pagination. |

Both start with **agent-generated HTML**. The HTML authoring patterns
(typography, callout boxes, tables, brand colors) in
[`pdf-generation.md`](pdf-generation.md) apply to email too — but **drop the
`.page` div wrapper and fixed 612x792 dimensions**. Email clients flow content;
they don't paginate.

## Ready-made script

```bash
osascript scripts/mail/draft-html.applescript /tmp/body.html recipient@example.com "Subject line"
```

See [`scripts/mail/draft-html.applescript`](../scripts/mail/draft-html.applescript)
for the implementation. Three positional args: HTML file path, recipient
address, subject line.

## Inline pattern

For one-shot use where you've generated the HTML in the agent's context and
want to write+draft in one block:

```bash
cat > /tmp/email-body.html <<'HTML'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"></head>
<body style="font-family: -apple-system, Helvetica Neue, sans-serif; color: #1a1a1a; max-width: 600px;">
    <h2 style="color: #1a2650;">Weekly update</h2>
    <p>Hi team,</p>
    <p>Here is this week's progress:</p>
    <ul>
        <li>Shipped the new export pipeline</li>
        <li>Closed 12 bugs in the dashboard</li>
        <li>Onboarded two new contractors</li>
    </ul>
    <p style="margin-top: 16px;">Best,<br>Chris</p>
</body></html>
HTML

osascript <<'APPLESCRIPT'
set htmlContent to read POSIX file "/tmp/email-body.html" as «class utf8»
tell application "Mail"
    activate
    set newMsg to make new outgoing message with properties {subject:"Weekly update", html content:htmlContent, visible:true}
    tell newMsg
        make new to recipient at end of to recipients with properties {address:"team@example.com"}
    end tell
end tell
APPLESCRIPT
```

## HTML authoring rules for email

Email clients (including Apple Mail's renderer) are stricter than browsers. The
following rules came out of live testing complex templates against macOS Mail:

- **Inline styles win.** External or `<style>`-block CSS often gets stripped or
  inconsistently applied. Inline critical styles directly on elements
  (`<p style="font-size: 14px; color: #333;">`).
- **No `.page` div.** That's a PDF concept. Use a single body container with a
  `max-width` (~600px) for readability.
- **Backgrounds on `<body>` and the outermost `<table>` get stripped by Mail's
  compose view.** If you want a dark-themed email (e.g. solid black canvas
  with light cards), put `bgcolor="#000000"` *and* `style="background-color:#000000"`
  on **every section-wrapper `<td>`** — the rows that contain side padding
  around inner cards. The desktop compose preview will still often show a
  white canvas; iOS Mail and most web clients render correctly. Test on a
  phone before declaring failure.
- **Use HTML entities for special characters** — `&#8212;` for em dash,
  `&#8226;` for bullet, `&amp;` for ampersand, `&#9650;` for triangle. See
  the encoding table in [`pdf-generation.md`](pdf-generation.md).
- **Tables work, even nested ones for layout.** This is the canonical email
  layout primitive and Mail handles it well. Avoid `position: absolute`,
  `flex`, or `grid` — older Mail render paths can mangle them.
- **Custom display fonts don't load.** Mail uses system fonts only. Georgia
  (serif/display) and Helvetica Neue (sans) are safe approximations.
- **Gradients via `linear-gradient()` work in Mail** but Gmail/Outlook may
  fall back to a flat color. If broad client compatibility matters, use a
  solid background.
- **Inline base64 images are typically stripped.** Use hosted image URLs
  (`<img src="https://...">`). For privacy-conscious mail clients, the user
  may need to approve remote image loads.

## Permissions

This script does not need Accessibility permission. Mail itself does not need
automation permission for this flow on modern macOS, but the first run may
surface a one-time prompt.

## When to use plain text instead

If the user just wants a quick email with no formatting, use the existing
[`scripts/mail/draft-new.applescript`](../scripts/mail/draft-new.applescript)
or the plain-text patterns in [`mail.md`](mail.md). Don't reach for the HTML
path unless styling matters.
