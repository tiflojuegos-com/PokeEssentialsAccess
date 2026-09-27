# core/input/remap.rb, the settings.ini key remapper, driven through the real Remap.update and Input hooks with only
# the OS keyboard (Keys::GAKS) and the engine's own answers scripted; the suites restore Config.rebinds themselves.
# Q and W are rebind targets; EXTRA_VK (numpad 0) is the raw virtual-key a game extra reads.
module PaRemapRig
  Q = 0x51
  W = 0x57
  EXTRA_VK = 0x60
  HOOKED = [:trigger?, :press?, :repeat?, :triggerex?, :pressex?]

  # The scripted world: the keys held down, the engine's own answer, and frames of the real Remap.update.
  class Scripted
    attr_reader :down
    attr_accessor :engine

    def initialize; @down = []; @engine = false; end

    # Scripts the physically held virtual-keys (replacing whatever was held).
    def hold(*vks); @down.replace(vks); self; end

    # Advances n frames of the real per-frame poll (default one).
    def frames(n = 1); n.times { PokeAccess::Remap.update }; self; end
  end

  # Runs the block with the OS keyboard and the engine's originals scripted, restoring all it touched; the Input
  # aliases are saved by alias, as they are the engine's only handle on its own methods.
  def self.with_scripted_input
    rig = Scripted.new
    gaks = PokeAccess::Keys::GAKS
    cfg = PokeAccess::Config
    saved = [cfg.rebinds, cfg.rebind_labels, PokeAccess::Remap.extras.dup]
    sc = (class << Input; self; end)
    gaks.define_singleton_method(:call) { |vk| rig.down.include?(vk) ? 0x8000 : 0 }
    HOOKED.each do |m|
      ali = "#{m.to_s.chomp('?')}__access_orig".to_sym
      next unless sc.method_defined?(ali)
      sc.send(:alias_method, "pa_spec_saved_#{ali}".to_sym, ali)
      sc.send(:define_method, ali) { |*_a| rig.engine }
    end
    yield rig
  ensure
    cfg.rebinds = {}
    (PokeAccess::Remap.update rescue nil)
    HOOKED.each do |m|
      ali = "#{m.to_s.chomp('?')}__access_orig".to_sym
      keep = "pa_spec_saved_#{ali}".to_sym
      next unless sc.method_defined?(keep)
      sc.send(:alias_method, ali, keep)
      sc.send(:remove_method, keep)
    end
    (gaks.singleton_class.send(:remove_method, :call) rescue nil)
    cfg.rebinds = saved[0]
    cfg.rebind_labels = saved[1]
    PokeAccess::Remap.extras.replace(saved[2])
  end
end

# The button table and the controls menu list (base buttons, game extras, the mod's keys, reset-all); building the
# list never grows BUTTONS (a fangame's Array#+ mutates in place).
Suite.define("remap: the button table and the menu list built from it") do
  saved_extras = PokeAccess::Remap.extras.dup
  begin
    rows = PokeAccess::Remap::BUTTONS
    eq "BUTTONS carries the twelve RPG Maker buttons and the engine's Alt", rows.length, 13
    falsy "every row names an Input constant that resolves",
          rows.any? { |r| (Input.const_get(r[1]) rescue nil).nil? }
    falsy "every row carries a label key", rows.any? { |r| r[2].nil? }
    eq "the four movement actions are the ones DIR_CODE protects",
       PokeAccess::Remap::DIR_CODE.keys.map { |s| s.to_s }.sort, %w[down left right up]

    eq "the accept action resolves to Input::C", PokeAccess::Remap.btn_int_map[:c], Input::C
    eq "and the reverse lookup gets back to it", PokeAccess::Remap.sym_for_button(Input::C), :c
    eq "an Input integer no row claims maps to no action", PokeAccess::Remap.sym_for_button(9999), nil

    before = rows.length
    PokeAccess::Remap.extras.clear
    PokeAccess::Remap.register_extra(:pa_spec_extra, PaRemapRig::EXTRA_VK, :btn_x)
    list = PokeAccess::Remap.buttons
    mods = PokeAccess::Remap::MOD_KEYS.length
    eq "the list is base + extras + the mod's own keys + reset-all", list.length, before + 1 + mods + 1
    eq "it opens with the base table, in order",
       list[0, before].map { |r| r[0] }, rows.map { |r| r[0] }
    eq "the registered extra follows the base buttons", list[before][0], :pa_spec_extra
    eq "the mod's own hotkeys come next", list[before + 1][0], PokeAccess::Remap::MOD_KEYS[0][0]
    eq "and the reset-all entry closes it", list.last[0], :__reset__

    missing =PokeAccess::Remap::MOD_KEYS.map { |s, _l| s }.reject { |s| PokeAccess::Config::KEY_DEFAULTS.has_key?(s) }
    eq "every offered mod key exists in the key table", missing, []
    eq "the menu offers ALL of them, none left unreachable",
       PokeAccess::Remap::MOD_KEYS.length, PokeAccess::Config::KEY_DEFAULTS.length
    falsy "and each row carries a label key", PokeAccess::Remap::MOD_KEYS.any? { |_s, l| l.nil? }
    PokeAccess::Remap.buttons
    PokeAccess::Remap.buttons
    eq "building the list never grows the BUTTONS constant (Array#+ trap)", rows.length, before

    eq "sym_for_extra finds the action registered for a raw key",
       PokeAccess::Remap.sym_for_extra(PaRemapRig::EXTRA_VK), :pa_spec_extra
    eq "and answers nothing for a raw key no extra claims",
       PokeAccess::Remap.sym_for_extra(PaRemapRig::EXTRA_VK + 1), nil
  ensure
    PokeAccess::Remap.extras.replace(saved_extras)
  end
