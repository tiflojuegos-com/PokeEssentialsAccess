# Hook chaining: several hooks on the same method must all run (an onion), the original's return value is
# preserved, and hooking a parent then a child that overrides the same method (with super) keeps the child's
# logic and its super chain intact -- the real game Options-screen case. Targets are defined here; after_hook
# patches the method when called, so load order does not matter.
Suite.define("hooks: multiple after-hooks chain and keep the result") do
  klass = Class.new { def greet(x); x * 2; end }
  Object.const_set(:HookChainTarget, klass) unless Object.const_defined?(:HookChainTarget)
  log = []
  PokeAccess::Hooks.after_hook("HookChainTarget", :greet) { |_i, r, _a| log << "A:#{r}" }
  PokeAccess::Hooks.after_hook("HookChainTarget", :greet) { |_i, r, _a| log << "B:#{r}" }
  result = HookChainTarget.new.greet(5)
  eq "hook preserves the original result", result, 10
  truthy "both after-hooks on the same method run", log.include?("A:10") && log.include?("B:10")
end

# Parent + overriding child: a hook on the base and a hook on the child must both fire, and the child's own
# body plus its super call must still run, in order: child body, base (via super), then the base hook, then
# the child hook.
Suite.define("hooks: parent and overriding child both fire, super intact") do
  log = []
  base = Class.new { define_method(:step) { log << "base" } }
  Object.const_set(:HookSuperBase, base) unless Object.const_defined?(:HookSuperBase)
  child = Class.new(HookSuperBase) { define_method(:step) { log << "child"; super() } }
  Object.const_set(:HookSuperChild, child) unless Object.const_defined?(:HookSuperChild)
  PokeAccess::Hooks.after_hook("HookSuperBase", :step) { |_i, _r, _a| log << "HB" }
  PokeAccess::Hooks.after_hook("HookSuperChild", :step) { |_i, _r, _a| log << "HC" }
  log.clear
  HookSuperChild.new.step
  eq "child body, super, then both hooks in order", log, ["child", "base", "HB", "HC"]
end

# The typo detector (Hooks.missing): a binding whose CLASS exists but METHOD does not is recorded (a likely
# typo -> a permanently dead feature); a binding whose whole class is absent is NOT recorded (normal
# cross-game variance, handled silently). Unique names so other suites cannot pollute the assertion.
Suite.define("hooks: missing records typo, ignores absent class") do
  target = Class.new { def real_method; end }
  Object.const_set(:HookMissTarget, target) unless Object.const_defined?(:HookMissTarget)
  PokeAccess::Hooks.after_hook("HookMissTarget", :typo_method) { |_i, _r, _a| }
  PokeAccess::Hooks.after_hook("HookNoSuchClassXYZ_pa", :whatever) { |_i, _r, _a| }
  truthy "method absent on a real class is recorded",
         PokeAccess::Hooks.missing.include?("HookMissTarget#typo_method")
  falsy "absent class is not recorded",
        PokeAccess::Hooks.missing.include?("HookNoSuchClassXYZ_pa#whatever")
end

# :optional declares the METHOD legitimately absent on some games (a plugin variant, a fork rename): the
# bind is skipped silently, so @missing keeps its exact meaning of "possible typo". Where the method DOES
# exist, :optional binds normally -- it only changes the absent-method outcome. All four registrars accept it.
Suite.define("hooks: :optional skips an absent method silently but still binds a present one") do
  target = Class.new { def present_method; :orig; end }
  Object.const_set(:HookOptTarget, target) unless Object.const_defined?(:HookOptTarget)
  PokeAccess::Hooks.after_hook("HookOptTarget", :absent_method, :optional => true) { |_i, _r, _a| }
  PokeAccess::Hooks.before_hook("HookOptTarget", :absent_before, :optional => true) { |_i, _a| }
  PokeAccess::Hooks.around_hook("HookOptTarget", :absent_around, :optional => true) { |_i, n, _a| n.call }
  falsy "an optional absent method is not recorded as a typo",
        PokeAccess::Hooks.missing.include?("HookOptTarget#absent_method")
  falsy "optional covers before_hook too",
        PokeAccess::Hooks.missing.include?("HookOptTarget#absent_before")
  falsy "optional covers around_hook too",
        PokeAccess::Hooks.missing.include?("HookOptTarget#absent_around")
  fired = []
  PokeAccess::Hooks.after_hook("HookOptTarget", :present_method, :optional => true) { |_i, r, _a| fired << r }
  eq "an optional present method binds and preserves the result", HookOptTarget.new.present_method, :orig
  eq "the optional hook on a present method fired", fired, [:orig]
end

