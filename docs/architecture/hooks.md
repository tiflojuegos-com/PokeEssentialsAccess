# Hooks

This page explains how the mod attaches its code to the game's methods: how a hook binds, how several hooks on one
method run, the reentrancy guard, game resets and failures. The registrars, their options and their block
arguments are listed in the [hooks API reference](../reference/hooks-api.md).

## What a hook is

The mod never edits a game's scripts. It reads a screen by running its own code around methods the screen already
calls. Each registrar in `core/input/hooks.rb` installs a wrapper over an existing method; the wrapper calls the
game's method and runs the mod's code before it, after it or around it.

## Binding by class name

A hook names its class as a string, such as `"Battle::Scene"`, and `Hooks.wrap` resolves the string when the hook is
registered. Many classes exist only in some games: `PokemonMenu_Scene` is gen-6 and `UI::BaseScreen` is v22. A
constant written in the code raises `NameError` in a game that lacks it, and the boot skips the rest of that file.
The mod loads after the game's scripts
([Loading](loading.md)), so every class the game defines exists when its hooks are registered.

Resolving the name has three outcomes:

- The class does not exist. The hook does not bind and nothing is recorded; this is the normal difference between
  games.
- The class exists and the method does not. The hook does not bind and `Class#method` goes to `Hooks.missing`,
  unless the hook is registered with `:optional => true`.
- Both exist. The hook binds.

`Hooks.missing` is a list of likely mistakes in the mod. `:optional` belongs on a method that some games lack for a
real reason, such as a method a fork renamed or one only a plugin adds. Marking a method optional as a precaution
removes a possible mistake from that list. Code that depends on what the engine provides asks `Engine.has?`
instead ([Engine eras](engine-eras.md)).

`Hooks.variants` binds one hook under every name a class takes across games, such as `PokemonTradeScene` and
`PokemonTrade_Scene`. It tries ancestors first and skips a class that is a subclass or a superclass of one already
bound. A group that binds under none of its names goes to `Hooks.unbound`: a class absent under one name is normal,
absent under all of them is a mistake in the mod.

## Several hooks on one method

Hooks on the same method form a middleware chain. The first hook on a method creates the wrapper and keeps the
game's method under an alias that carries the class name, such as `update__pa_orig_Game_Player`. Later hooks add
their middleware to the chain. A new hook never replaces an existing one.

The first registration is the outermost layer. With hooks A and B registered in that order, `before_hook` bodies
run A then B, and `after_hook` bodies run B then A.

Each alias carries its own class's name, so a hook on a parent class and a hook on a child that overrides the method
both keep their wrapper. When a module prepended to the class overrides the method (Ruby 2 and later),
`Hooks.keep_original` takes the method from beneath the module: an alias would copy the module's method, whose
`super` would call the wrapper again. A private method keeps its visibility after it is wrapped.

## Reentrancy guard

An `after_hook` reads the state its method leaves. If that method calls another hooked method on the way, the inner
hook speaks first and its change detection consumes the line the outer hook was going to say. The guard prevents
this.

While the original of an `after_hook` runs, its method name is on a stack. A hooked call to a method with a
different name, made while that stack is not empty, skips its whole chain and runs the game's method alone. A call
to the same name passes, so a child class that reaches its hooked parent through `super` runs both hooks.

Only `after_hook` puts its method on the stack. `before_hook` and `around_hook` run the original without it. Any
method hooked through `Hooks.wrap` can be skipped, whatever registrar bound it. The function wrappers and the
overrides of module methods never check the guard.

### Containers

The guard suits a method that reads its own result. It does not suit a method that drives other readers, such as a
modal loop or a scene opener that says nothing itself and calls the methods that do. Guarding that method silences
the whole screen. Two registrations run the original without the guard:

- `after_hook` with `:hook_container => true`, for a container whose result the hook still reads.
- `frame_hook`, for a per-frame driver that can run a whole nested loop.

In gen-6 a wild battle runs inside `Game_Player#update`, because stepping into grass starts the encounter there. A
guarded hook on that method would keep `update` on the stack for the whole battle and skip every battle reader. The
mod's map frame, `PokeAccess::Frame.run` in `core/input/frame.rb`, is bound to that method with `frame_hook` for this
reason; it runs the world, control, navigation and sound stages in order ([Loading](loading.md)).

### Suppressed hooks

A hook the guard skips raises no error; the screen goes quiet. Each skipped pair is recorded as `outer>inner`, the
name of the method on the stack and the skipped `Class#method`, at most 40 per session, and the diagnostic dump prints
them as `guard_suppressed`. Most pairs are correct. A pair whose outer method says nothing points at a method that
should be a container.

## Game resets

An F12 reset runs the game's scripts again, and their definitions replace the mod's wrappers. `Hooks.keep_bound`
records each wrapper as installed, with the block that installs it. After the reset, `Hooks.rebind` installs again
every wrapper whose method changed, over the game's new method, and `Hooks.after_reset` clears the caches kept for the
previous run.

## Failures

A reader must not break the game. The body of a `before_hook`, `after_hook`, `frame_hook` or `read_on_open` runs
inside a rescue: its exception is swallowed, and the first one of each registration is written to the marker file.
Failures are logged per registration, so one failing reader does not hide another's failure on the same method. The
`:before` and `:after` bodies of the function wrappers are swallowed too, with the first failure logged per function.

`around_hook`, `override` and the `:around` timing of the function wrappers log the exception and raise it again.
Their body decides whether the game's method runs, so swallowing an exception could skip the method silently.

A hook that binds can still read nothing. Accessors and instance variables changed names between Essentials
versions, and each fangame kept the names of the version it started from. `PokeAccess.ivar` and
`PokeAccess.attr_of` return `nil` for a name that does not exist, so a hook that reads the wrong name stays silent
without an error. `PokeAccess.attr_of(obj, :power, :base_damage)` tries several names in order.

```ruby
# core/battle/battle.rb
PokeAccess.ivar(disp, :@window) || PokeAccess.ivar(disp, :@cmdWindow)
```

A bound hook does not prove that its data exists; the game's scripts do.

## Functions, module methods and overrides

Essentials also calls top-level functions, such as `pbMessage` and `pbFadeOutIn`, and singleton methods of its own
modules. Class hooks do not reach them:

- `Hooks.wrap_global` wraps a function defined on `Object`.
- `Hooks.wrap_kernel` wraps a function defined as a `Kernel` singleton, as gen-6 defines them, and otherwise falls
  back to `wrap_global`.
- `Hooks.wrap_singleton` wraps a module's own singleton method, defined as `def self.x` and called as `Module.x`.

One wrapper serves every body registered on a function. A function found nowhere goes to `Hooks.fn_absent`; some
functions exist in a few games only, so that list is informational.

`Hooks.override` replaces a method of a mod module or of a game class and records the replacement in
`Hooks.overrides`. A profile uses it to change what a core reader does in one game without editing `core/`.

## Diagnostic lists

| List | Holds |
|---|---|
| `Hooks.missing` | Hooks whose class exists and method does not; override targets that do not resolve |
| `Hooks.unbound` | `variants` groups that bound under none of their names |
| `Hooks.fn_absent` | Functions that no wrapper found |
| `Hooks.overrides` | Installed overrides, as `Target.meth (tag)` |
| `Hooks.suppressed` | `outer>inner` pairs the reentrancy guard skipped |

The boot logs `Hooks.missing` and `Hooks.unbound` as one list (`loader/boot.rb`). The diagnostic dump prints all
five ([Diagnostics](diagnostics.md)).
