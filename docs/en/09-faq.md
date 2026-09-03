# Frequently asked questions

Short answers to what comes up first, linking to the long document when more is needed. If you are **adding**
something (a profile, a reader, a plugin), read [05-extending](05-extending.md) as well — it has the full
steps. This is the map for deciding which one to open.

## Games and profiles

### What is a "profile", and when does one become necessary?

Code specific to ONE fangame, in `games/<profile>/`, loaded after the core. You need one when the game has
screens no other game has: a minigame, an odd shop, a rewritten menu.

What does **not** justify a profile: the game shipping a third-party plugin. That goes to `plugins/`, because
the same plugin turns up in several games.

### How do I add a new profile?

1. `games/<name>/manifest.rb` with `{ :modules => %w[...], :plugins => %w[...] }`.
2. One `.rb` per module, listed in that manifest. Anything not listed is not loaded, and nothing warns you.
3. An entry in `games/catalog.json` with its `detect` (a regex against the game folder's name).
   **Careful**: `generic` must stay LAST, because it is the catch-all; move it up and it swallows the rest.
4. Any new spoken text, in all six `lang/` files. A test fails if a key is missing from any of them.

Detail: profiles may carry bare Spanish literals, because the fangames covered are Spanish-only. The core
may not.

### What is the `generic` profile?

The fallback for games with no profile of their own. It does not know which game it is running in, so instead
of naming plugins it carries `:plugins => :auto` and **asks the game** which ones it has, through the
detection table.

### A screen in my game does not read. Where do I start?

With the diagnostic, not with the code. **Ctrl+Alt+F9** dumps `accessibility/data/diag.txt`; **Ctrl+Alt+F10**
speaks it. Read it in this order:

1. The `mod:` line — is the installed version the one you think? A stale install is cause number one.
2. `engine:` — `kind`, `version`, `fork` and `caps`. It says which era and which capabilities it sees.
3. `plugins:` — loaded and undeclared. **Undeclared is gold**: the game ships a plugin we know about and its
   profile never declared it. That is your silent screen.
4. `plugins_juego:` — the game's own registry through `PluginManager`. It also lists plugins we do not know
   about, which is exactly the set a screen with no reader usually belongs to.
5. `scene=` — the active scene's class. With that name you can search the game's scripts.

The dump is described in full in [07-diagnostics](07-diagnostics.md).

### How do I look at my game's scripts?

```bash
ruby tools/dump_scripts.rb "C:\path\to\the game"
```

It writes `Scripts_dump/` inside the game folder. It handles all three ways a game stores its code —
`Data/Scripts.rxdata`, a loose tree of files, or everything packed into `Game.rgssad` — and needs no gems.
That folder is what the rest of the documentation means when it says "look in the game's scripts".

## Hooks

### How do I hook a screen?

Through the semi-API in `core/input/hooks.rb`, never by patching the class by hand:

```ruby
PokeAccess::Hooks.after_hook("TheClassName", :the_method) do |scene, _ret, args|
  # read and speak
end
```

Pass the class name **as a String**: if that class does not exist in that game the hook simply does not bind,
instead of breaking the load.

The variants are `before_hook`, `around_hook`, `override` (replaces), `read_on_open` and `frame_hook` (once
per frame). Which to use and why, in [03-hooks](03-hooks.md).

### When do I add `:optional => true`?

When the method may be **deliberately absent** in some games. Without `:optional`, that absence is recorded
in `Hooks.missing`, which by contract is the list of **typos**: filling it with expected absences is how a
real typo stops being noticed.

In `plugins/` it is mandatory on every hook, and a test checks it.

### The screen is read twice. Why?

Because the generic command-window reader sees it too. Claim the window:

```ruby
PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
```

Mind the trap behind this: the generic reader gates on `active`, not on `visible`, and several command
windows are born active even while hidden. Not being able to see one does not mean it is not already being
read.

And do **not** use the engine's `@ignore_input` to mute us: some Selectable windows use it for their own
navigation, and you would freeze the player's cursor.

### The hook binds but nothing is heard. What happened?

The most expensive failure in this project, and it raises nothing: the class exists, the method exists, the
hook binds perfectly, and the ivar you read is named differently in that game. You read `nil` forever, with
no exception and no trace.

Real cases: `totalpp` against `total_pp`; the sprite `"fightwindow"` against `"fightWindow"`; `power`
against `base_damage`. That is what `PokeAccess.attr_of(obj, :name_a, :name_b)` is for — it asks for both.

**Rule: a bound hook does not prove the data is where you think.** Verify it against the game's scripts.

### The hook is right but it only speaks when the screen closes

You hooked the loop. In Essentials it is normal for a method called `main`, `pbUpdate`, or even `initialize`
itself, to **be** the screen's blocking loop: an `after` on it does not fire until the player leaves. Hook it
with `around` to hold the scene, and read from the per-frame poll.

## Third-party plugins

### Does this go in `core/`, `plugins/` or `games/`?

- **`core/`** — what any Essentials game has. Vanilla.
- **`plugins/`** — a third-party plugin some games install.
- **`games/<profile>/`** — code belonging to ONE fangame.

To decide whether something is a plugin: if the class is in some upstream Essentials tag, it is vanilla. If
not, see whether the game keeps it in a plugins folder (`_PluginScripts/`, or a numbered addons folder). Many
games do not separate plugins into a folder — they paste them into the script list — so there you have to
look by hand.

Two traps: a plugin that **reopens** a vanilla class looks like it defines it, and the Sky fork puts things
that look like plugins inside its engine.

### How do I add a plugin reader?

1. `plugins/<plugin-name>.rb`, with every hook `:optional`.
2. One line in `plugins/manifest.rb`: `:<name> => "TellTaleClass"`, or `"Class#method"` if the plugin brings
   no class of its own and reopens one of the engine's. If the class lives inside a module, write it
   **qualified** (`"Module::Class"`): the census indexes it by its last segment either way, but the runtime
   gate cannot resolve the bare name.
3. `:plugins => %w[... <name>]` in every profile that ships it.
4. Regenerate the censuses: `ruby test/static/build_fangame_census.rb` and
   `ruby test/static/build_reader_census.rb`. The second is the one that asks the dumps whether the ivars
   you read exist in that game and whether the method you hook is the screen's loop; without regenerating
   it, the check fails saying exactly that.
5. A spec that pins **the divergence** between the two copies, not the obvious part.

### Why is the file named after the plugin and not after the screen?

So two different plugins can never collide. One plugin = one file = one table entry, and that way the table
answers the right question: *which plugins does this game have*, not *which screens do we cover*.

That is where the split comes from: **the core keeps the text builder and `plugins/` keeps only the hooks**.
What to say is shared; when to say it belongs to the plugin. Two readers of the same screen share the text
without copying it.

### What if two plugins use the same class?

Today it cannot happen: a test fails if two entries share a probe, or if two files in `plugins/` claim the
same (class, method) pair. The day two plugins genuinely need it, that test catches it, and the answer is for
each reader to **identify itself** — check something only its copy has — before speaking.

### I forgot to declare a plugin in a profile. Does it show?

Yes, two ways. In the game, the diagnostic lists it as undeclared. And in the repo a test cross-checks every
declaration against `test/static/plugin_census.txt`, which records which game ships which plugin: it fails in
both directions, missing and spurious.

## Engines

### How many Essentials versions do I have to keep in mind?

Two real divisions: **gen-6** (v16-17, Ruby 1.8.7, no `GameData`) and **modern** (v19+, with `GameData` and
`$player`). But there is a middle band that misleads: some games are **hybrids**, with gen-6 class NAMES
(`PokeBattle_Scene`, `CommandMenuDisplay`) and modern internals. That is where most divergences appear. See
[02-engines](02-engines.md).

### How do I gate by version?

Do not. Gate by **capability**:

```ruby
PokeAccess::Engine.has?(:ui_rework)          # a registered capability
PokeAccess::Engine.has?("Battle::Scene")     # a class
PokeAccess::Engine.has?("Battle#pbSideSize") # a method on a class
```

A version number lies the moment a fork backports something. The `v21/`, `v22/` folders say **where a
capability appeared**, not when to switch it on.

### Why can I not use modern Ruby syntax in `core/`?

Because the mod runs under **Ruby 1.8.7** inside mkxp-z, even though the tests use the system Ruby. No `->`,
no `Array#first(n)` (an Essentials 16.3 bug: use `[0, n]`). A static check catches it.

## Tests

### How do I run the tests?

```bash
ruby test/run_all.rb
```

It runs the specs on both engines plus the static checks (manifest, i18n parity, Ruby 1.8.7). To filter, pass
a path fragment: `ruby test/run_all.rb behavior/battle`.

### How do I know my test is worth anything?

Break it on purpose. Change the implementation to reintroduce the bug and check that the test **fails**. A
test that passes with and without the fix proves nothing, and this project has had several: one asserted
`t.index("1") && t.index("2")`, which the string "01234" satisfies just as well.

A worse and more common case: the fixture describes a shape the game does not have. Then the test passes, it
protects a wrong reading, and it **fails the day you fix it**. If correcting a reader breaks a spec, check the
fixture against the dump before assuming the spec was right.

### Installing into the games

At the end of the work, never halfway through:

```bash
powershell -File installer/install.ps1 -Force
```

Reinstalling on top is an update: it keeps `settings.ini` and the tags.
