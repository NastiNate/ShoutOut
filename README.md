<p align="center"><img src=".github/icon.png" width="96" alt="Shout Out icon"></p>

# Shout Out

Build clean, efficient Trade chat ads for your professions and class services. Check what you sell, set your prices, and post in one click. Shout Out packs everything into WoW's 255-character limit for you.

## Features

- **One-click ads:** check the crafts, portals or summons you offer and Shout Out writes the ad.
- **Clickable links:** crafted items post as real item links buyers can inspect, with your price after each one.
- **Always fits:** ads are packed to the 255-character limit automatically. Overflow can rotate into a second post.
- **Your words, your layout:** write the whole message yourself, using placeholders like `{prof}` and `{items}` that fill themselves in, or keep the ready-made example.
- **Prices made easy:** gold / silver / copper boxes, per-stack or each pricing, and one-click AH estimates from Auctionator or TradeSkillMaster.
- **Several ads:** separate ads for each profession or service, each with its own color.
- **Quick-post bar:** a small movable bar to post, switch ads and see your timer.
- **Reminders:** optional timer, sound and flashing outline when it's time to post again.
- **Auto-invite:** whispers of "inv" or "invite" get a group invite (optional).
- **Customer radar:** spots people asking for what you sell in chat ("LF enchanter", "LF ench Fiery") and pops up a card to invite or whisper them. Optionally auto-invites exact requests.
- **Test before you post:** send the exact ad to a private channel only you can see.

## Supported ad types

- **Enchanting:** short enchant names, grouped by gear slot, with material costs.
- **Leatherworking, Blacksmithing, Tailoring, Engineering, Cooking:** item links with your prices.
- **Alchemy:** transmutes posted as a service, with elixirs and potions sorted by buff type.
- **Mage:** portals in one tidy phrase ("UC & TB 40s from ORG"), plus food and water.
- **Warlock:** summon spots with prices, with optional ALL CAPS and Repeat.
- **Custom:** anything sellable in your bags, with AH prices.

## Installing

- **CurseForge app:** search for Shout Out and click Install.
- **Manually:** download the latest zip from [Releases](https://github.com/NastiNate/ShoutOut/releases), unzip it, and put the `ShoutOut` folder in `World of Warcraft\_forever_\Interface\AddOns`. Restart the game.

## Getting started

1. Open your profession window once so Shout Out can learn your recipes.
2. Type `/shoutout` (or `/so`).
3. Check what you sell, set prices, pick your channel, and press Post.

Full instructions are on the **How it Works** page inside the addon.

## Commands

| Command | What it does |
|---|---|
| `/shoutout` or `/so` | Open or close the window |
| `/so post [ad]` | Post the current ad (or a named one) |
| `/so next` | Switch to the next ad |
| `/so test` | Send a test only you can see |
| `/so settings` | Open Settings |
| `/so how` | Open the How it Works page |
| `/so mini` | Show or hide the quick-post bar |
| `/so minimap` | Show or hide the minimap button |
| `/so reset` | Move windows back to the center |
| `/so resetlimit` | Go back to the full message length |

## Good to know

- WoW only allows chat posts from a click or key press, so Shout Out never posts on its own: you press Post, the quick bar, or a key binding (Options > Keybindings > AddOns > Shout Out).
- **Preview a profession** (Settings) lets you build and test ads for professions you don't have. Previewed ads can only be sent to yourself as a test, never posted.
- Optional: Auctionator or TradeSkillMaster for AH price estimates.
- Built for WoW Forever. English only.

## Bugs and ideas

Found a bug or have an idea? [Open an issue](https://github.com/NastiNate/ShoutOut/issues/new/choose): there's a short form for each. If you use BugSack, include the error text.

## License

The code is open source under the [MIT License](LICENSE.txt): you're welcome to use, change and share it, as long as you keep the copyright notice. The icon artwork isn't covered by the MIT License and stays all rights reserved (see [LICENSE.txt](LICENSE.txt)).
