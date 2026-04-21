# PDF Generation

Generate native multi-page PDFs using HTML/CSS and a compiled Swift converter.
No external packages required — uses WebKit and Core Graphics built into macOS.

## Prerequisites

- `swiftc` (ships with Xcode or Command Line Tools)
- One-time compile of `scripts/system/html2pdf.swift`

## Setup

Compile the converter once. The binary can be reused for all future PDFs:

```bash
swiftc scripts/system/html2pdf.swift -o scripts/system/html2pdf -framework WebKit -framework AppKit
```

## Usage

```bash
scripts/system/html2pdf input.html output.pdf
```

## How It Works

1. Agent generates an HTML file with CSS styling
2. The compiled `html2pdf` binary loads the HTML into a headless WebKit view
3. It counts page divs, resizes the view to fit all pages, takes a snapshot of each page, and composites them into a multi-page PDF

## HTML Template Structure

Each page is a `<div>` with class `page` or `page-flex`, fixed to US Letter dimensions (612x792px). The converter detects these divs and renders each one as a separate PDF page.

### Minimal page template

```html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, Helvetica Neue, sans-serif;
        color: #1a1a1a;
        width: 612px;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
    }
    .page {
        width: 612px;
        height: 792px;
        overflow: hidden;
        padding: 50px 50px 30px 50px;
        display: flex;
        flex-direction: column;
    }
    .content {
        flex: 1;
        max-height: 672px;
        overflow: hidden;
    }
    .page-num {
        font-size: 9px;
        color: #999;
        text-align: center;
        padding-top: 12px;
        flex-shrink: 0;
    }
</style>
</head>
<body>

<div class="page">
    <div class="content">
        <!-- Page content here -->
    </div>
    <div class="page-num">Page 1 of 1</div>
</div>

</body>
</html>
```

### Page dimensions

| Element | Height | Notes |
|---------|--------|-------|
| Full page | 792px | US Letter at 72 DPI |
| Top padding | 50px | |
| Bottom padding | 30px | |
| Page number area | 20px | Includes 12px top padding |
| **Usable content** | **672px** | Max height for body content per page |
| Content width | 512px | 612px - 50px left - 50px right padding |

### Content rules

- Each `<div class="page">` becomes one PDF page
- Content that exceeds `max-height: 672px` is clipped by `overflow: hidden`
- The agent must distribute content across pages so nothing gets cut off
- Place natural break points between sections, not mid-paragraph or mid-table

## Branded Template (Headers, Footers, Colors)

For professional documents with repeating branding. Ask the user for their preferred colors
or use their brand colors if known. All color values below are CSS variables that the agent
should replace based on user preference.

### Color configuration

When generating a branded PDF, define colors as CSS variables at the top of the stylesheet.
Ask the user what colors they want, or infer from their brand if known:

```css
:root {
    --brand-primary: #1a2650;      /* Header/footer background, headings, accents */
    --brand-primary-light: #d0d4e0; /* Subtle text on dark backgrounds */
    --brand-accent: #1a2650;        /* Callout borders, stat numbers */
    --text-primary: #1a1a1a;        /* Body text */
    --text-secondary: #666;         /* Subtitles, labels */
    --text-muted: #999;             /* Page numbers */
    --table-header-bg: #ecedf1;     /* Table header background */
    --table-stripe-bg: #f7f7fb;     /* Alternating table row */
    --callout-bg: #f0f2f8;          /* Highlight box background */
}
```

Then reference them throughout the styles:

```css
.page-header { background: var(--brand-primary); }
.page-footer { background: var(--brand-primary); }
.cover-header { background: var(--brand-primary); }
h2 { color: var(--brand-primary); }
.highlight-box { background: var(--callout-bg); border-left: 3px solid var(--brand-accent); }
.stat .number { color: var(--brand-accent); }
th { background: var(--table-header-bg); }
tr:nth-child(even) { background: var(--table-stripe-bg); }
```

### Common brand color presets

