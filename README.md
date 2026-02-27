# WoWFlipper

This is a wow addon that lets you analyze and visualize the potential earnings from flipping consumables or reagents on WoW auction.

The idea is simple: Scan the amount and price of a selected item, then evaluate the potential profit from buying N amount of such item and selling it again for the new lowest price.

For example, let's say there are following listings for Silverleaf:
1g - 2x
2g - 3x
4g - 1x

Then the price to pay for N items increses in the following way
1x - 1g
2x - 2g
3x - 4g
4x - 6g
5x - 8g
6x - 12g

with the earnings from reselling at the newly lowest price is
1x - 1g
2x - 4g
3x - 6g
4x - 8g
5x - 20g
6x - 24g

making the profits equal to
1x - 0g
2x - 2g
3x - 2g
4x - 2g
5x - 12g
6x - 12g

What this addon does is show you the profits as a function of number of pieces to flip in absolute (gold) and relative (ratio to investment needed). This lets you optimize the number of items to flip in order to maximize profits.

