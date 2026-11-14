# Experimental Xenoverse profile

This profile targets Xenoverse 1.5.5, whose published script source is revision
3356658c25c6fd5f64b26948670e5d2ef6e13100. It uses the gen6 engine model.
Other game versions and the complete story have not been verified.

Use a legally obtained game with its native snGame_n.exe player. Keep the
original executables and resources. Game.exe can be a CLR launcher which starts
another player; selecting that wrapper does not establish that Access is loaded.
The catalog detects snGame_n.exe and applies the profile's compatibility preload.
The preload registers bundled fonts privately for the current process and
neutralizes the old system font installer's restart, without changing game
scripts, saves or system font registrations. Registration failures are logged.

For an untouched first run, the language chooser can appear before Access's
normal core bootstrap. The shared first-run language fix is offered separately
in [PR 27](https://github.com/tiflojuegos-com/PokeEssentialsAccess/pull/27).
Without that fix, this profile alone does not make that early prompt speak.

The readers cover the actual language/title, gender, Classic/Modern mode,
starter, sprite-based pause menu, Bag, shop grid, battle commands/Bag, caught
Pokemon, Party commands, Summary, controls and badges. They announce the game's
current translated text and cursor rather than making hidden stock windows
visible. Map/NPC names follow the game's translation API; verified healing
centers are recognized from their original nurse events. No event Ruby is
evaluated to invent a label.

The game's Bag paints Q/W for left/right, Z for confirm and X for cancel; the
profile preserves those actual key hints. Field-move rules intentionally remain
unnamed until the PokeWES rules are verified. Generic obstacle descriptions are
not proof that a field action can be performed.

Earlier keyboard/NVDA trials of the combined integration reached the first
earned badge, ordinary battles, item use and purchases, Party/Summary/Box,
healing centers, named NPCs and normal saving/reloading. These are bounded
trials, not a claim of full-game accessibility. PokeWES, the second controls
screen, full-party/full-box catches, later story/puzzles and another physical
computer remain unverified. This profile does not enable wall crossing, change
collision or force story flags.

Regression fixtures for the older summary/party classes run in isolated gen6
processes. Complete-profile loading is checked independently with both engine
models. Font compatibility is exercised through modern Ruby and Ruby 1.8.7
when the latter is available. The added static survey uses 257 original script
inputs and retains the previous 35-source evidence. No game scripts, assets or
saves are distributed with the profile.
