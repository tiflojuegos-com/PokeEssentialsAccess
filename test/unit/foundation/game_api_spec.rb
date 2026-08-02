# Adapter API (#1): PokeAccess::Game.define forwards each declarative call to the SAME registration point
# the raw calls use, so a migrated profile behaves identically. Exercises every forwarder (config,
# button_labels, screen_reader, after) plus the per-frame registry (poll_each_frame -> Keys.on_frame, run by
# the single Input.update wrapper via run_frame_pollers).
Suite.define("game api: define forwards every declarative call") do
  hook_target = Class.new { def ping; :orig; end }
  Object.const_set(:ApiHookTarget, hook_target) unless Object.const_defined?(:ApiHookTarget)
  api_window = Class.new { def index; 2; end }
  Object.const_set(:ApiTestWindow, api_window) unless Object.const_defined?(:ApiTestWindow)

  api_log = []
  $api_log_ref = api_log
  old_money = PokeAccess::Config.money_label
  PokeAccess::Game.define("test_profile") do
    config(:money_label, :tr_money_generic)
    button_labels :q => "Quaff"
    screen_reader("ApiTestWindow") { |_w, i| "row#{i}" }
    after("ApiHookTarget", :ping) { |_i, r, _a| $api_log_ref << r }
  end
  truthy "profile registered", PokeAccess::Game.profiles.include?("test_profile")
  eq "config(key, val) applied", PokeAccess::Config.money_label, :tr_money_generic
  eq "button_labels merged", PokeAccess::Config.rebind_labels[:q], "Quaff"
  eq "screen_reader becomes an extractor", PokeAccess::Menus.focused_text(ApiTestWindow.new), "row2"
  ApiHookTarget.new.ping
  eq "after becomes a hook", api_log, [:orig]
  PokeAccess::Config.money_label = old_money

  $frame_log_ref = []
  PokeAccess::Game.define("frame_test") { poll_each_frame { $frame_log_ref << :tick } }
  PokeAccess::Keys.run_frame_pollers
  truthy "poll_each_frame registers and runs", $frame_log_ref.include?(:tick)
end

# The DSL's hook forwarders must pass an OPTIONS hash through, or a profile is a second-class citizen of the
# very API written for it: the core marks its own binds :optional wherever a method is legitimately absent on
# some build of a game, and a profile -- which meets far more of that variance than the core does -- could
# not, so its perfectly legitimate bind landed in Hooks.missing, the list whose entire value is that
# everything on it is a typo. The discriminating case is an absent METHOD on a PRESENT class: an absent
# class is silent for everyone, flag or no flag, so it would pass even with the options dropped. The
# non-optional bind at the end is the control: it proves these asserts fail for the right reason and that
# forwarding opts did not simply stop the binds from being attempted.
Suite.define("game api: a profile's hooks take the same options the core's do") do
  opt_target = Class.new { def present_one; :orig; end }
  Object.const_set(:ApiOptTarget, opt_target) unless Object.const_defined?(:ApiOptTarget)
  PokeAccess::Game.define("opts_profile") do
    after("ApiOptTarget",  :gone_after,  :optional => true) { |_i, _r, _a| }
    before("ApiOptTarget", :gone_before, :optional => true) { |_i, _a| }
    around("ApiOptTarget", :gone_around, :optional => true) { |_i, nxt, _a| nxt.call }
  end
  miss = PokeAccess::Hooks.missing
  falsy "an optional after on an absent method is not recorded as a typo", miss.include?("ApiOptTarget#gone_after")
  falsy "optional reaches before too", miss.include?("ApiOptTarget#gone_before")
  falsy "optional reaches around too", miss.include?("ApiOptTarget#gone_around")

  PokeAccess::Game.define("opts_profile") { after("ApiOptTarget", :typo_one) { |_i, _r, _a| } }
  truthy "and a bind WITHOUT the flag is still flagged as a typo",
         PokeAccess::Hooks.missing.include?("ApiOptTarget#typo_one")

  container = Class.new do
    def open_it(i); reader(i); :opened; end
    def reader(i); @i = i; :read; end
  end
  Object.const_set(:ApiContainerTarget, container) unless Object.const_defined?(:ApiContainerTarget)
  $api_read_ref = []
  PokeAccess::Game.define("opts_profile") do
    after("ApiContainerTarget", :reader) { |_i, _r, a| $api_read_ref << a[0] }
    after("ApiContainerTarget", :open_it, :hook_container => true) { |_i, _r, _a| }
  end
  eq "the container's original still returns its value", ApiContainerTarget.new.open_it(3), :opened
  eq "hook_container reaches the hook: the reader the opener drives still speaks", $api_read_ref, [3]

  present = []
  $api_present_ref = present
  PokeAccess::Game.define("opts_profile") do
    after("ApiOptTarget", :present_one, :optional => true) { |_i, r, _a| $api_present_ref << r }
  end
  eq "an optional bind on a method that DOES exist still binds", ApiOptTarget.new.present_one, :orig
  eq "and its body ran", present, [:orig]
end