| Style | Primary | Accent | Callout BG | Notes |
|-------|---------|--------|------------|-------|
| Navy (default) | `#1a2650` | `#1a2650` | `#f0f2f8` | Professional, corporate |
| Slate | `#334155` | `#0f172a` | `#f1f5f9` | Modern, neutral |
| Forest | `#14532d` | `#166534` | `#f0fdf4` | Eco, natural |
| Burgundy | `#5b1a2a` | `#7f1d2e` | `#fdf2f4` | Luxury, classic |
| Ocean | `#0c4a6e` | `#0369a1` | `#f0f9ff` | Tech, clean |
| Charcoal | `#1c1917` | `#292524` | `#f5f5f4` | Minimal, elegant |
| Custom | User-provided | User-provided | Derive from primary at 95% lightness | Ask the user |

To derive a callout background from a custom primary color, use the primary hue at
5% saturation and 95% lightness. The agent should ask the user for their preferred
colors if not already known.

### Branded page structure

Headers and footers go inside each page div, outside the content div:

```html
<div class="page">
    <div class="page-header">
        <span class="brand">Company Name</span>
        <span class="doc-title">Document Title</span>
    </div>
    <div class="content">
        <!-- Page content here -->
    </div>
    <div class="page-footer">
        Company Name &#8226; Confidential &#8226; Page 1 of 2
    </div>
</div>
```

### Branded styles

```css
.page-header {
    background: var(--brand-primary);
    padding: 10px 50px;
    color: white;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-shrink: 0;
}
.page-header .brand { font-size: 12px; font-weight: 700; }
.page-header .doc-title { font-size: 9px; color: var(--brand-primary-light); }

.page-footer {
    background: var(--brand-primary);
    color: white;
    padding: 8px 50px;
    font-size: 8px;
    text-align: center;
    flex-shrink: 0;
    margin-top: auto;
}
```

When using headers and footers, reduce `max-height` on `.content` to account for
their height (~35px header + ~25px footer = ~60px less content space per page).

### Cover page with large header

Use a taller branded header on the first page only:

```css
.cover-header {
    background: var(--brand-primary);
    padding: 35px 50px;
    color: white;
    flex-shrink: 0;
}
.cover-header h1 { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
.cover-header p { font-size: 11px; color: var(--brand-primary-light); }
```

## Typography Reference

Recommended styles for clean, readable PDF output:

```css
h1 { font-size: 20px; margin-bottom: 12px; }
h2 { font-size: 16px; color: var(--brand-primary, #1a1a1a); margin: 16px 0 8px 0; }
p { font-size: 11px; line-height: 1.6; margin-bottom: 10px; }
ul, ol { font-size: 11px; line-height: 1.7; margin: 8px 0 8px 24px; }
table { width: 100%; border-collapse: collapse; font-size: 10px; margin: 10px 0; }
th { background: var(--table-header-bg, #ecedf1); text-align: left; padding: 6px 8px; font-weight: 600; }
td { padding: 5px 8px; border-bottom: 1px solid #eee; }
tr:nth-child(even) { background: var(--table-stripe-bg, #f7f7fb); }
code { background: #ecedf1; padding: 1px 4px; border-radius: 3px; font-size: 9.5px; }
```

## Callout Boxes

```css
.highlight-box {
    background: var(--callout-bg, #f0f2f8);
    border-left: 3px solid var(--brand-accent, #1a2650);
    padding: 8px 12px;
    margin: 10px 0;
    font-size: 10.5px;
    line-height: 1.5;
}
```

```html
<div class="highlight-box">
    <strong>Key point:</strong> Important information here.
</div>
```

## Stat Boxes

```css
.stat-row { display: flex; justify-content: space-between; margin: 12px 0; }
.stat { text-align: center; flex: 1; }
.stat .number { font-size: 26px; font-weight: 700; color: var(--brand-accent, #1a2650); }
.stat .label { font-size: 9px; color: #666; margin-top: 2px; }
```

```html
<div class="stat-row">
    <div class="stat"><div class="number">42</div><div class="label">Items</div></div>
    <div class="stat"><div class="number">99%</div><div class="label">Uptime</div></div>
</div>
```

## Encoding

Always include `<meta charset="UTF-8">` in the HTML head. Use HTML entities for special characters:

| Character | Entity |
|-----------|--------|
| Em dash (—) | `&#8212;` |
| Bullet (•) | `&#8226;` |
| Ampersand (&) | `&amp;` |
| Less than (<) | `&lt;` |
| Right single quote (') | `&#8217;` |

Do **not** use raw Unicode characters like `—` in the HTML — they can get mangled during file writes. Always use numeric entities.
