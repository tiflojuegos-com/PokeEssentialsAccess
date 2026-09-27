# A key a game's screen claims (yield_key!, refreshed every frame it runs) does nothing for the mod, and is the
# mod's again a few frames after the screen stops refreshing the claim.
Suite.define("keys: a key a game's screen claims does nothing for the mod while the screen runs") do
  keys = PokeAccess::Keys
  falsy "nothing is claimed to begin with", keys.yielded?(:info)
  keys.yield_key!(:info)
  truthy "a claim holds", keys.yielded?(:info)
  falsy "for that key only", keys.yielded?(:hp)
  5.times { keys.global_poll }
  falsy "and lapses once the screen stops refreshing it", keys.yielded?(:info)
end

# The press itself, through the frame poll that reads it: the window focused, the info key down.
Suite.define("keys: a press of a claimed key says nothing, and the same press once it lapses reads the info") do
  keys = PokeAccess::Keys
  saved_key = keys.method(:key)
  saved_focus = keys.method(:focused?)
  pressed = [false]
  keys.define_singleton_method(:key) { |name| pressed[0] && name == :info }
  keys.define_singleton_method(:focused?) { true }
  begin
    PokeAccess::Info.set_info(:text, "Datos del lugar")
    keys.yield_key!(:info)
    SpeakCapture.clear
    pressed[0] = true
    keys.global_poll
    silent "the press lands on the game's screen, not on the mod"
    pressed[0] = false
    5.times { keys.global_poll }
    pressed[0] = true
    keys.global_poll
    eq "once the claim lapses the same key reads the info again", SpeakCapture.lines, ["Datos del lugar"]
  ensure
    keys.define_singleton_method(:key, saved_key)
    keys.define_singleton_method(:focused?, saved_focus)
  end
end

# Ctrl on the coordinates key toggles the locator's filter on the map, and does nothing in a battle (Spatial busy).
Suite.define("keys: the coordinates key and its gestures stay with the map") do
  keys = PokeAccess::Keys
  saved = [keys.method(:key), keys.method(:focused?), keys.method(:ctrl_down?)]
  sp = class << PokeAccess::Spatial; self; end
  sp.send(:alias_method, :key_spec_busy, :busy?)
  keys.define_singleton_method(:key) { |name| name == :coords }
  keys.define_singleton_method(:focused?) { true }
  keys.define_singleton_method(:ctrl_down?) { true }
  toggled = []
  loc = class << PokeAccess::Locator; self; end
  loc.send(:alias_method, :key_spec_toggle, :toggle_hide_unreachable)
  PokeAccess::Locator.define_singleton_method(:toggle_hide_unreachable) { toggled.push(:toggle) }
  begin
    PokeAccess::Spatial.define_singleton_method(:busy?) { true }
    keys.global_poll
    eq "in a battle, Ctrl and the key do nothing of the locator's", toggled, []
    PokeAccess::Spatial.define_singleton_method(:busy?) { false }
    keys.global_poll
    eq "on the map, they toggle its filter", toggled, [:toggle]
  ensure
    keys.define_singleton_method(:key, saved[0])
    keys.define_singleton_method(:focused?, saved[1])
    keys.define_singleton_method(:ctrl_down?, saved[2])
    sp.send(:alias_method, :busy?, :key_spec_busy)
    sp.send(:remove_method, :key_spec_busy)
    loc.send(:alias_method, :toggle_hide_unreachable, :key_spec_toggle)
    loc.send(:remove_method, :key_spec_toggle)
  end
end