end

# label(): a row's i18n string, a per-game relabel over it, an extra's registered label; an action in no table is its
# own name, never a raise.
Suite.define("remap: labels resolve through i18n, per-game relabels win, unknown actions never raise") do
  cfg = PokeAccess::Config
  saved_labels = cfg.rebind_labels
  saved_extras = PokeAccess::Remap.extras.dup
  begin
    cfg.rebind_labels = {}
    eq "a known row labels with its own i18n key",
       PokeAccess::Remap.label(:c), PokeAccess::I18n.t(:btn_accept)
    falsy "the label is the translated string, not the raw key",
          PokeAccess::Remap.label(:c) == "btn_accept"
    falsy "two different rows do not share a label",
          PokeAccess::Remap.label(:c) == PokeAccess::Remap.label(:b)

    cfg.rebind_labels = { :c => :btn_cancel }
    eq "a per-game relabel overrides the row's own key",
       PokeAccess::Remap.label(:c), PokeAccess::I18n.t(:btn_cancel)
    cfg.rebind_labels = { :c => "Vial" }
    eq "a per-game relabel given as literal text is spoken verbatim", PokeAccess::Remap.label(:c), "Vial"
    cfg.rebind_labels = {}
    eq "dropping the relabel restores the default label",
       PokeAccess::Remap.label(:c), PokeAccess::I18n.t(:btn_accept)

    PokeAccess::Remap.register_extra(:pa_spec_extra, PaRemapRig::EXTRA_VK, :btn_x)
    eq "an extra labels with what it registered",
       PokeAccess::Remap.label(:pa_spec_extra), PokeAccess::I18n.t(:btn_x)

    eq "an action in no table degrades to its own name instead of raising",
       PokeAccess::Remap.label(:pa_no_such_action), "pa_no_such_action"
    falsy "no entry of the menu list labels as nil or empty (the menu speaks every row)",
          PokeAccess::Remap.buttons.any? { |r| PokeAccess::Remap.label(r[0]).to_s.empty? }
  ensure
    cfg.rebind_labels = saved_labels
    PokeAccess::Remap.extras.replace(saved_extras)
  end
end

# The suppression rule through the real Input hooks: an unbound button answers engine or mod, a rebound one the mod
# alone (its default key goes quiet).
Suite.define("remap: a rebound button answers from the mod alone, an unbound one from engine OR mod") do
  PaRemapRig.with_scripted_input do |rig|
    cfg = PokeAccess::Config
    truthy "the keyboard probe the module needs is present", PokeAccess::Keys::GAKS ? true : false

    cfg.rebinds = {}
    rig.hold.frames
    falsy "with no rebinds the accept button is not remapped",
          PokeAccess::Remap.remapped_button?(Input::C)
    rig.engine = false
    falsy "unbound and the engine silent: not triggered", Input.trigger?(Input::C)
    rig.engine = true
    truthy "unbound and the engine pressed: triggered (engine OR mod)", Input.trigger?(Input::C)

    cfg.rebinds = { :c => PaRemapRig::Q }
    rig.hold.frames
    truthy "a bound non-direction button reports as remapped",
           PokeAccess::Remap.remapped_button?(Input::C)
    falsy "an unbound button is not remapped just because another one is",
          PokeAccess::Remap.remapped_button?(Input::B)
    rig.engine = true
    falsy "REBOUND: the engine's default key is ignored while the bound key is up",
          Input.trigger?(Input::C)
    falsy "the same suppression applies to press?", Input.press?(Input::C)
    falsy "and to repeat?", Input.repeat?(Input::C)
    truthy "the button that was NOT rebound still answers the engine", Input.trigger?(Input::B)

    rig.engine = false
    rig.hold(PaRemapRig::Q).frames
    truthy "the bound key alone triggers the action", Input.trigger?(Input::C)
    truthy "and presses it", Input.press?(Input::C)
    truthy "repeat? fires on the press frame", Input.repeat?(Input::C)
    rig.frames
    falsy "trigger? is edge-only: a second held frame does not re-trigger", Input.trigger?(Input::C)
    truthy "press? stays true while the key is held", Input.press?(Input::C)
    falsy "repeat? waits out the repeat delay", Input.repeat?(Input::C)
    rig.frames(19)
    truthy "repeat? fires again once delay + interval have elapsed", Input.repeat?(Input::C)
    rig.hold.frames
    falsy "releasing the key clears the held state", PokeAccess::Remap.pressed_sym?(:c)
  end
