# KOReader Custom Header Patch

A highly configurable header for KOReader that displays customizable information at the top of the screen while reading.

![Koreader Header](/img/koreader_header.png)

## Features

- **various display items** including time, battery, progress, chapter info, and more
- **Flexible space separator** - push items to left/right corners or distribute them across the bar
- **Customizable separator styles** - choose from different characters to separate header items
- **Item reordering** - easily arrange items using the built-in SortWidget
- **Tap to toggle** - tap the top of the screen to show/hide the bar
- **Multi-select items** - display multiple pieces of information simultaneously
- **Respects book margins** - automatically adjusts to your book's margin settings

## Credits

This patch is based on:
- [joshuacant's reader-header-cornered.lua](https://github.com/joshuacant/KOReader.patches/blob/main/2-reader-header-cornered.lua) - original header implementation
- [KOReader's ReaderFooter module](https://github.com/koreader/koreader/blob/master/frontend/apps/reader/modules/readerfooter.lua) - feature inspiration and implementation patterns

## Installation

1. Create a directory named `patches` under the koreader directory on your device
   - **Android**: This folder is located on the SD-card (e.g., `/sdcard/koreader/patches/`)
   - **Kindle/Kobo**: Usually in `/mnt/us/koreader/patches/` or `/mnt/onboard/.adds/koreader/patches/`
2. Download `2-reader-header.lua` and put it in the `patches` directory
3. Restart KOReader

The top bar should now appear when reading EPUB and other reflowable formats (not PDFs or CBZ files).

## Configuration

Access all settings through: **Settings (cog wheel) → Header**

## Gesture Controls

- **Tap top of screen** - Show/hide the top bar
- The touch zone covers approximately the top 10% of the screen

### ⚠️ Important: Touch Zone Conflict

**This patch creates a conflict with KOReader's default tap-to-open-menu gesture.** By default, KOReader opens the menu when you tap the top portion of the screen. This patch uses the same area to toggle the top bar. You must disable tap gestures for opening the menu and use swipe instead.

## Customization

You can modify the following settings in the code (lines ~147-155):

```lua
local header_font_face = "ffont"              -- Font face
local header_font_size = 14                   -- Font size
local header_font_bold = false                -- Bold text
local header_font_color = Blitbuffer.COLOR_BLACK  -- Text color
local header_top_padding = Size.padding.small -- Top padding
local header_use_book_margins = true          -- Use book margins
local header_margin = Size.padding.large      -- Manual margin (if not using book margins)
```
Separator style can be changed via the Header menu.
## Requirements

- KOReader v2024.04 or later (recommended)

## Known Limitations

- Only works with reflowable formats (not PDF, CBZ, or other fixed-layout formats)
- Overlays book content - ensure you have sufficient top margin configured
- Conflict with KOReader's default tap-to-open-menu gesture (see [Gesture Controls](#gesture-controls))
- Time left to finish book and Time left to finish chapter are disabled, as they cause koreader to crash - feel free to improve this if you know how

## License

This patch follows KOReader's license (AGPL-3.0).

## Contributing

Feel free to modify and improve this patch.