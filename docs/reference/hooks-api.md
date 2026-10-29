# Hooks API

This page lists the registrars of `PokeAccess::Hooks` (`core/input/hooks.rb`): their arguments, block parameters,
options, timings, failure behavior and the diagnostic lists they fill. The model behind them, from binding by class
name to game resets, is explained in [Hooks](../architecture/hooks.md).

## Registrars

| Registrar | Wraps | Body runs |
|---|---|---|
| `before_hook` | an instance method | before the original |
| `after_hook` | an instance method | after the original |
| `frame_hook` | an instance method | after the original, which runs without the reentrancy guard |
| `read_on_open` | an instance method | after the original, or before it |
| `around_hook` | an instance method | in place of the original |
| `override` | a mod module's method or a game class's instance method | in place of the original |
| `wrap` | an instance method | as its middleware decides |
| `wrap_global` | a function defined on `Object` | before, after or around the function |
| `wrap_kernel` | a function on `Kernel`'s singleton class, else on `Object` | before, after or around the function |
| `wrap_singleton` | a singleton method of a game module | before, after or around the method |
| `variants` | nothing itself | runs one registration under each name of a class |

Each registrar is a module method, called as `PokeAccess::Hooks.after_hook(...)`. A [profile](glossary.md) reaches
some of them through its DSL ([Profile DSL forms](#profile-dsl-forms)). The architecture page explains the
[reentrancy guard](../architecture/hooks.md#reentrancy-guard) and [containers](../architecture/hooks.md#containers).

## Arguments of the class registrars

`before_hook`, `after_hook`, `frame_hook`, `read_on_open`, `around_hook` and `wrap` take the same first arguments:

- `cname`: the class's name as a String, such as `"Battle::Scene"`. `PokeAccess.const_at` resolves it when the hook
  is registered, one `::` segment at a time. A literal name is checked by `test/static/hooked_classes_test.rb`.
- `meth`: the method's name as a Symbol. The method may be public or private, defined on the class or inherited; the
  wrapper is defined on the named class.
- `opts`: a Hash of the [options](#options). `frame_hook` takes none.

Each answers `true` when its body joined the method's chain. It answers `false` when the class or the method does not
exist, or when the wrapper could not be installed.

## Options

| Option | Accepted by | Effect |
|---|---|---|
| `:optional => true` | class registrars but `frame_hook`; `override` | No `Hooks.missing` entry when absent |
| `:hook_container => true` | `after_hook`, `read_on_open` | The original runs without the reentrancy guard |
| `:timing => :before` | `read_on_open` | The text is said before the original runs |
| `:tag => "name"` | `override` | Names the owner in the `Hooks.overrides` entry |

Other keys are ignored. `:hook_container` changes nothing on a registration whose original already runs unguarded.

## Block parameters

| Registration | Parameters | The hooked call answers |
|---|---|---|
| `before_hook` | `inst, args` | unchanged |
| `after_hook` | `inst, result, args` | unchanged |
| `frame_hook` | `inst, args` | unchanged |
| `read_on_open` | `scene` | unchanged |
| `around_hook` | `inst, call_next, args` | the body's value |
| `override` | `receiver, original, args` | the body's value |
| `wrap` | `inst, call_next, args` | the middleware's value |
| function, `:before` | `args, result` (`result` is `nil`) | unchanged |
| function, `:after` | `args, result` | unchanged |
| function, `:around` | `args, call_next` | the body's value |

- `inst` is the object whose method was called. `args` is the Array of the call's arguments.
- A body that runs before the original can change `args` in place, and the original receives the change.
- `call_next` and `original` take no arguments. Calling one runs the rest of the chain and the original with `args`
  and returns its value. A body that does not call it skips the original.
- The block passed to the hooked method goes to the original. Bodies do not receive it.
- Declare every parameter the registration passes. Under Ruby 1.8.7 a block with one parameter receives all the
  values as one Array. The arity net of the suite (`test/support/arity_net.rb`) fails a run in which a one-parameter
  block of the mod receives several values.

## Class registrars

Registrations on one method form one chain, the first registration outermost
([Several hooks on one method](../architecture/hooks.md#several-hooks-on-one-method)). `before_hook` bodies run in
registration order and `after_hook` bodies in reverse. `around_hook` bodies and instance overrides nest with the first
registered outermost. The reentrancy guard can skip any of these chains.

### before_hook

`before_hook(cname, meth, opts = {}) { |inst, args| ... }`

Runs the body, then the rest of the chain and the original. The original runs without the guard. A failing body is
swallowed.

### after_hook

`after_hook(cname, meth, opts = {}) { |inst, result, args| ... }`

Runs the rest of the chain and the original under the reentrancy guard, then the body with the original's result. The
body's own value is discarded. With `:hook_container => true` the original runs without the guard. When the original
raises, the body does not run and the exception goes on to the caller. A failing body is swallowed.

### frame_hook

`frame_hook(cname, meth) { |inst, args| ... }`

An `after_hook` registered with `:hook_container => true` whose body does not receive the result. It suits a
per-frame driver that can run a nested loop; the map frame binds with it in `core/input/frame.rb`. It accepts no
options, so a method absent in a game always goes to `Hooks.missing`.

### read_on_open

`read_on_open(cname, meth = :pbStartScene, opts = {}) { |scene| text }`

Says the block's value when the method runs. `PokeAccess.clean` strips the control codes, and `PokeAccess.speak`
says the text queued, without interrupting. A `nil` or empty value says nothing. The block runs after the original,
through `after_hook`. With `:timing => :before` it runs before, through `before_hook`, for an opener that runs the
screen's loop before it returns. `:optional` and `:hook_container` pass on to the hook.

### around_hook

`around_hook(cname, meth, opts = {}) { |inst, call_next, args| ... }`

The body takes the place of the call. The original runs only when the body calls `call_next`, and it runs without
the guard. A failing body is logged once and its exception raised again. An exception of the original passes through
the body and is raised again unlogged.

### wrap

`wrap(cname, meth, opts = {}) { |inst, call_next, args| ... }`

The middleware the other class registrars are built on; the mod's code calls those instead. Nothing rescues the
middleware: its exception reaches the caller and is not logged.

The first registration on a method installs the wrapper and keeps the game's method under the alias
`<meth>__pa_orig_<cname>`, each character of `cname` other than a letter or a digit replaced by `_`
(`pbFightMenu__pa_orig_Battle__Scene`). If the class already defines that alias, `wrap` keeps it as the original.
Later registrations add their middleware to the chain.

The chain is keyed by the class name as written and the method, as `"Battle::Scene#pbFightMenu"`. Two names for one
class make two chains on the same method, and a call runs both. `variants` skips the second name.

## Several names for one class

`variants(names, meth, label = nil) { |cname| bound }`

- Calls the block with each name in `names`, every ancestor before its descendants and otherwise in the order given.
- Skips a name whose class is the same as, a subclass of or a superclass of a class already bound. A name whose class
  does not exist still reaches the block, and its registrar answers `false`.
- The block registers the hook under the name it receives and answers whether it bound. The registrar's own answer
  serves.
- Returns the names that bound. When none did, records `"<label>#<meth>"` in `Hooks.unbound`; `label` defaults to the
  first name. `meth` only names the group, and the block chooses the method it hooks.

```ruby
# core/field/trade_shiny.rb
PokeAccess::Hooks.variants(["PokemonTradeScene", "PokemonTrade_Scene"], :pbScene2, "trade_shiny") do |cname|
  PokeAccess::Hooks.before_hook(cname, :pbScene2, :optional => true) do |scene, _a|
    pk = PokeAccess.ivar(scene, :@pokemon2)
    PokeAccess.after_next_line(PokeAccess::I18n.t(:pk_shiny_hatch)) if pk && PokeAccess::Party.shiny?(pk)
  end
end
```

`PokeAccess::Engine.scene_classes(*names)` (`core/foundation/engine.rb`) returns the existing names, less a subclass
of another listed class and a second name for one class. It records nothing.

## Overrides

`override(target, meth, opts = {}) { |receiver, original, args| ... }`

`target` is a module or a class, or its name as a String. The override takes the first case that applies:

- The target's singleton class defines `meth`: the override replaces that singleton method. When the target's
  instances also define `meth`, it counts as a singleton method only if the singleton class defines it itself, so a
  class's `name` inherited from `Module` is not one.
- The target's instances define `meth`: the override is an `around_hook` on the target's name.
- Neither: `"<label>#<meth>"` goes to `Hooks.missing`, unless `:optional` is given.

A singleton override keeps the original as `<meth>__pa_override_<n>` and passes the module as `receiver`. A later
override of the same singleton method wraps the earlier one: the later body runs first, and its `original` is the
earlier override.

An instance override joins the method's chain like any `around_hook`. The first registered runs first, and its
`original` is the next layer. The reentrancy guard can skip it with the method's other hooks.

Each installation adds `"<label>.<meth>"` to `Hooks.overrides`, followed by ` (<tag>)` when `:tag` is given. The label
is the String given, or the target's `Module#name`, read through `Module` because a mod module may define a `name`
method of its own. A failing body is logged once and its exception raised again.

```ruby
# plugins/dbk_battle.rb
PokeAccess::Hooks.override(PokeAccess::Battle, :shown_level, :tag => "dbk_battle") do |_mod, original, args|
  b = args[0]
  PokeAccess::Battle.styled_box(b) && !(b.index.even? rescue false) ? nil : original.call
end
```

## Function wrappers

- `wrap_global(name, tag, timing = :after) { ... }`
- `wrap_kernel(name, tag, timing = :before) { ... }`
- `wrap_singleton(owner, name, tag, timing = :before) { ... }`

| Registrar | The function is defined as | Default timing | `Hooks.fn_absent` entry |
|---|---|---|---|
| `wrap_global` | a public or private instance method of `Object` (a top-level `def`) | `:after` | `"<name>"` |
| `wrap_kernel` | a method of `Kernel`'s own singleton class (gen-6), else as above | `:before` | `"<name>"` |
| `wrap_singleton` | a singleton method of the module named `owner` | `:before` | `"<owner>.<name>"` |

- `name` is the function's name, as a String or a Symbol. `tag` names the registration in the marker line written
  when the wrapper cannot be installed.
- `timing` is `:before`, `:after` or `:around` ([block parameters](#block-parameters)). The `:before` bodies run
  first, in registration order. The `:around` bodies follow, nested with the first registered outermost, or the
  function runs alone. The `:after` bodies run last, in registration order.
- The `:after` bodies do not run when the call raises. They run from an `ensure`, so a `return` or `break` out of a
  block passed to the function still runs them, with a `nil` result.
- The first registration on a function installs one wrapper and keeps the original as `<name>__pa`. Later
  registrations add their body to it.
- Bodies are stored by function name (`"<owner>.<name>"` for `wrap_singleton`), so a function wrapped both on `Kernel`
  and on `Object` runs the same bodies from either wrapper.
- The `wrap_global` wrapper keeps the function's visibility, since a game may call a public function through
  `Kernel`.
- The reentrancy guard does not apply. A function wrapper always runs its bodies, and it does not set `Hooks.screen`.
- The return value of these registrars is not meaningful.

```ruby
# core/sound/feedback.rb
PokeAccess::Hooks.wrap_kernel("pbSEPlay", "game_bump", :around) do |args, nxt|
  PokeAccess::Sound::Feedback.mute_game_bump?(args[0]) ? nil : nxt.call
end
```

## Failures

| Registration | Its exception | First failure in the marker file |
|---|---|---|
| `before_hook`, `after_hook`, `frame_hook` | swallowed | `hook body <cname>#<meth>@<n>: <error>` |
| `read_on_open` | swallowed | `hook body <cname>#<meth>@<n>: <error>` |
| `around_hook`, instance `override` | raised again | `hook body <cname>#<meth>@<n>: <error>` |
| singleton `override` | raised again | `hook body override <label>.<meth>: <error>` |
| function, `:before` or `:after` | swallowed | `<wrapper>: <error>` |
| function, `:around` | raised again | `hook body fn <wrapper>: <error>` |
| `wrap` middleware | raised, not logged | none |

- A failing body is one that raises a `StandardError`. Other exceptions, such as mkxp-z's `Reset`, are not rescued.
- An exception the game's own method raises under an `around_hook`, an instance `override` or an `:around` function
  wrapper is raised again with no marker line.
- After a swallowed exception the call goes on as if the body were not there: the original runs and answers, and
  the next function body runs.
- `<n>` numbers the registrations of the session, so two hooks on one method log their failures apart.
- `<wrapper>` is `global_<name>`, `kernel_<name>` or `singleton_<owner>.<name>`. It is one key per function, so the
  marker file gets only the first failing body of a function. These failures also appear in the `logged=` line of
  the diagnostic dump.
- `<error>` is `PokeAccess.format_error`: the class, the message and the top three backtrace frames.
- A swallowed class-hook failure also goes to `PokeAccess.swallowed`, which writes `swallowed <site>: <error>` once
  per place in the mod and counts every occurrence for the `swallowed=` line of the diagnostic dump.

An installation that raises is written as `wrap <cname>#<meth>: <message>`, `override <label>#<meth>: <message>` or
`<tag>: <message>`, and the hook is not installed.

The [marker file](glossary.md) is `hook_loaded.txt` in the data folder
([The marker file](../architecture/diagnostics.md#the-marker-file)).

## Game resets

- `keep_bound(owner, meth) { |again| ... }`: runs the install block with `false`, and records it for `rebind`.
- `rebind`: runs with `true` each recorded block whose method the game's scripts replaced, and answers how many.
- `after_reset`: runs `rebind`, then `PokeAccess::Caches.reset_all`, and writes `game reset: <n> wrappers put back`.

Every registrar installs its wrapper through `keep_bound`. `AccessPreload.after_reset` (`loader/preload_access.rb`)
calls `Hooks.after_reset` once the game's scripts have run again after an F12 reset
([Loading](../architecture/loading.md)). A wrapper that cannot be put back is written as
`rebind <owner>#<meth>: <message>`.

## Diagnostic lists

| Method | Entry | Recorded by | Kept |
|---|---|---|---|
| `Hooks.missing` | `"<cname>#<meth>"` | an absent method or `override` target | each entry once |
| `Hooks.unbound` | `"<label>#<meth>"` | `variants`, when no name bound | each entry once, the first 40 |
| `Hooks.fn_absent` | `"<name>"` or `"<owner>.<name>"` | a function wrapper that found no function | each entry once |
| `Hooks.overrides` | `"<label>.<meth> (<tag>)"` | each `override` installed | every installation |
| `Hooks.suppressed` | `"<outer>><cname>#<meth>"` | the reentrancy guard | each pair once, the first 40 |

`Hooks.missing` records a method absent from a class that exists, and an `override` whose target or method is
absent. A class registrar on an absent class records nothing. An `override` entry has its ` (<tag>)` part only
when `:tag` is given. In a `Hooks.suppressed` pair, `<outer>` is the name of the method whose guarded original was
running, and `<cname>#<meth>` the chain the guard skipped. `Hooks.screen` holds the class name of the last class
wrapper called, skipped calls included.

| Output | What it shows |
|---|---|
| `loader_error.txt`, at boot | `missing` and `unbound`, after `[diag] enganches sin metodo (posible typo):` |
| `hooks:` line of the diagnostic dump | `missing`, `fn_absent`, `overrides` and `unbound`, each cut at 200 characters |
| `guard_suppressed=` line of the diagnostic dump | `suppressed`, cut at 300 characters |
| `silent:` line of the diagnostic dump | the screens that stayed silent after they came up, by `Hooks.screen` |
| spoken diagnostic (Ctrl+Alt+F10) | how many entries `missing` holds |
| self-check, `selfcheck.txt` | `missing` and `unbound`, one `falta` line each |

The boot writes `loader_error.txt` (`loader/boot.rb`). The silence watch names a screen by `$scene` until a hook has
run (`core/util/silence.rb`). [Diagnostics](../architecture/diagnostics.md) describes the diagnostic dump.

## Profile DSL forms

A profile's `PokeAccess::Game.define` block forwards `after`, `before`, `around`, `read_on_open`, `override` and
`kernel` to `after_hook`, `before_hook`, `around_hook`, `read_on_open`, `override` and `wrap_kernel`
(`core/foundation/game.rb`). The [profile DSL reference](profile-dsl.md#hooks) lists their arguments and how they
differ from the registrars.

## Other methods of the module

| Method | Role |
|---|---|
| `guarded(meth)` | runs a block with `meth` on the guard's stack |
| `nested_other?(meth)` | whether the guard skips a call to `meth` now |
| `note_suppressed(inner)` | records a pair the guard skipped |
| `note_screen(cname)`, `screen` | set and read `Hooks.screen` |
| `keep_original(owner, meth, ali)` | keeps the original under `ali`, past a prepended module that overrides it |
| `beneath_prepends(owner, meth)` | the method beneath the modules prepended to `owner` |
| `pass_keywords(owner, meth)` | marks a wrapper with `ruby2_keywords`, so keyword arguments reach the original |
| `next_key(cname, meth)` | the failure key of a new registration |
| `run_body(key)`, `log_body_failure(key, e)` | run a body under the rescue, and write its first failure |
| `ancestors_first(names)` | the order in which `variants` tries its names |
| `override_singleton`, `note_missing_override` | the singleton case and the absent case of `override` |
| `kernel_owns?(sym)` | whether `Kernel`'s own singleton class defines a function |
| `define_fn_wrapper`, `note_fn_absent` | install a function wrapper, and record an absent function |
| `add_fn_body`, `fn_bodies`, `run_fn_bodies` | keep and run the bodies of the function wrappers |

## Checks on registrations

These static checks read the hook registrations: `test/static/hooked_classes_test.rb` (the class exists in a surveyed
game), `test/static/arity_test.rb` (the `args` positions a body reads), `test/static/blocking_hooks_test.rb` (no after
hook on a screen's blocking loop) and `test/static/ivars_test.rb` (the instance variables a reader reads). They are
described in [Static checks](static-checks.md).