end

# The engine's Alt (Input::ALT, which turbo scripts read and F1 cannot move) rebinds like a button: once bound,
# physical Alt goes quiet.
Suite.define("remap: the engine's Alt follows a rebind like any button, so a turbo read from Input::ALT moves with it") do
  PaRemapRig.with_scripted_input do |rig|
    cfg = PokeAccess::Config
    eq "Alt sits in the base table", PokeAccess::Remap.sym_for_button(Input::ALT), :alt
    truthy "with a spoken label of its own", PokeAccess::I18n.t(:btn_alt) != "btn_alt"
    eq "which the menu resolves", PokeAccess::Remap.label(:alt), PokeAccess::I18n.t(:btn_alt)

    cfg.rebinds = {}
    rig.hold.frames
    rig.engine = true
    truthy "unbound, physical Alt still reaches the game", Input.trigger?(Input::ALT)

    cfg.rebinds = { :alt => PaRemapRig::Q }
    rig.hold.frames
    truthy "bound, Alt reports as remapped", PokeAccess::Remap.remapped_button?(Input::ALT)
    rig.engine = true
    falsy "and physical Alt goes quiet", Input.trigger?(Input::ALT)
    rig.engine = false
    rig.hold(PaRemapRig::Q).frames
    truthy "the chosen key toggles what the game reads as Alt", Input.trigger?(Input::ALT)
    truthy "and holds it", Input.press?(Input::ALT)
    rig.hold.frames
    falsy "released, nothing stays down", PokeAccess::Remap.pressed_sym?(:alt)
  end
end

# A rebound direction stays additive (the arrow key still moves the player), and no binding change leaves a key held.
Suite.define("remap: directions stay additive and no binding change leaves a key stuck") do
  PaRemapRig.with_scripted_input do |rig|
    cfg = PokeAccess::Config
    cfg.rebinds = { :down => PaRemapRig::Q }
    rig.hold.frames
    falsy "a rebound DIRECTION is never reported as remapped",
          PokeAccess::Remap.remapped_button?(Input::DOWN)
    rig.engine = true
    truthy "so the engine's own arrow key still moves the player", Input.press?(Input::DOWN)

    rig.engine = false
    eq "no bound movement key held: no direction", PokeAccess::Remap.dir, 0
    eq "and dir4 reports none", Input.dir4, 0
    rig.hold(PaRemapRig::Q).frames
    eq "the bound key yields its 4-direction code", PokeAccess::Remap.dir, 2
    eq "and dir4 falls back to it when the engine reports none", Input.dir4, 2
    rig.hold.frames
    eq "releasing it returns dir to none", PokeAccess::Remap.dir, 0

    cfg.rebinds = { :c => PaRemapRig::Q, :b => PaRemapRig::W }
    rig.hold(PaRemapRig::Q, PaRemapRig::W).frames
    truthy "both bound keys register as held", PokeAccess::Remap.pressed_sym?(:c)
    truthy "the second one too", PokeAccess::Remap.pressed_sym?(:b)
    cfg.rebinds = { :b => PaRemapRig::W }
    rig.frames
    falsy "dropping ONE binding releases only that action", PokeAccess::Remap.pressed_sym?(:c)
    truthy "the surviving binding stays held", PokeAccess::Remap.pressed_sym?(:b)
    cfg.rebinds = {}
    rig.frames
    falsy "clearing every binding releases everything (no key left walking)",
          PokeAccess::Remap.pressed_sym?(:b)
    falsy "and with no bindings a physically held key means nothing to the mod",
          PokeAccess::Remap.pressed_sym?(:c)
  end
end