# wrap_global: the shared helper that replaced six copy-pasted Object-method wraps. :after runs after the
# original and sees its return value; :before runs first with a nil result; the original's return is
# preserved; it never double-wraps. Throwaway Object methods stand in for the real (stubbed-away) sites.
# A SECOND hook on the same function chains onto the first instead of vanishing. An installer that returns
# early once the alias exists binds nothing for whichever reader registered second, with no entry in missing
# and nothing in the diagnostic to show for it. The original must still run exactly once, which is what that
# early return protects and what installing the wrapper once, with the bodies in a list beside it, protects
# instead.
Suite.define("hooks: wrap_global timing, return value and chained bodies") do
  wg = []
  Object.send(:define_method, :pa_wg_after) { |x| wg.push([:orig, x]); x * 2 }
  PokeAccess::Hooks.wrap_global("pa_wg_after", "hook_t1", :after) { |args, r| wg.push([:after, args[0], r]) }
  PokeAccess::Hooks.wrap_global("pa_wg_after", "hook_t1", :after) { |args, r| wg.push([:dup, r]) }
  res = pa_wg_after(5)
  eq "after preserves the return value", res, 10
  eq "the original runs once and BOTH after-bodies run, in order",
     wg, [[:orig, 5], [:after, 5, 10], [:dup, 10]]

  # A broken body must not take its neighbours down with it, nor the function.
  wg3 = []
  Object.send(:define_method, :pa_wg_chain) { |x| x }
  PokeAccess::Hooks.wrap_global("pa_wg_chain", "hook_t5", :after) { |_a, _r| raise "boom" }
  PokeAccess::Hooks.wrap_global("pa_wg_chain", "hook_t5", :after) { |_a, r| wg3.push(r) }
  eq "a throwing body does not stop the next one", pa_wg_chain(3), 3
  eq "and the next one still ran", wg3, [3]

  wg2 = []
  Object.send(:define_method, :pa_wg_before) { |x| wg2.push([:orig, x]); x }
  PokeAccess::Hooks.wrap_global("pa_wg_before", "hook_t2", :before) { |args, r| wg2.push([:before, args[0], r]) }
  pa_wg_before(7)
  eq "before runs first with a nil result", wg2, [[:before, 7, nil], [:orig, 7]]
  PokeAccess::Hooks.wrap_global("pa_wg_missing_xyz", "hook_t3") { |_a, _r| }
  eq "wrapping a missing method does not define it", Object.method_defined?(:pa_wg_missing_xyz), false
  eq "wrapping a missing method creates no alias", Object.method_defined?(:pa_wg_missing_xyz__pa), false
end

# Failure path: a throwing hook/poller body must be logged-once and SWALLOWED, never propagated -- a reader
# bug must not crash a wrapped global or the per-frame input loop. Guards the regression where the call sites
# referenced an undefined log_once (the suite was green because nothing exercised the rescue branch).
Suite.define("hooks: a throwing body is swallowed, not propagated") do
  truthy "log_once is defined", PokeAccess.respond_to?(:log_once)
  Object.send(:define_method, :pa_wg_raise) { |x| x + 1 }
  PokeAccess::Hooks.wrap_global("pa_wg_raise", "hook_t4", :after) { |_a, _r| raise "boom" }
  safe = (begin; pa_wg_raise(4); rescue StandardError; :propagated; end)
  eq "throwing after-body does not propagate, return preserved", safe, 5

  PokeAccess::Keys.on_frame { raise "poller boom" }
  poller = (begin; PokeAccess::Keys.run_frame_pollers; :ok; rescue StandardError; :propagated; end)
  eq "a throwing per-frame poller does not propagate", poller, :ok
end

# Reentrancy guard (after-hook path): when an after-hooked method's ORIGINAL synchronously calls a DIFFERENT
# hooked method, the inner hook is skipped so it cannot speak or consume the outer's dedup -- the OUTER
# after-hook, running once the original returns, is the authoritative announcer (the real v22 set_party_index
# -> refresh case). Called on its own (not nested) the inner hook fires normally, proving the guard changes
# only the nested path.
Suite.define("hooks: a nested different-method hook is skipped and keeps the outer's dedup") do
  klass = Class.new do
    def outer; inner; :outer_done; end
    def inner; :inner_done; end
  end
  Object.const_set(:HookReentTarget, klass) unless Object.const_defined?(:HookReentTarget)
  inner_fired = 0
  inner_stole = false
  outer_spoke = []
  holder = HookReentTarget.new
  # The inner hook competes for the SAME dedup key on the SAME holder the outer uses: if it were allowed to
  # run nested, it would consume the key and mute the outer -- exactly the v22 summary regression.
  PokeAccess::Hooks.after_hook("HookReentTarget", :inner) do |i, _r, _a|
    inner_fired += 1
    inner_stole = true if PokeAccess::Cursor.changed?(i, :reent_slot, :k1)
  end
  PokeAccess::Hooks.after_hook("HookReentTarget", :outer) do |h, _r, _a|
    outer_spoke << :outer if PokeAccess::Cursor.changed?(h, :reent_slot, :k1)
  end

  r = holder.outer
  eq "the outer original still returns its value", r, :outer_done
  eq "the inner hook does NOT fire while nested inside outer's original", inner_fired, 0
  falsy "the inner hook did not consume the shared dedup key", inner_stole
  eq "the outer hook speaks: its dedup survived the nested call", outer_spoke, [:outer]

  inner_fired = 0
  eq "calling inner directly (not nested) runs its original", holder.inner, :inner_done
  eq "the inner hook fires when it is the top-level call", inner_fired, 1
