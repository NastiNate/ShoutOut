# Shout Out changelog

## 1.1.0 (November 2026)

- **Customer radar** (Enchanting): when someone in Trade, Services, General, /say or /yell asks for an enchanter or an enchant you know ("LF enchanter", "LF ench Fiery", a linked recipe), a small card pops up with their name in class color and Invite, Whisper and Ignore. It never invites on its own, so you can read the message first. Capitals don't matter. Settings > Customers.
- The radar skips sellers ("WTS", "LFW", "on AH", "for sale") and only treats "anyone"/"any" as a request right before a profession word ("any enchanters around?"), so ads like "if anyone wants a pair… stacks with Fiery Enchant" don't pop up. Its sound is a soft map ping, not the whisper sound.
- The radar card's **Whisper** button links your [Enchanting]: put {prof} in the radar whisper (it's in the default) and it becomes your clickable profession link, captured when you open your Enchanting window.
- **Turn a full party into a raid** (on by default): when your party has 5 and another customer gets invited, Shout Out makes it a raid first and keeps inviting, up to 40. Settings > Customers.
- The radar also skips other enchanters advertising ("Enchanter LF work", "available", "tips appreciated", a linked [Enchanting] window), and words inside someone's item link ("WTB [Fiery War Axe]") no longer count.
- Invites check first: if your raid is full or you're not the leader, nothing is sent, the card's button says "Group full" or "Not leader", and the "inv" whisper auto-invite tells you why instead of claiming it invited.
- The minimap button's click guide moved into its tooltip in Settings, to make room.

## 1.0.3 (November 2026)

- The silver and copper price boxes are back to their full width, so both digits show while you type.

## 1.0.2 (November 2026)

- Link-heavy ads (crafted items) are no longer held back by an old 448-character link-code limit: WoW Forever accepts much more. If WoW ever refuses a post as too long, Shout Out trims it, posts the shorter ad in the same click, and remembers the limit.
- The "with link code" count under the preview only shows when it's the limit that matters.

## 1.0.1 (November 2026)

- The gold price box now fits 4 digits, so prices up to 9,999g show in full.
- The code is now open source under the MIT License (the icon artwork stays all rights reserved).

## 1.0.0 (November 2026)

First public release.

- Trade chat ads for Enchanting, Leatherworking, Alchemy, Blacksmithing, Tailoring, Engineering and Cooking, plus Mage (portals, food and water), Warlock (summons) and Custom (bag items) ads.
- Write your own message with `{prof}`, `{items}`, `{enchants}`, `{portals}` and `{places}` placeholders, or use each ad type's example message.
- Clickable item, recipe and profession links, with gold / silver / copper prices and stack / each pricing.
- Messages packed to WoW's 255-character limit, with optional Rotate overflow into a second post. If WoW refuses a post as too long, Shout Out trims and retries automatically.
- AH estimates and material costs from Auctionator or TradeSkillMaster.
- Several ads with their own colors, a quick-post bar, a minimap button, reminders and auto-invite.
- Send test to me: see the exact ad in your chat, visible only to you.
- Preview a profession to build ads for professions you don't have (test messages only).
- How it Works guide inside the addon.
