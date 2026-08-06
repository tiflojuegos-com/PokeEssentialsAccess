# Hooks

Hooking means registering your own code around a method that already exists, without touching the game's
scripts. The whole system lives in `core/input/hooks.rb` and is 1.8.7-safe. Several hooks may wrap the same
method: each registers a middleware and they chain like an onion around the original, so a new feature can
never silently disable an existing hook.

## Why hooks bind by name

`cname` is always a **string** (`"Battle::Scene"`), never the constant. `wrap` resolves it through
`PokeAccess.const_at`, which walks the segments one by one because 1.8.7's `const_defined?` rejects a name
containing `::`. Naming the constant would blow up loading on any game that does not define it, and no class
exists across all 14 profiles at once: `PokemonMenu_Scene` is gen-6, `UI::BaseScreen` is v22.

| Situation | Result |
|---|---|
| Class absent | Silent no-op: normal cross-game variance |
| Method absent on a present class | Recorded in `Hooks.missing`, unless `:optional` |
| Private method | Hooked anyway: `wrap` detects it and re-privatises it after redefining |
| Method already hooked | Only the middleware is added; the original's alias is created once |

`override` is the exception to the first row: a target that does not resolve **does** count in
`Hooks.missing`, because a declared replacement always names something that ought to exist.

## The registrars

| Registrar | Signature | The block receives | When |
|---|---|---|---|
| `before_hook` | `(cname, meth, opts)` | `(instance, args)` | Speak before the original blocks |
| `after_hook` | `(cname, meth, opts)` | `(instance, result, args)` | Read the already-updated state |
| `around_hook` | `(cname, meth, opts)` | `(instance, call_next, args)` | Decide whether the original runs, or mark entry and exit of a loop |
| `frame_hook` | `(cname, meth)` | `(instance, args)` | Per-frame poller. Takes no `opts` |
| `read_on_open` | `(cname, meth = :pbStartScene, opts)` | `(scene)`, returns the text | Spoken summary when a screen opens |
| `override` | `(target, meth, opts)` | `(receiver, original, args)` | Declared replacement of a method |
| `wrap_global` | `(name, tag, timing = :after)` | `(args, result)` or `(args, call_next)` | Top-level function on `Object` |
| `wrap_kernel` | `(name, tag, timing = :before)` | same as `wrap_global` | Function that may be a `Kernel` singleton or top-level |
| `wrap` | `(cname, meth, opts)` | `(instance, call_next, args)` | The engine: raw middleware. Everything else uses it |

`call_next` takes no arguments: it replays the chain with the caller's own. To change what the original
receives, mutate the `args` array **in place** before calling it. The first registration sits in the outermost
layer, so with A and B in that order the `before_hook` bodies run A, B and the `after_hook` bodies run B, A.

`read_on_open` speaks **queued** (`PokeAccess.speak(text, false)`): an opening read must never cut the
transition click or a line already in progress. The text goes through `PokeAccess.clean`; `nil` or empty stays
silent. `games/opalo/trainer_card.rb` is the `:timing => :before` case: its opener blocks in its own loop, so
an after-hook would only speak on close.

`override` replaces a method while declaring the intent, as opposed to a silent module reopen. `target` is
either a mod module (its singleton method) or the string name of a game class (its instance method, via
`around_hook`). The body receives `original` as a lambda: call it to wrap instead of substitute. Every
installation is recorded in `Hooks.overrides` and printed by the diagnostic.

```ruby
# games/reminiscencia/move_relearner.rb -- arrows speak the name only; the info key gives the full detail
override(PokeAccess::MoveRelearnerGen6, :detail) do |_mod, _original, args|
  name = (PokeAccess::Data.move_name(PokeAccess::MoveRelearnerGen6.focused_id(args[0])) rescue nil)
  PokeAccess.speak(name.to_s, true) if name && !name.to_s.empty?
end
```

Stacking two overrides works, but the order depends on the path: on a mod module the second receives the first
as its `original` and the last one wins; on a game class it goes through the `wrap` chain, so the first is the
one left outermost, receiving the second.

Class hooks cannot reach Essentials' top-level functions. `wrap_global` looks for them on `Object`;
`wrap_kernel` tries the `Kernel` singleton first (`def Kernel.foo`, the gen-6 style) and otherwise falls back
to `wrap_global` (`def foo`, modern). A function found nowhere is recorded in `Hooks.fn_absent`.

| `timing` | The block receives | Exception raised by the body |
|---|---|---|
| `:before` | `(args, nil)`, runs before the original | Swallowed, logged once |
| `:after` | `(args, result)`, runs after | Swallowed, logged once |
| `:around` | `(args, call_next)`, you must call `call_next` | Logged and re-raised |

The `:around` on `pbBattleAnimation` (`core/battle/gen6/battle_g6.rb`) is the pattern: the function wraps the
entire battle, so marking inside a `begin/ensure` leaves the flag clean whatever happens.

## Options

| Option | Applies to | Effect |
|---|---|---|
| `:optional => true` | `wrap`, `before_hook`, `after_hook`, `around_hook`, `read_on_open`, `override` | The method is legitimately absent on some games: the bind is skipped silently instead of counting as a typo |
| `:hook_container => true` | `after_hook`, and `read_on_open`, which passes it through | The original runs without the reentrancy guard |
| `:timing => :before` | `read_on_open` | Speaks before the opener, for openers that block in their own loop |
| `:tag => "..."` | `override` | Names the owner of the replacement in the diagnostic listing |