end

# hook_container: the escape hatch for a CONTAINER -- a modal loop or scene opener whose original delegates the
# announcement to hooked methods it drives internally. This is the gen-6 battle command phase: the
# pbUpdateSelected / command-loop original drives the display's own hooked index setter every frame, and the
# default reentrancy guard would mute that reader (the real regression where Pokemon Z battles read nothing).
# Marking the outer hook hook_container: true runs its original UNGUARDED so the nested reader speaks, while the
# atomic guard above is untouched -- both behaviours coexist.
Suite.define("hooks: a hook_container lets its nested reader speak (battle command phase)") do
  klass = Class.new do
    def loop_update(i); set_index(i); :looped; end   # the container: drives the reader internally
    def set_index(i); @i = i; :set; end              # the real reader (a hooked display setter)
  end
  Object.const_set(:HookContainerTarget, klass) unless Object.const_defined?(:HookContainerTarget)
  read = []
  holder = HookContainerTarget.new
  PokeAccess::Hooks.after_hook("HookContainerTarget", :set_index) { |_i, _r, a| read << a[0] }
  PokeAccess::Hooks.after_hook("HookContainerTarget", :loop_update, :hook_container => true) { |_i, _r, _a| }

  holder.loop_update(2)
  eq "the nested reader speaks because the container ran unguarded", read, [2]

  # Contrast: the SAME nested call, but the outer is a plain (atomic) after-hook -> guarded -> reader muted.
  klass2 = Class.new do
    def loop_update(i); set_index(i); :looped; end
    def set_index(i); @i = i; :set; end
  end
  Object.const_set(:HookAtomicTarget, klass2) unless Object.const_defined?(:HookAtomicTarget)
  read2 = []
  h2 = HookAtomicTarget.new
  PokeAccess::Hooks.after_hook("HookAtomicTarget", :set_index) { |_i, _r, a| read2 << a[0] }
  PokeAccess::Hooks.after_hook("HookAtomicTarget", :loop_update) { |_i, _r, _a| }
  h2.loop_update(2)
  eq "without hook_container the guard mutes the nested reader", read2, []
end

# frame_hook: a per-frame DRIVER whose original can synchronously host an ENTIRE nested modal loop. This is
# the real Pokemon Z wild-battle regression: gen-6 launches the whole battle from inside Game_Player#update
# (Scene_Map#update -> $game_player.update -> encounter -> the full battle loop), so an atomic after-hook on
# update would pin :update on the reentrancy stack for the entire fight and skip EVERY battle reader as
# nested_other? -- total silence in wild battles only (trainer battles run from the interpreter, not the
# player, so they were unaffected). frame_hook runs the driver's original UNGUARDED so all the readers driven
# inside the nested battle loop still speak, and runs its own body after (a poller reading post-update state
# has no lag). The contrast case reproduces the exact silence an atomic after-hook caused.
Suite.define("hooks: a frame_hook lets readers inside a nested battle loop speak (wild-battle regression)") do
  klass = Class.new do
    def update; run_battle; :updated; end          # the per-frame driver that hosts the whole battle
    def run_battle; show_message; move_cursor; :fought; end  # the nested modal loop
    def show_message; :msg; end                    # a battle reader (message)
    def move_cursor; :cur; end                     # another battle reader (command/move cursor)
  end
  Object.const_set(:HookFrameDriver, klass) unless Object.const_defined?(:HookFrameDriver)
  spoke = []
  holder = HookFrameDriver.new
  PokeAccess::Hooks.before_hook("HookFrameDriver", :show_message) { |_i, _a| spoke << :msg }
  PokeAccess::Hooks.after_hook("HookFrameDriver", :move_cursor) { |_i, _r, _a| spoke << :cur }
  PokeAccess::Hooks.frame_hook("HookFrameDriver", :update) { |_i, _a| spoke << :tick }

  r = holder.update
  eq "the driver original still returns its value", r, :updated
  truthy "the nested message reader spoke", spoke.include?(:msg)
  truthy "the nested cursor reader spoke", spoke.include?(:cur)
  truthy "the frame_hook body ran too", spoke.include?(:tick)

  # Contrast: the SAME nested readers, but the driver is a plain (atomic) after-hook -> guarded -> both muted.
  klass2 = Class.new do
    def update; run_battle; :updated; end
    def run_battle; show_message; move_cursor; :fought; end
    def show_message; :msg; end
    def move_cursor; :cur; end
  end
  Object.const_set(:HookFrameAtomic, klass2) unless Object.const_defined?(:HookFrameAtomic)
  spoke2 = []
  h2 = HookFrameAtomic.new
  PokeAccess::Hooks.before_hook("HookFrameAtomic", :show_message) { |_i, _a| spoke2 << :msg }
  PokeAccess::Hooks.after_hook("HookFrameAtomic", :move_cursor) { |_i, _r, _a| spoke2 << :cur }
  PokeAccess::Hooks.after_hook("HookFrameAtomic", :update) { |_i, _r, _a| }
  h2.update
  eq "an atomic after-hook driver mutes every reader in the nested loop", spoke2, []