# Game extras, read by raw virtual-key (Input.triggerex?), rebind and suppress like the base buttons.
Suite.define("remap: a rebound game extra takes over its raw virtual-key") do
  PaRemapRig.with_scripted_input do |rig|
    cfg = PokeAccess::Config
    vk = PaRemapRig::EXTRA_VK
    PokeAccess::Remap.extras.clear
    PokeAccess::Remap.register_extra(:pa_spec_extra, vk, :btn_x)

    cfg.rebinds = {}
    rig.hold.frames
    falsy "an unbound extra is not remapped", PokeAccess::Remap.extra_remapped?(vk)
    rig.engine = true
    truthy "so the game's own raw key still fires it", Input.triggerex?(vk)

    cfg.rebinds = { :pa_spec_extra => PaRemapRig::Q }
    rig.hold.frames
    truthy "a bound extra reports as remapped", PokeAccess::Remap.extra_remapped?(vk)
    falsy "a raw key no extra claims is never remapped", PokeAccess::Remap.extra_remapped?(vk + 1)
    rig.engine = true
    falsy "REBOUND: the game's original raw key goes silent", Input.triggerex?(vk)
    falsy "pressex? is suppressed too", Input.pressex?(vk)

    rig.engine = false
    rig.hold(PaRemapRig::Q).frames
    truthy "the bound key triggers the extra", Input.triggerex?(vk)
    truthy "and presses it", Input.pressex?(vk)
    falsy "while a raw key belonging to no extra stays false", Input.triggerex?(vk + 1)
  end
end

# A game extra still on the raw key the game reads it by owns that key: giving it to another action would make one
# press do both (Reminiscencia's S, its help and its tabs, under a key bound to "down"); once the extra moves, the
# key is free.
Suite.define("remap: a game extra keeps its own raw key until it is rebound") do
  rb = PokeAccess::Config.rebinds
  keys = PokeAccess::Config.keys
  saved = PokeAccess::Remap.extras.dup
  begin
    PokeAccess::Remap.extras.clear
    PokeAccess::Remap.register_extra(:pa_spec_help, 0x53, :btn_x)
    PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup
    PokeAccess::Config.rebinds = {}
    eq "a game button cannot take the extra's key", PokeAccess::Remap.conflict(0x53, :down), :pa_spec_help
    eq "nor a mod key", PokeAccess::Remap.conflict(0x53, :hp), :pa_spec_help
    eq "the extra itself may stay on it", PokeAccess::Remap.conflict(0x53, :pa_spec_help), nil
    PokeAccess::Config.rebinds = { :pa_spec_help => 0x32 }
    eq "moved elsewhere, its old key is free", PokeAccess::Remap.conflict(0x53, :down), nil
    eq "and its new key is taken as any binding is", PokeAccess::Remap.conflict(0x32, :down), :pa_spec_help
  ensure
    PokeAccess::Remap.extras.replace(saved)
    PokeAccess::Config.rebinds = rb
    PokeAccess::Config.keys = keys
  end
end

# Remap.conflict, one check over both key tables (the mod's hotkeys and the game's rebinds) and the engine's reserved
# keys.
Suite.define("remap: one collision check guards BOTH key tables and the engine's own keys") do
  rb   = PokeAccess::Config.rebinds
  keys = PokeAccess::Config.keys
  begin
    PokeAccess::Config.rebinds = { :c => 0x5A }                     # the game's accept on Z
    PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup  # info on T (0x54)

    eq "a free key is free", PokeAccess::Remap.conflict(0x51, :info), nil
    eq "a key already taken by ANOTHER MOD action is refused",
       PokeAccess::Remap.conflict(0x48, :info), :hp
    eq "a key already taken by a GAME button is refused for a mod action",
       PokeAccess::Remap.conflict(0x5A, :info), :c
    eq "and the reverse: a mod key is refused for a game button (the hole this closes)",
       PokeAccess::Remap.conflict(0x54, :c), :info
    eq "rebinding an action to the key it already has is not a conflict",
       PokeAccess::Remap.conflict(0x54, :info), nil
    eq "a modifier's key is refused like any other, so shift+info cannot be broken",
       PokeAccess::Remap.conflict(0x10, :info), :shift

    eq "the engine's Enter is not ours to give away",
       PokeAccess::Remap.conflict(0x0D, :info), :rmp_key_enter
    eq "nor the arrows", PokeAccess::Remap.conflict(0x26, :next), :rmp_key_up
    eq "nor the mod's own on/off gesture, the way back from a bad binding",
       PokeAccess::Remap.conflict(0x77, :info), :rmp_key_f8
    eq "a reserved key stays reserved even for the action that would want it",
       PokeAccess::Remap.conflict(0x1B, :config), :rmp_key_escape

    eq "no code, no conflict", PokeAccess::Remap.conflict(nil, :info), nil
    truthy "the mod's own actions are told apart from the game's",
           PokeAccess::Remap.mod_action?(:info) && !PokeAccess::Remap.mod_action?(:c)
  ensure
    PokeAccess::Config.rebinds = rb
    PokeAccess::Config.keys = keys
  end
end