Use `:optional` **YES** when the method is absent through real variance: a plugin variant, a fork that renamed
it, a `pbUpdateBattlerInfo` that only the Deluxe Battle Kit ships. Without it those games park permanent entries
in `missing`, and eight standing false positives hide the real one. **NO** out of habit or just in case:
`missing` is by contract the list of TYPOS, and every extra `:optional` costs it one detection. To branch on what
the engine can do, the gate is `Engine.has?` ([02-engines](02-engines.md)); `:optional` only silences the entry.

## The reentrancy guard

**The problem.** An `after_hook` whose original synchronously calls ANOTHER hooked method (v22:
`set_party_index` invokes `refresh` internally) lets the inner hook speak, which consumes the outer's dedup and
mutes the authoritative announcer: the outer `after_hook`, running once the original returns.

**The mechanism.** The game is single-threaded, so a stack of names is enough.

- `@active`: the names of the methods whose ORIGINAL is running right now.
- `guarded(meth)` pushes, yields and always pops in an `ensure`, so a throwing original never leaves nested
  hooks permanently muted. Only `after_hook` calls it, and only when it is not a container.
- `nested_other?(meth)` is true when the stack is not empty and its top is not `meth`; `wrap`'s dispatcher then
  skips the whole chain and goes straight to the original.

Only `after_hook` **pushes**, but being **skipped** happens to any hooked method, whatever the registrar: a
`before_hook` nested under another guarded one does not fire either.

| Escape | What it does | When you want it |
|---|---|---|
| Same name | A nested call to the SAME name passes through the guard | A child reaching its hooked parent via `super` fires both hooks |
| `:hook_container => true` | The original runs unguarded | The method is a container: it delegates the announcement to hooked methods it drives |
| `frame_hook` | Same, plus the body after and no use of the return value | Per-frame driver that can host a whole modal loop |

The default is atomic (guarded): a hook that says nothing itself keeps the safe behaviour. A **container** is a
modal loop or a scene opener that does not speak itself but drives hooked readers internally -- the battle
command phase, the options screen's `pbUpdate`, the `pbScene`/`pbStartScene`/`main` that drive the pokedex
`drawPage`, the summary `drawPageOne` and the party panel's `selected=`. Guarding them mutes the actual talkers.

### The root case: `Game_Player#update`

In gen-6, stepping onto grass launches the wild battle from INSIDE the player's update
(`Scene_Map#update -> $game_player.update -> encounter -> the whole battle`). With an atomic `after_hook`,
`:update` stays pinned on the stack for the entire fight and every battle reader -- messages, command menu,
moves -- is skipped as `nested_other?`. The symptom was exact: wild battles silent, trainer battles reading,
because those run from the map interpreter, not the player. The three pollers on that method
(`core/nav/locator.rb`, `core/audio/audio3d.rb`, `core/util/recorder.rb`) are `frame_hook` for this reason.

```ruby
# core/nav/locator.rb
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end
```

### Invisible suppression

When the guard drops a hook there is no error, no log and no failing test: the screen simply goes quiet, which
is exactly what a blind player cannot debug. `note_suppressed` records the `"outer>inner"` pair (deduped, capped
at 40) and the diagnostic prints it as `guard_suppressed`. Suppression is often CORRECT: look for the pair whose
outer says nothing.

## The silent failure

`Hooks.missing` only checks the name of the hooked method. A hook that binds perfectly and then reads an ivar or
an accessor named differently on that game shows up in no list: `PokeAccess.ivar` and `PokeAccess.attr_of`
return `nil` instead of raising, `run_body` has nothing to swallow, and the screen stays quiet.

Essentials renamed accessors between eras and every fangame kept the spelling it forked from.
`PokeAccess.attr_of(obj, :power, :base_damage)` tries the names in order and returns the first that answers
something; for ivars the equivalent is chaining `PokeAccess.ivar`.

```ruby
# core/battle/battle.rb -- the command window: @window up to v17, @cmdWindow from v19
PokeAccess.ivar(disp, :@window) || PokeAccess.ivar(disp, :@cmdWindow)
```

Rule: **an installed hook is no proof the data is where you think it is.** Verify it in the game, not in
`missing`.

## Errors and diagnostics

| Registrar | Failure in the body |
|---|---|
| `before_hook`, `after_hook`, `frame_hook`, `read_on_open` | Swallowed; the first one is logged to the marker, deduped per REGISTRATION and not per method, so if two features hook `Game_Player#update` one's failure does not silence the other's diagnostic |
| `around_hook`, `override`, `wrap_*` with `:around` | Logged and re-raised: they may legitimately choose not to run the original |

Four distinct lists, printed by the diagnostic ([07-diagnostics](07-diagnostics.md)); `missing` is also logged
at boot, in `loader/boot.rb`.

| Query | What it holds | How to read it |
|---|---|---|
| `Hooks.missing` | `"Class#method"` whose class exists but whose method does not, plus `override` targets that did not resolve | Likely typo |
| `Hooks.fn_absent` | Global functions no wrapper found anywhere | Informative: some functions only exist on a few fangames |
| `Hooks.overrides` | The declared replacements, as `"Target.meth (tag)"` | Audit: what is replaced and who replaced it |
| `Hooks.suppressed` | `"outer>inner"` pairs the guard dropped | Evidence, not a fault: look for a pair whose outer stays silent |

The default dedup is `PokeAccess::Cursor`; screens with their own loop are polled with `SceneWatcher`
([04-readers](04-readers.md)).