end

# Reentrancy guard must not break around-hook semantics: when the wrapped original raises, the around body's
# ensure still runs and the exception still propagates (around may legitimately let a failure through). The
# guard only touches before/after; an around wrapping a throwing original is the case to protect.
Suite.define("hooks: an around-hook runs its ensure and propagates when the original raises") do
  klass = Class.new { def boom; raise "kaboom"; end }
  Object.const_set(:HookAroundEnsure, klass) unless Object.const_defined?(:HookAroundEnsure)
  ensured = []
  PokeAccess::Hooks.around_hook("HookAroundEnsure", :boom) do |_i, nxt, _a|
    begin; nxt.call; ensure; ensured << :ran; end
  end
  outcome = (begin; HookAroundEnsure.new.boom; :no_raise; rescue StandardError => e; e.message; end)
  eq "the around-hook's ensure ran despite the original raising", ensured, [:ran]
  eq "the original's exception still propagated out of the around-hook", outcome, "kaboom"
end

# Reentrancy guard MUST NOT reach the before-hook path. A before_hook commonly wraps a modal loop or a scene
# opener (pbScene, pbStartScene, main) whose original synchronously drives OTHER announcing hooks -- the
# pokedex-entry drawPage, the summary drawPageOne, the party panel selected=. Its body already spoke (or, as
# here, only reset a dedup) BEFORE the original, so nothing it owns is at risk; the nested announcer MUST fire.
# Guarding the before path muted that whole family (pokedex/summary/party silent on open). This models the
# real chain: an opener before-hook that only resets, whose original draws via a DIFFERENT after-hook that
# announces through the just-reset dedup.
Suite.define("hooks: a before-hook opener does not mute the nested announcer its original drives") do
  klass = Class.new do
    def open_scene; draw_page; :opened; end
    def draw_page; :drawn; end
  end
  Object.const_set(:HookOpenerTarget, klass) unless Object.const_defined?(:HookOpenerTarget)
  drew = []
  holder = HookOpenerTarget.new
  # The opener's before-body only clears the dedup (as pbScene/pbStartScene reset do); the nested draw_page
  # after-hook is the actual announcer and must speak through the freshly reset slot.
  PokeAccess::Hooks.before_hook("HookOpenerTarget", :open_scene) do |i, _a|
    PokeAccess::Cursor.reset(i, :opener_slot)
  end
  PokeAccess::Hooks.after_hook("HookOpenerTarget", :draw_page) do |i, _r, _a|
    drew << :page if PokeAccess::Cursor.changed?(i, :opener_slot, :p1)
  end

  r = holder.open_scene
  eq "the opener original still returns its value", r, :opened
  eq "the nested draw announcer fired while inside the opener's original", drew, [:page]
end

# The asymmetry, side by side: the SAME nested-announcer method, driven once by an after-hooked caller
# (guarded -> skipped) and once by a before-hooked caller (unguarded -> fires). Locks that the guard lives on
# the after path only, so fixing the v22 dedup competition never re-silences an opener.
Suite.define("hooks: the guard applies to the after caller but not the before caller") do
  klass = Class.new do
    def after_caller; announce; :a; end
    def before_caller; announce; :b; end
    def announce; :ann; end
  end
  Object.const_set(:HookGuardSide, klass) unless Object.const_defined?(:HookGuardSide)
  fired = []
  holder = HookGuardSide.new
  PokeAccess::Hooks.after_hook("HookGuardSide", :after_caller) { |_i, _r, _a| }
  PokeAccess::Hooks.before_hook("HookGuardSide", :before_caller) { |_i, _a| }
  PokeAccess::Hooks.after_hook("HookGuardSide", :announce) { |_i, _r, _a| fired << :ann }

  holder.after_caller
  eq "nested announce is skipped when driven by an after-hooked caller", fired, []
  fired.clear
  holder.before_caller
  eq "nested announce fires when driven by a before-hooked caller", fired, [:ann]
end
