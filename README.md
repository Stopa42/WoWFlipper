# WoWFlipper

WoWFlipper is a World of Warcraft addon that analyzes Auction House commodity listings and
shows the potential earnings from buying out the first `N` units and relisting them at the
new market floor.

## What it does

For a selected commodity, WoWFlipper:
1. Reads the current commodity listings from the AH.
2. Computes the cumulative buyout cost for each quantity `N`.
3. Computes the relist revenue at the new lowest unit price after your buyout.
4. Shows profit (absolute gold) and ROI (relative gain) for each `N`.
5. Highlights best opportunities by absolute profit and by ROI.

## Example

Given listings:
- `1g` × `2`
- `2g` × `3`
- `4g` × `1`

WoWFlipper computes:
- cost curve: `1x=1g`, `2x=2g`, `3x=4g`, `4x=6g`, `5x=8g`, `6x=12g`
- relist revenues: `1x=1g`, `2x=4g`, `3x=6g`, `4x=8g`, `5x=20g`, `6x=24g`
- profits: `0g`, `2g`, `2g`, `2g`, `12g`, `12g`

## Installation

1. Copy this repository folder to your AddOns folder as `WoWFlipper`:
   - `_retail_/Interface/AddOns/WoWFlipper`
2. Ensure these files are present inside it:
   - `WoWFlipper.toc`
   - `WoWFlipper.lua`
3. Restart WoW or run `/reload`.

## Usage

1. Open the Auction House.
2. Use either:
   - Slash command: `/wowflipper <itemID or itemLink>`
   - Addon panel to the right of the AH window:
     - enter item ID/link and click **Scan**, or
     - select an item in the AH UI and click **Use Selected** to auto-fill the item ID.
3. Read results in:
   - Chat output table.
   - WoWFlipper panel output.

## Notes

- Works with **commodity** searches (stackable materials, reagents, consumables, etc.).
- Uses the in-game Auction House API and requires AH to be open while scanning.
