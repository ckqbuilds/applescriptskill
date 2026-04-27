-- Draft a new email with a styled HTML body. Opens the compose window for review — does NOT send.
-- Usage: osascript draft-html.applescript "/abs/path/to/body.html" "recipient@example.com" "Subject line"
--
-- How it works:
--   1. Reads the HTML file as text.
--   2. Creates a new outgoing message with that text on the `html content`
--      property. Mail renders it as styled HTML in the compose window.
--
-- Note on the AppleScript dictionary:
--   `sdef /System/Applications/Mail.app` marks `html content` as
--   `hidden="yes" description="Does nothing at all (deprecated)"`. This is
--   wrong / stale on modern macOS — verified live on Darwin 25.5: the property
--   does render HTML in outgoing messages. Trust the live behavior, not the
--   dictionary, for this property.
--
-- Caveats discovered while testing complex templates:
--   * Mail's compose window strips body-level / outer-table backgrounds, so a
--     dark-themed email may show a white canvas in the compose preview. iOS
--     Mail and most web clients render correctly. Test on a phone before
--     declaring failure based on the desktop compose view.
--   * To get backgrounds that survive: set bgcolor + background-color on
--     every section-wrapper <td>, not just <body> or the outer table.
--   * Custom display fonts don't load. Georgia + Helvetica Neue are safe
--     approximations for serif/display + sans pairings.
--   * Inline base64 images are typically stripped — use hosted image URLs.
--
-- No Accessibility permission required (no UI scripting).

on run argv
    if (count of argv) < 3 then
        error "Usage: draft-html.applescript <html-path> <to-address> <subject>"
    end if
    set htmlPath to item 1 of argv
    set toAddr to item 2 of argv
    set msgSubject to item 3 of argv

    set htmlContent to read POSIX file htmlPath as «class utf8»

    tell application "Mail"
        activate
        set newMsg to make new outgoing message with properties {subject:msgSubject, html content:htmlContent, visible:true}
        tell newMsg
            make new to recipient at end of to recipients with properties {address:toAddr}
        end tell
    end tell

    return "HTML draft created: " & msgSubject
end run
