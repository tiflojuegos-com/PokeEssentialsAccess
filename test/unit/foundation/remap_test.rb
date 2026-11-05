# The key remapper (core/input/remap.rb): the controls menu's list, labels and collision check over both key tables,
# and a rebound key reaching the game through the Input hooks, with the keyboard and the engine's answers scripted.
class RemapTest < PokeAccessTest
  Remap = PokeAccess::Remap
  REMAP_FILE = File.join(Harness::ROOT, "core", "input", "remap.rb")
  Q = 0x51
  W = 0x57
  E = 0x45
  R = 0x52
  ALT = PokeAccess::Keyboard::VK_ALT
  LETTER = 0x4D
  EXTRA_VK = 0x60
  OTHER_VK = 0x61
  BUTTON_HOOKS = [:trigger?, :press?, :repeat?]
  EXTRA_HOOKS = [:triggerex?, :pressex?]
  ENGINE_KEYS = [:trigger__access_orig, :press__access_orig, :repeat__access_orig, :triggerex__access_orig,
                 :pressex__access_orig]
  ENGINE_DIRS = [:dir4__access_orig, :dir8__access_orig]
  QUERIES = [:triggered?, :pressed?, :repeated?, :extra_triggered?, :extra_pressed?]

  # What the scripted keyboard holds down and what the engine's own Input answers: its button and raw-key queries,
  # its direction, and the arguments each of its direction calls got.
  Scripted = Struct.new(:down, :engine, :dir, :dir_args)

  test "lists the base buttons, the game extras as registered, the mod's keys and a reset-all entry" do
    with_extras([:pa_test_b, OTHER_VK, :btn_y], [:pa_test_a, EXTRA_VK, :btn_x]) do
      want = Remap::BUTTONS + [[:pa_test_b, nil, :btn_y], [:pa_test_a, nil, :btn_x]] +
             Remap::MOD_KEYS.map { |sym, label| [sym, nil, label] } + [[:__reset__, nil, :btn_reset_all]]
      assert_equal want, Remap.buttons
    end
  end

  test "opens the list with the twelve RPG Maker buttons and the engine's Alt" do
    assert_equal [:down, :left, :right, :up, :c, :b, :a, :x, :y, :z, :l, :r, :alt],
                 Remap.buttons.first(13).map { |row| row[0] }
  end

  test "building the list twice leaves the base table as it was" do
    before = Remap::BUTTONS.map { |row| row.dup }
    Remap.buttons
    Remap.buttons
    assert_equal before, Remap::BUTTONS
  end

  test "offers every hotkey of the mod, and only those" do
    assert_equal PokeAccess::Config::KEY_DEFAULTS.keys.sort, Remap::MOD_KEYS.map { |sym, _label| sym }.sort
  end

  test "has a spoken translation for the label of every entry of the list" do
    with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
      unspoken = Remap.buttons.map { |row| row[2] }.select do |key|
        PokeAccess::I18n.t(key) == key.to_s || PokeAccess::I18n.t(key).strip.empty?
      end
      assert_equal [], unspoken
    end
  end

  test "an extra registered again keeps one row, with its new key and label, and moves to the end of the list" do
    with_extras([:pa_test_a, EXTRA_VK, :btn_x], [:pa_test_b, OTHER_VK, :btn_y]) do
      Remap.register_extra(:pa_test_a, 0x62, :btn_z)
      assert_equal [[:pa_test_b, OTHER_VK, :btn_y], [:pa_test_a, 0x62, :btn_z]], Remap.extras
    end
  end

  test "finds the action of each base button's Input integer" do
    Remap::BUTTONS.each do |sym, const, _label|
      assert_equal sym, Remap.sym_for_button(Input.const_get(const)), "Input::#{const}"
    end
  end

  test "finds no action for an Input integer no base button has" do
    assert_nil Remap.sym_for_button(Input::CTRL)
  end

  test "an engine's Input that lacks a base button leaves it out and still finds the others" do
    without_input_constant(:ALT) do |alt|
      assert_equal [:c, nil], [Remap.sym_for_button(Input::C), Remap.sym_for_button(alt)]
    end
  end

  test "finds the extra registered for a raw key, and none for a key no extra claims" do
    with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
      assert_equal [:pa_test_a, nil], [Remap.sym_for_extra(EXTRA_VK), Remap.sym_for_extra(OTHER_VK)]
    end
  end

  test "finds an extra by how the game reads it, by name or by code, and none another way" do
    with_extras([:pa_test_a, :M, :btn_x], [:pa_test_b, EXTRA_VK, :btn_y]) do
      assert_equal [:pa_test_a, nil, nil, :pa_test_b],
                   [Remap.sym_for_extra(:M), Remap.sym_for_extra(LETTER), Remap.sym_for_extra(:N), Remap.sym_for_extra(EXTRA_VK)]
    end
  end

  test "an extra read as a button of the game's Input answers for that button and for its raw key, a constant it lacks for none" do
    Input.const_set(:PA_TEST_BUTTON, 977) unless Input.const_defined?(:PA_TEST_BUTTON)
    with_extras do
      Remap.register_extra(:pa_test_a, LETTER, :btn_x, :PA_TEST_BUTTON)
      Remap.register_extra(:pa_test_b, OTHER_VK, :btn_y, :PA_NOT_IN_THE_GAME)
      assert_equal [:pa_test_a, :pa_test_a, :pa_test_b],
                   [Remap.sym_for_button(977), Remap.sym_for_extra(LETTER), Remap.sym_for_extra(OTHER_VK)]
      Remap.register_extra(:pa_test_a, LETTER, :btn_x)
      assert_equal [nil, :pa_test_a], [Remap.sym_for_button(977), Remap.sym_for_extra(LETTER)]
    end
  ensure
    Remap.extra_buttons.clear
    Remap.instance_variable_set(:@button_extras, nil)
  end

  test "tells the mod's own hotkeys from the game's buttons and extras" do
    with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
      { :info => true, :hp => true, :shift => true, :verbosity => true,
        :c => false, :alt => false, :pa_test_a => false, :__reset__ => false }.each do |sym, mine|
        assert_equal mine, Remap.mod_action?(sym), sym.inspect
      end
    end
  end

  test "labels each entry of the list with its own translation" do
    with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
      Remap.buttons.each { |sym, _const, key| assert_equal PokeAccess::I18n.t(key), Remap.label(sym), sym.inspect }
    end
  end

  test "gives every entry of the list a label no other entry has, in every language" do
    with_extras do
      PokeAccess::I18n.available_languages.each do |code|
        PokeAccess::Config.language = code
        labels = Remap.buttons.map { |row| Remap.label(row[0]) }
        assert_equal [], labels.select { |label| labels.count(label) > 1 }.uniq, code.inspect
      end
    end
  end

  test "labels a button with the game's relabel given as a translation key" do
    PokeAccess::Config.rebind_labels = { :c => :btn_cancel }
    assert_equal PokeAccess::I18n.t(:btn_cancel), Remap.label(:c)
  end

  test "says a game's relabel given as text as it is written" do
    PokeAccess::Config.rebind_labels = { :x => "Pokevial" }
    assert_equal "Pokevial", Remap.label(:x)
  end

  test "labels an action no table has with its own name" do
    assert_equal "pa_no_such_action", Remap.label(:pa_no_such_action)
  end

  test "finds a key no action uses free" do
    assert_nil Remap.conflict(Q, :info)
  end

  test "finds no conflict without a key" do
    assert_nil Remap.conflict(nil, :info)
  end

  test "a key one of the mod's hotkeys uses is taken by it, for another hotkey or a game button" do
    { [0x48, :info] => :hp, [0x10, :info] => :shift, [0x54, :c] => :info }.each do |(vk, action), holder|
      assert_equal holder, Remap.conflict(vk, action), "key 0x#{vk.to_s(16)} for #{action}"
    end
  end

  test "a key a game button is rebound to is taken by that button" do
    PokeAccess::Config.rebinds = { :c => 0x5A }
    assert_equal [:c, :c], [Remap.conflict(0x5A, :info), Remap.conflict(0x5A, :b)]
  end

  test "an action's own key is no conflict for it" do
    with_extras([:pa_test_help, 0x53, :btn_x]) do
      PokeAccess::Config.rebinds = { :c => 0x5A }
      assert_equal [nil, nil, nil],
                   [Remap.conflict(0x54, :info), Remap.conflict(0x5A, :c), Remap.conflict(0x53, :pa_test_help)]
    end
  end

  test "a game extra still on its raw key holds it against buttons and hotkeys" do
    with_extras([:pa_test_help, 0x53, :btn_x]) do
      assert_equal [:pa_test_help, :pa_test_help], [Remap.conflict(0x53, :down), Remap.conflict(0x53, :hp)]
    end
  end

  test "an extra rebound elsewhere frees its raw key and holds the new one" do
    with_extras([:pa_test_help, 0x53, :btn_x]) do
      PokeAccess::Config.rebinds = { :pa_test_help => 0x32 }
      assert_equal [nil, :pa_test_help], [Remap.conflict(0x53, :down), Remap.conflict(0x32, :down)]
    end
  end

  test "refuses the engine's and the mod's reserved keys to every action, naming what holds them" do
    { 0x0D => :rmp_key_enter, 0x1B => :rmp_key_escape, 0x20 => :rmp_key_space, 0x25 => :rmp_key_left,
      0x26 => :rmp_key_up, 0x27 => :rmp_key_right, 0x28 => :rmp_key_down, 0x70 => :rmp_key_f1, 0x71 => :rmp_key_f2,
      0x7B => :rmp_key_f12, 0x77 => :rmp_key_f8, 0x78 => :rmp_key_f9, 0x79 => :rmp_key_f10 }.each do |vk, holder|
      [:info, :config, :c].each do |action|
        assert_equal holder, Remap.conflict(vk, action), "key 0x#{vk.to_s(16)} for #{action}"
      end
    end
  end

  test "reports no rebinds for an empty table or none at all, and rebinds once a key is bound" do
    { {} => true, nil => true, { :c => Q } => false }.each do |table, want|
      PokeAccess::Config.rebinds = table
      assert_equal want, Remap.no_rebinds?, table.inspect
    end
  end

  test "with no rebinds, a button answers the engine's own key" do
    with_scripted_input do
      { true => true, false => false }.each do |engine, want|
        engine_answers(engine)
        poll
        BUTTON_HOOKS.each { |m| assert_equal want, Input.send(m, Input::C), "#{m} with the engine at #{engine}" }
      end
    end
  end

  test "a rebound button no longer answers the engine's own key" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      engine_answers(true)
      poll
      assert_equal [false, false, false], BUTTON_HOOKS.map { |m| Input.send(m, Input::C) }
    end
  end

  test "a button not rebound keeps the engine's own key while another is rebound" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      engine_answers(true)
      poll
      assert_equal [true, true, true], BUTTON_HOOKS.map { |m| Input.send(m, Input::B) }
    end
  end

  test "a button no base row has answers the engine alone" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      { true => true, false => false }.each do |engine, want|
        engine_answers(engine)
        poll
        BUTTON_HOOKS.each { |m| assert_equal want, Input.send(m, Input::CTRL), "#{m} with the engine at #{engine}" }
      end
    end
  end

  test "the bound key triggers its button on the frame it goes down, and only then" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      assert_equal [true, false, false], (1..3).map { poll; Input.trigger?(Input::C) }
    end
  end

  test "the bound key presses its button for as long as it is held" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      held = (1..3).map { poll; Input.press?(Input::C) }
      hold
      poll
      assert_equal [true, true, true, false], held + [Input.press?(Input::C)]
    end
  end

  test "on mkxp-z's input by frames the bound key repeats as the engine's keys do: on the press, then every 4 from the 16th" do
    on_engine([]) { assert_equal [1, 16, 20, 24, 28, 32, 36, 40], held_repeats(40) }
    on_engine([2, 1]) { assert_equal [1, 16, 20, 24, 28, 32, 36, 40], held_repeats(40) }
  end

  test "where the game reads its keys in Ruby, the bound key repeats as they do: on the press, then on even frames past the 20th" do
    on_engine([2, 4, 2], [0, false], true) { assert_equal [1, 22, 24, 26, 28, 30], held_repeats(30) }
  end

  test "from mkxp-z 2.1.1 the bound key repeats by time, 0.4 s then every 0.1 s, at the rate the engine's input counts by" do
    want = { [0, false, 40] => [1, 20, 24, 28, 32, 36, 40], [0, false, 60] => [1, 30, 36],
             [60, false, 40] => [1, 30, 36], [0, true, 60] => [1, 20, 24, 28, 32, 36, 40], [0, false, 50] => [1, 24, 30, 36] }
    said = want.keys.map { |fixed, synced, rate| on_engine([2, 1, 1], [fixed, synced], false, rate) { held_repeats(40) } }
    assert_equal want.values, said
  end

  test "reads mkxp-z's version from the engine's System::VERSION, and none from an engine without it" do
    Remap.instance_variable_set(:@mkxp_version, nil)
    none = Remap.mkxp_version
    Remap.instance_variable_set(:@mkxp_version, nil)
    defined = Object.const_defined?(:System)
    Object.const_set(:System, Module.new) unless defined
    System.const_set(:VERSION, "2.4.2")
    assert_equal [[], [2, 4, 2]], [none, Remap.mkxp_version]
  ensure
    System.send(:remove_const, :VERSION) if Object.const_defined?(:System) && System.const_defined?(:VERSION, false)
    Object.send(:remove_const, :System) if Object.const_defined?(:System) && !defined
    Remap.instance_variable_set(:@mkxp_version, nil)
  end

  test "an mkxp-z 2.2 whose System::VERSION reads MKXPZ_VERSION is told from 2.1 by its System::CONFIG, and repeats by time" do
    defined = Object.const_defined?(:System)
    Object.const_set(:System, Module.new) unless defined
    System.const_set(:VERSION, "MKXPZ_VERSION")
    said = [false, true].map do |config|
      System.const_set(:CONFIG, {}) if config
      Remap.instance_variable_set(:@mkxp_version, nil)
      [Remap.mkxp_version, on_engine(nil, [0, false], false, 40) { held_repeats(24) }]
    end
    assert_equal [[[], [1, 16, 20, 24]], [[2, 2], [1, 20, 24]]], said
  ensure
    [:VERSION, :CONFIG].each { |c| System.send(:remove_const, c) if Object.const_defined?(:System) && System.const_defined?(c, false) }
    Object.send(:remove_const, :System) if Object.const_defined?(:System) && !defined
    Remap.instance_variable_set(:@mkxp_version, nil)
  end

  test "while Ctrl and Alt are held for one of the mod's gestures, the game reads its Alt and F8 as up" do
    with_scripted_input do
      with_f8 do
        kb = PokeAccess::Keyboard
        engine_answers(true)
        hold(kb::VK_CONTROL, kb::VK_ALT)
        poll
        chord = [Input::ALT, Input::F8].map { |b| BUTTON_HOOKS.map { |m| Input.send(m, b) } }
        hold(kb::VK_ALT)
        poll
        assert_equal [[[false] * 3] * 2, true], [chord, Input.trigger?(Input::ALT)]
      end
    end
  end

  test "of two bound directions held, the one pressed last leads, as the engine's dir4 has it" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :right => Q, :up => W }
      hold(Q)
      poll
      hold(Q, W)
      poll
      up = Input.dir4
      hold(W)
      poll
      hold(W, Q)
      poll
      assert_equal [8, 6], [up, Input.dir4]
    end
  end

  test "the engine's Alt, which turbo scripts read, follows its rebind like any button" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :alt => Q }
      engine_answers(true)
      poll
      engine_alt = Input.press?(Input::ALT)
      engine_answers(false)
      hold(Q)
      poll
      assert_equal [false, true], [engine_alt, Input.press?(Input::ALT)]
    end
  end

  test "a rebound direction keeps the engine's arrow key" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :down => Q }
      engine_answers(true)
      poll
      assert_equal [true, true, true], BUTTON_HOOKS.map { |m| Input.send(m, Input::DOWN) }
    end
  end

  test "a rebound direction answers its bound key too, as the menus read it to move the cursor" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :down => Q }
      engine_answers(false)
      hold(Q)
      poll
      assert_equal [true, true, true], BUTTON_HOOKS.map { |m| Input.send(m, Input::DOWN) }
    end
  end

  test "each bound direction steers dir4 and dir8 while the engine gives none" do
    with_scripted_input do
      hold(Q)
      { :down => 2, :left => 4, :right => 6, :up => 8 }.each do |dir, code|
        PokeAccess::Config.rebinds = { dir => Q }
        poll
        assert_equal [code, code], [Input.dir4, Input.dir8], dir.inspect
      end
    end
  end

  test "the engine's own direction wins over a bound one" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :down => Q }
      hold(Q)
      poll
      engine_dir(6)
      assert_equal [6, 6], [Input.dir4, Input.dir8]
    end
  end

  test "with no bound direction held, dir4 and dir8 give the engine's none" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :down => Q }
      poll
      assert_equal [0, 0], [Input.dir4, Input.dir8]
    end
  end

  test "bound directions pressed on the same frame resolve down first, then left, then right, then up" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :up => Q, :left => W, :right => E, :down => R }
      { [Q, W] => 4, [Q, E] => 6, [W, R] => 2, [E, W] => 4, [Q, W, E, R] => 2 }.each do |keys, code|
        hold
        poll
        hold(*keys)
        poll
        assert_equal code, Input.dir4, keys.inspect
      end
    end
  end

  test "hands the engine's dir4 and dir8 the arguments the game passes" do
    with_scripted_input do
      Input.dir4(:sky)
      Input.dir8(:sky)
      assert_equal [[:sky], [:sky]], @rig.dir_args
    end
  end

  test "dropping one binding releases only its button" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q, :b => W }
      hold(Q, W)
      poll
      PokeAccess::Config.rebinds = { :b => W }
      poll
      assert_equal [false, true], [Input.press?(Input::C), Input.press?(Input::B)]
    end
  end

  test "clearing every binding releases every button" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q, :b => W }
      hold(Q, W)
      poll
      PokeAccess::Config.rebinds = {}
      poll
      assert_equal [false, false], [Input.press?(Input::C), Input.press?(Input::B)]
    end
  end

  test "a binding without a key leaves its button on the engine's own key" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => nil }
      engine_answers(true)
      poll
      assert_equal true, Input.trigger?(Input::C)
    end
  end

  test "with no rebind table at all, a frame holds nothing and the engine answers" do
    with_scripted_input do
      PokeAccess::Config.rebinds = nil
      hold(Q)
      { true => true, false => false }.each do |engine, want|
        engine_answers(engine)
        poll
        assert_equal want, Input.trigger?(Input::C), "with the engine at #{engine}"
      end
    end
  end

  test "switching the mod off releases a held bound key" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      poll
      held = Input.press?(Input::C)
      with_mod_off { poll }
      assert_equal [true, false], [held, Input.press?(Input::C)]
    end
  end

  test "a frame with another window in front releases a held bound key" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      poll
      held = Input.press?(Input::C)
      in_background { poll }
      assert_equal [true, false], [held, Input.press?(Input::C)]
    end
  end

  test "a bound key still answers while the mod's switch or the focus check fails" do
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      [:enabled, :focused?].each do |check|
        hold
        poll
        hold(Q)
        failing(PokeAccess::Keys, check) { poll }
        assert_equal true, Input.press?(Input::C), "with #{check} failing"
      end
    end
  end

  test "while the mod is off or out of focus, a rebound button and extra answer the game's own keys" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :c => Q, :pa_test_a => W }
        engine_answers(true)
        [:with_mod_off, :in_background].each do |condition|
          send(condition) do
            poll
            assert_equal [true, true], [Input.trigger?(Input::C), Input.triggerex?(EXTRA_VK)], condition.to_s
          end
        end
      end
    end
  end

  test "an extra shipped on Alt answers Alt then its key, once, and no longer its key alone" do
    with_shipped_extra do
      engine_answers(true)
      [[[LETTER], false], [[], false], [[ALT], false], [[ALT, LETTER], true], [[ALT, LETTER], false]].each do |keys, want|
        key_frame(*keys)
        assert_equal want, Input.triggerex?(:M), keys.inspect
      end
      assert_equal true, Input.pressex?(:M)
    end
  end

  test "an extra shipped on no key answers nothing, its game's key neither, and holds no key" do
    with_shipped_extra(:pa_test_a => "None") do
      engine_answers(true)
      2.times { key_frame(LETTER) }
      assert_equal [false, false], [Input.triggerex?(:M), Input.pressex?(:M)]
      assert_nil Remap.conflict(PokeAccess::Keyboard::NO_KEY, :c)
      assert_equal PokeAccess::I18n.t(:rmp_unassigned), PokeAccess::KeyHints.bound_name(:pa_test_a)
    end
  end

  test "an extra shipped on Alt alone counts while Alt is held, and no longer on its own key" do
    with_shipped_extra(:pa_test_a => "Alt") do
      engine_answers(true)
      key_frame(LETTER)
      assert_equal [false, false], [Input.triggerex?(:M), Input.pressex?(:M)]
      key_frame(ALT)
      assert_equal [true, true], [Input.triggerex?(:M), Input.pressex?(:M)]
      key_frame(ALT)
      assert_equal [false, true], [Input.triggerex?(:M), Input.pressex?(:M)]
      key_frame
      assert_equal false, Input.pressex?(:M)
    end
  end

  test "a row read as a button answers for its raw key too, so one key moves both reads" do
    Input.const_set(:PA_TEST_BUTTON, 977) unless Input.const_defined?(:PA_TEST_BUTTON)
    with_shipped_extra do
      Remap.register_extra(:pa_test_a, LETTER, :btn_x, :PA_TEST_BUTTON)
      engine_answers(true)
      key_frame(LETTER)
      assert_equal [false, false], [Input.press?(977), Input.pressex?(LETTER)]
      engine_answers(false)
      key_frame(ALT)
      key_frame(ALT, LETTER)
      assert_equal [true, true], [Input.trigger?(977), Input.triggerex?(LETTER)]
    end
  ensure
    Remap.extra_buttons.clear
    Remap.instance_variable_set(:@button_extras, nil)
  end

  test "in a text field a button read through a row is the game's, whatever its row is on" do
    Input.const_set(:PA_TEST_BUTTON, 977) unless Input.const_defined?(:PA_TEST_BUTTON)
    with_shipped_extra do
      Remap.register_extra(:pa_test_a, LETTER, :btn_x, :PA_TEST_BUTTON)
      engine_answers(true)
      key_frame(LETTER)
      assert_equal false, Input.press?(977), "out of a field it answers its row"
      PokeAccess::Keys.typing!
      assert_equal true, Input.press?(977), "in one, the game's key"
      engine_answers(false)
      key_frame(ALT, LETTER)
      assert_equal false, Input.press?(977), "and its row's key says nothing for it"
    end
  ensure
    Reset.reset_keys
    Remap.extra_buttons.clear
    Remap.instance_variable_set(:@button_extras, nil)
  end

  test "a game button shipped on Tab answers that alone, held while it is down, and Alt+Tab says nothing for it" do
    Input.const_set(:PA_TEST_BUTTON, 977) unless Input.const_defined?(:PA_TEST_BUTTON)
    tab = PokeAccess::Keyboard::VK_TAB
    with_shipped_extra(:pa_test_a => "Tab") do
      Remap.register_extra(:pa_test_a, LETTER, :btn_x, :PA_TEST_BUTTON)
      engine_answers(true)
      key_frame(LETTER)
      assert_equal false, Input.press?(977), "the key the game read before"
      engine_answers(false)
      key_frame(tab)
      assert_equal [true, true], [Input.trigger?(977), Input.press?(977)]
      key_frame(tab)
      assert_equal [false, true], [Input.trigger?(977), Input.press?(977)]
      key_frame
      key_frame(ALT, tab)
      assert_equal [false, false], [Input.trigger?(977), Input.press?(977)], "Alt+Tab switches windows"
    end
  ensure
    Remap.extra_buttons.clear
    Remap.instance_variable_set(:@button_extras, nil)
  end

  test "a mod's key on Tab says nothing for Alt+Tab" do
    tab = PokeAccess::Keyboard::VK_TAB
    with_shipped_extra do
      PokeAccess::Config.keys[:hp] = tab
      key_frame(ALT, tab)
      assert_equal false, PokeAccess::Keys.key(:hp)
      key_frame
      key_frame(tab)
      assert_equal true, PokeAccess::Keys.key(:hp)
    end
  end

  test "with an action on Alt plus a key the game's Alt reads one frame as it is let go, and not as it goes down" do
    with_shipped_extra do
      [[[ALT], true, false], [[ALT], true, false], [[], false, true], [[], false, false]].each do |keys, engine, want|
        engine_answers(engine)
        key_frame(*keys)
        reads = [Input.trigger?(Input::ALT), Input.press?(Input::ALT), Input.repeat?(Input::ALT)]
        assert_equal [want] * 3, reads, keys.inspect
      end
    end
  end

  test "a game that reads its Alt inside its own Input.update, before the pulse, sees the same single frame" do
    with_shipped_extra do
      reads = [[[ALT], true], [[ALT], true], [[], false], [[], false], [[], false]].map do |keys, engine|
        hold(*keys)
        engine_answers(engine)
        read = Input.trigger?(Input::ALT)
        PokeAccess::Keyboard.snapshot
        poll
        read
      end
      assert_equal [false, false, false, true, false], reads
    end
  end

  test "a tap too quick for any frame to see Alt down is still the engine's to answer" do
    with_shipped_extra do
      engine_answers(true)
      key_frame
      assert_equal true, Input.trigger?(Input::ALT)
    end
  end

  test "what is shipped steps aside while the player or a mod's key holds its key, and comes back" do
    code = PokeAccess::Keyboard.with_alt(LETTER)
    with_shipped_extra do
      assert_equal code, Remap.shipped(:pa_test_a)
      PokeAccess::Config.rebinds = { :pa_test_a => code }
      assert_equal code, Remap.shipped(:pa_test_a), "its own binding does not count"
      PokeAccess::Config.rebinds = { :x => code }
      assert_nil Remap.shipped(:pa_test_a), "the player's other binding"
      PokeAccess::Config.rebinds = {}
      PokeAccess::Config.keys[:hp] = code
      assert_nil Remap.shipped(:pa_test_a), "a mod's key"
      PokeAccess::Config.keys[:hp] = nil
      assert_equal code, Remap.shipped(:pa_test_a)
    end
  end

  test "an Alt let go in the mod's menu, where it picks a key, fires no game's Alt" do
    menu = PokeAccess::ConfigMenu.method(:active?)
    with_shipped_extra do
      begin
        PokeAccess::ConfigMenu.define_singleton_method(:active?) { true }
        key_frame(ALT)
        key_frame
        assert_equal false, Input.trigger?(Input::ALT)
      ensure
        PokeAccess::ConfigMenu.define_singleton_method(:active?, menu)
      end
    end
  end

  test "a combination read that way fires no Alt either" do
    with_shipped_extra do
      reads = [[[ALT], true], [[ALT, LETTER], true], [[], false], [[], false]].map do |keys, engine|
        hold(*keys)
        engine_answers(engine)
        read = Input.trigger?(Input::ALT)
        PokeAccess::Keyboard.snapshot
        poll
        read
      end
      assert_equal [false] * 4, reads
    end
  end

  test "what is shipped for the field takes no letter from the mod in a battle" do
    with_shipped_extra do
      Remap.ship({ :pa_test_a => "Alt+M" }, true)
      kept = PokeAccess::Battle.method(:in_battle?)
      begin
        PokeAccess::Battle.define_singleton_method(:in_battle?) { true }
        key_frame(ALT)
        Remap.code_pressed?(LETTER)
        key_frame(ALT, LETTER)
        assert_equal true, Remap.code_pressed?(LETTER)
      ensure
        PokeAccess::Battle.define_singleton_method(:in_battle?, kept)
      end
    end
  end

  test "an action on Alt plus a key keeps the game's Alt from answering as that Alt is let go, and the next Alt alone does" do
    with_shipped_extra do
      [[ALT], [ALT, LETTER], [ALT], []].each do |keys|
        key_frame(*keys)
        assert_equal false, Input.trigger?(Input::ALT), keys.inspect
      end
      key_frame(ALT)
      key_frame
      assert_equal true, Input.trigger?(Input::ALT)
    end
  end

  test "a mod's key on Alt plus a key keeps the game's Alt from answering too" do
    code = PokeAccess::Keyboard.with_alt(Q)
    with_shipped_extra do
      PokeAccess::Config.keys[:hp] = code
      [[[ALT], false], [[ALT, Q], true]].each do |keys, want|
        key_frame(*keys)
        assert_equal want, Remap.code_pressed?(code), keys.inspect
      end
      key_frame
      assert_equal false, Input.trigger?(Input::ALT)
    end
  end

  test "letting go a Ctrl+Alt gesture or AltGr fires no game's Alt" do
    ctrl = PokeAccess::Keyboard::VK_CONTROL
    with_shipped_extra do
      [[ALT, ctrl], [ALT], []].each do |keys|
        key_frame(*keys)
        assert_equal false, Input.trigger?(Input::ALT), keys.inspect
      end
    end
  end

  test "the player's binding or a mod's key on Alt plus a key is enough for the game's Alt to read late" do
    code = PokeAccess::Keyboard.with_alt(Q)
    keys = PokeAccess::Config.keys.dup
    with_scripted_input do
      [lambda { PokeAccess::Config.rebinds = { :c => code } }, lambda { PokeAccess::Config.keys[:hp] = code }].each do |bind|
        bind.call
        engine_answers(true)
        key_frame(ALT)
        assert_equal false, Input.trigger?(Input::ALT)
        engine_answers(false)
        key_frame
        assert_equal true, Input.trigger?(Input::ALT)
        PokeAccess::Config.rebinds = {}
        PokeAccess::Config.keys = keys.dup
      end
    end
  ensure
    PokeAccess::Config.keys = keys
  end

  test "with nothing on Alt plus a key the game's Alt is the engine's" do
    with_scripted_input do
      engine_answers(true)
      key_frame(ALT)
      assert_equal true, Input.trigger?(Input::ALT)
      engine_answers(false)
      key_frame
      assert_equal false, Input.trigger?(Input::ALT)
    end
  end

  test "the game's Alt bound by the player follows that key, with an action on Alt plus another" do
    with_shipped_extra do
      PokeAccess::Config.rebinds = { :alt => Q }
      key_frame(ALT)
      key_frame
      assert_equal false, Input.trigger?(Input::ALT)
      key_frame(Q)
      assert_equal true, Input.trigger?(Input::ALT)
    end
  end

  test "what is shipped for the field leaves the game's Alt to the engine in a battle" do
    with_shipped_extra do
      Remap.ship({ :pa_test_a => "Alt+M" }, true)
      kept = PokeAccess::Battle.method(:in_battle?)
      begin
        PokeAccess::Battle.define_singleton_method(:in_battle?) { true }
        engine_answers(true)
        key_frame(ALT)
        assert_equal true, Input.trigger?(Input::ALT)
      ensure
        PokeAccess::Battle.define_singleton_method(:in_battle?, kept)
      end
    end
  end

  test "the mod off forgets a held Alt: letting it go after fires nothing" do
    with_shipped_extra do
      key_frame(ALT)
      with_mod_off { key_frame(ALT) }
      key_frame
      assert_equal false, Input.trigger?(Input::ALT)
    end
  end

  test "a key pressed before Alt is no press of what is on Alt plus it" do
    with_shipped_extra do
      key_frame(LETTER)
      key_frame(ALT, LETTER)
      assert_equal [false, false], [Input.triggerex?(:M), Input.pressex?(:M)]
    end
  end

  test "an extra read by its letter's name leaves that letter read by code to the game, as a text entry reads it" do
    with_shipped_extra do
      [false, true].each do |bound|
        PokeAccess::Config.rebinds = bound ? { :pa_test_a => Q } : {}
        { true => true, false => false }.each do |engine, want|
          engine_answers(engine)
          key_frame
          assert_equal want, Input.triggerex?(LETTER), "bound #{bound}, with the engine at #{engine}"
        end
      end
    end
  end

  test "with Alt held, a mod's key yields to an action on Alt plus its letter, and answers with none there" do
    with_shipped_extra do
      keys = PokeAccess::Keys
      key_frame(ALT, LETTER)
      assert_equal false, keys.key(:coords)
      key_frame
      key_frame(LETTER)
      assert_equal true, keys.key(:coords)
      PokeAccess::Config.rebinds = { :pa_test_a => Q }
      key_frame
      key_frame(ALT, LETTER)
      assert_equal true, keys.key(:coords)
    end
  end

  test "a mod's key on Alt plus a letter answers that, and the letter alone no more" do
    with_shipped_extra do
      PokeAccess::Config.keys[:hp] = PokeAccess::Keyboard.with_alt(Q)
      [[[Q], false], [[], false], [[ALT], false], [[ALT, Q], true], [[ALT, Q], false]].each do |held, want|
        key_frame(*held)
        assert_equal want, PokeAccess::Keys.key(:hp), held.inspect
      end
    end
  end

  test "a game button the player binds to Alt plus a key answers that alone" do
    with_shipped_extra do
      PokeAccess::Config.rebinds = { :c => PokeAccess::Keyboard.with_alt(Q) }
      engine_answers(true)
      [[[Q], false], [[], false], [[ALT], false], [[ALT, Q], true], [[ALT, Q], false]].each do |held, want|
        key_frame(*held)
        assert_equal want, Input.trigger?(Input::C), held.inspect
      end
    end
  end

  test "a plain key the player binds yields to an action on Alt plus it, and answers only a press of its own" do
    with_shipped_extra do
      PokeAccess::Config.rebinds = { :c => LETTER }
      key_frame(ALT, LETTER)
      assert_equal false, Input.trigger?(Input::C), "with Alt"
      key_frame(LETTER)
      assert_equal false, Input.trigger?(Input::C), "letting Alt go first"
      key_frame
      key_frame(LETTER)
      assert_equal true, Input.trigger?(Input::C), "its own press"
      key_frame(ALT, LETTER)
      key_frame(LETTER)
      assert_equal false, Input.trigger?(Input::C), "tapping Alt while it is held"
    end
  end

  test "a plain key with nothing on Alt plus it counts with Alt held, as ever" do
    with_shipped_extra do
      PokeAccess::Config.rebinds = { :c => Q }
      key_frame(ALT, Q)
      assert_equal true, Input.trigger?(Input::C)
    end
  end

  test "AltGr, which holds Ctrl with Alt, is no Alt for a key with it, and leaves the letter's own press alone" do
    with_shipped_extra do
      kb = PokeAccess::Keyboard
      PokeAccess::Config.keys[:hp] = kb.with_alt(Q)
      key_frame(ALT, kb::VK_CONTROL, LETTER)
      assert_equal [false, true], [Input.triggerex?(:M), PokeAccess::Keys.key(:coords)]
      key_frame(ALT, kb::VK_CONTROL, Q)
      assert_equal false, PokeAccess::Keys.key(:hp)
    end
  end

  test "a key held before Alt, never asked about till then, is no press of what is on Alt plus it" do
    with_shipped_extra do
      Remap.ship(:z => "Alt+E")
      key_frame(E)
      key_frame(ALT, E)
      assert_equal false, Input.trigger?(Input::Z)
    end
  end

  test "in a text field an extra's key is a letter: its bound key and its shipped one say nothing for it" do
    with_shipped_extra do
      keys = PokeAccess::Keys
      engine_answers(true)
      keys.instance_variable_set(:@typing_ttl, 4)
      begin
        key_frame
        assert_equal true, Input.triggerex?(:M), "the engine's own answer, on its key"
        engine_answers(false)
        key_frame(ALT, LETTER)
        assert_equal false, Input.triggerex?(:M), "what it ships on"
        PokeAccess::Config.rebinds = { :pa_test_a => Q }
        key_frame(Q)
        assert_equal false, Input.triggerex?(:M), "what the player bound it to"
      ensure
        keys.instance_variable_set(:@typing_ttl, 0)
      end
    end
  end

  test "a game button shipped on a key answers it alone, and the player's key takes its place" do
    with_shipped_extra do
      Remap.ship(:z => "Q")
      engine_answers(true)
      key_frame
      assert_equal false, Input.trigger?(Input::Z)
      key_frame(Q)
      assert_equal true, Input.trigger?(Input::Z)
      PokeAccess::Config.rebinds = { :z => W }
      key_frame
      key_frame(Q)
      assert_equal false, Input.trigger?(Input::Z)
      key_frame
      key_frame(W)
      assert_equal true, Input.trigger?(Input::Z)
    end
  end

  test "a key the player binds to a shipped extra frees what it shipped on" do
    with_shipped_extra do
      assert_equal PokeAccess::Keyboard.with_alt(LETTER), Remap.bound_code(:pa_test_a)
      PokeAccess::Config.rebinds = { :pa_test_a => Q }
      assert_equal Q, Remap.bound_code(:pa_test_a)
      key_frame(ALT, LETTER)
      assert_equal false, Input.triggerex?(:M)
      key_frame(Q)
      assert_equal true, Input.triggerex?(:M)
      assert_nil Remap.conflict(PokeAccess::Keyboard.with_alt(LETTER), :info)
    end
  end

  test "what is shipped for the field holds out of battle, and a battle leaves the action on the game's keys" do
    with_shipped_extra do
      Remap.ship({ :pa_test_a => "Alt+M" }, true)
      engine_answers(true)
      kept = PokeAccess::Battle.method(:in_battle?)
      begin
        key_frame
        assert_equal false, Input.triggerex?(:M)
        PokeAccess::Battle.define_singleton_method(:in_battle?) { true }
        key_frame
        assert_equal [true, nil], [Input.triggerex?(:M), Remap.bound_code(:pa_test_a)]
        engine_answers(false)
        key_frame(ALT, LETTER)
        assert_equal false, Input.triggerex?(:M)
      ensure
        PokeAccess::Battle.define_singleton_method(:in_battle?, kept)
      end
    end
  end

  test "with the mod off or out of focus, what is shipped is on the game's keys" do
    with_shipped_extra do
      engine_answers(true)
      [:with_mod_off, :in_background].each do |condition|
        send(condition) do
          key_frame
          assert_equal true, Input.triggerex?(:M), condition.to_s
        end
      end
    end
  end

  test "a mod's key shipped elsewhere moves there, as its default, and into no table of the game's" do
    with_shipped_extra do
      Remap.ship(:hp => "Alt+K", :verbosity => "V")
      cfg = PokeAccess::Config
      with_k = PokeAccess::Keyboard.with_alt(0x4B)
      assert_equal [with_k, with_k, 0x56, 0x56], [cfg.keys[:hp], cfg.key_defaults[:hp], cfg.keys[:verbosity], cfg.key_defaults[:verbosity]]
      assert_equal [:pa_test_a], Remap.defaults.keys
    end
  end

  test "what is shipped holds its key against the other entries and leaves its raw key free, and Alt frees no reserved key" do
    with_shipped_extra do
      kb = PokeAccess::Keyboard
      alt_m = kb.with_alt(LETTER)
      assert_equal [:pa_test_a, nil, :rmp_key_enter, :rmp_key_f1],
                   [Remap.conflict(alt_m, :info), Remap.conflict(alt_m, :pa_test_a), Remap.conflict(kb.with_alt(0x0D), :info),
                    Remap.conflict(kb.with_alt(0x70), :info)]
      PokeAccess::Config.keys[:coords] = 0x4E
      assert_nil Remap.conflict(LETTER, :info)
    end
  end

  test "what is shipped holds in a battle too, unless shipped for the field" do
    with_shipped_extra do
      kept = PokeAccess::Battle.method(:in_battle?)
      begin
        PokeAccess::Battle.define_singleton_method(:in_battle?) { true }
        assert_equal PokeAccess::Keyboard.with_alt(LETTER), Remap.bound_code(:pa_test_a)
      ensure
        PokeAccess::Battle.define_singleton_method(:in_battle?, kept)
      end
    end
  end

  test "an extra read by its letter's name, not shipped elsewhere, holds that letter against other entries" do
    with_extras([:pa_test_a, :M, :btn_x]) do
      kept = PokeAccess::Config.keys[:coords]
      begin
        PokeAccess::Config.keys[:coords] = 0x4E
        assert_equal :pa_test_a, Remap.conflict(LETTER, :info)
      ensure
        PokeAccess::Config.keys[:coords] = kept
      end
    end
  end

  test "what a profile ships counts as a key moved" do
    with_shipped_extra do
      PokeAccess::Config.rebinds = {}
      assert_equal false, Remap.no_rebinds?
    end
  end

  test "an extra not rebound answers the game's own raw key" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        { true => true, false => false }.each do |engine, want|
          engine_answers(engine)
          poll
          EXTRA_HOOKS.each { |m| assert_equal want, Input.send(m, EXTRA_VK), "#{m} with the engine at #{engine}" }
        end
      end
    end
  end

  test "a rebound extra no longer answers the game's own raw key" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :pa_test_a => Q }
        engine_answers(true)
        poll
        assert_equal [false, false], EXTRA_HOOKS.map { |m| Input.send(m, EXTRA_VK) }
      end
    end
  end

  test "the bound key triggers its extra on the frame it goes down and presses it while held" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :pa_test_a => Q }
        hold(Q)
        frames = (1..2).map { poll; EXTRA_HOOKS.map { |m| Input.send(m, EXTRA_VK) } }
        assert_equal [[true, true], [false, true]], frames
      end
    end
  end

  test "a raw key no extra claims answers the engine alone" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :pa_test_a => Q }
        hold(Q)
        { true => true, false => false }.each do |engine, want|
          engine_answers(engine)
          poll
          EXTRA_HOOKS.each { |m| assert_equal want, Input.send(m, OTHER_VK), "#{m} with the engine at #{engine}" }
        end
      end
    end
  end

  test "without the keyboard probe, nothing is remapped and the engine keeps every key" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :c => Q, :pa_test_a => W }
        engine_answers(true)
        without_keyboard_probe do
          poll
          assert_equal [true, true], [Input.trigger?(Input::C), Input.triggerex?(EXTRA_VK)]
        end
      end
    end
  end

  test "when its check fails, a button and an extra answer the engine's own keys" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :c => Q, :pa_test_a => W }
        engine_answers(true)
        poll
        failing(Remap, :remapped_button?, :extra_remapped?) do
          answers = BUTTON_HOOKS.map { |m| Input.send(m, Input::C) } + EXTRA_HOOKS.map { |m| Input.send(m, EXTRA_VK) }
          assert_equal [true] * 5, answers
        end
      end
    end
  end

  test "when its answer fails, a rebound button or extra answers nothing" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        PokeAccess::Config.rebinds = { :c => Q, :pa_test_a => W }
        engine_answers(true)
        poll
        failing(Remap, *QUERIES) do
          answers = BUTTON_HOOKS.map { |m| Input.send(m, Input::C) } + EXTRA_HOOKS.map { |m| Input.send(m, EXTRA_VK) }
          assert_equal [false] * 5, answers
        end
      end
    end
  end

  test "when its answer fails, a button or extra not rebound answers the engine alone" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        failing(Remap, *QUERIES) do
          { true => true, false => false }.each do |engine, want|
            engine_answers(engine)
            answers = BUTTON_HOOKS.map { |m| Input.send(m, Input::C) } + EXTRA_HOOKS.map { |m| Input.send(m, EXTRA_VK) }
            assert_equal [want] * 5, answers, "with the engine at #{engine}"
          end
        end
      end
    end
  end

  test "when its direction fails, dir4 and dir8 give the engine's none" do
    with_scripted_input do
      failing(Remap, :dir) { assert_equal [0, 0], [Input.dir4, Input.dir8] }
    end
  end

  test "loaded again, as an F12 reset reruns the scripts, its Input hooks stay a single layer" do
    with_scripted_input do
      with_extras([:pa_test_a, EXTRA_VK, :btn_x]) do
        load_hooks_again
        PokeAccess::Config.rebinds = { :c => Q, :pa_test_a => W }
        engine_answers(true)
        hold(Q, W)
        poll
        assert_equal [true, true, true, true], [Input.trigger?(Input::C), Input.trigger?(Input::B),
                                                Input.triggerex?(EXTRA_VK), Input.triggerex?(OTHER_VK)]
      end
    end
  end

  private

  # Runs the block with the keyboard and the engine's own Input scripted through @rig: the virtual-keys in its down
  # list are held, the engine's button and raw-key queries answer its engine value, and dir4 and dir8 its dir. The
  # real ones are put back after, and every key the remapper holds released before and after.
  def with_scripted_input
    @rig = Scripted.new([], false, 0, [])
    rig = @rig
    sc = Input.singleton_class
    PokeAccess::Keyboard::GAKS.define_singleton_method(:call) { |vk| rig.down.include?(vk) ? 0x8000 : 0 }
    ENGINE_KEYS.each { |orig| script_engine(sc, orig) { |*_args| rig.engine } }
    ENGINE_DIRS.each { |orig| script_engine(sc, orig) { |*args| rig.dir_args.push(args); rig.dir } }
    release_all
    yield
  ensure
    release_all
    [:@alt_was, :@alt_tap, :@alt_used].each { |state| Remap.instance_variable_set(state, false) }
    (ENGINE_KEYS + ENGINE_DIRS).each { |orig| unscript_engine(sc, orig) }
    PokeAccess::Keyboard::GAKS.singleton_class.send(:remove_method, :call)
  end

  # Puts the block in place of the engine's original Input method orig, the one the hook calls, keeping the real one.
  def script_engine(sc, orig, &answer)
    return unless sc.method_defined?(orig)
    sc.send(:alias_method, "pa_test_real_#{orig}", orig)
    sc.send(:define_method, orig, &answer)
  end

  # Puts the engine's real Input method orig back.
  def unscript_engine(sc, orig)
    real = "pa_test_real_#{orig}"
    return unless sc.method_defined?(real)
    sc.send(:alias_method, orig, real)
    sc.send(:remove_method, real)
  end

  # Holds exactly these virtual-keys down from now on (none: every key up).
  def hold(*vks)
    @rig.down.replace(vks)
  end

  # What the engine's own button and raw-key queries answer from now on.
  def engine_answers(value)
    @rig.engine = value
  end

  # The direction the engine's own dir4 and dir8 give from now on.
  def engine_dir(dir)
    @rig.dir = dir
  end

  # Runs one frame of the remapper's poll.
  def poll
    Remap.update
  end

  # The frames, of so many with Accept's bound key held, on which the game reads Accept as repeated.
  def held_repeats(frames)
    with_scripted_input do
      PokeAccess::Config.rebinds = { :c => Q }
      hold(Q)
      (1..frames).select { |_frame| poll; Input.repeat?(Input::C) }
    end
  end

  # Runs the block on an engine of that mkxp-z version (as numbers, none for 1.3, nil to read System::VERSION), its
  # mkxp.json giving [fixedFramerate, syncToRefreshrate], the game reading its keys in Ruby when ruby, at frame rate
  # rate (or the stub's); the real answers are put back after.
  def on_engine(version, config = [0, false], ruby = false, rate = nil)
    real = [[PokeAccess::NativeKeys, :native_input?, lambda { !ruby }], [Remap, :engine_config, lambda { config }]]
    real.push([Remap, :mkxp_version, lambda { version }]) if version
    real.push([Graphics, :frame_rate, lambda { rate }]) if rate
    real = real.map { |mod, name, body| was = mod.method(name); mod.define_singleton_method(name, &body); [mod, name, was] }
    yield
  ensure
    real.each { |mod, name, was| mod.define_singleton_method(name, was) } if real.is_a?(Array)
  end

  # Empties the rebinds and runs a frame, which releases every key the remapper holds.
  def release_all
    PokeAccess::Config.rebinds = {}
    Remap.update
  end

  # Runs the block with these extras, as [action, raw key, label], registered in place of any others; the real list is
  # put back after.
  def with_extras(*rows)
    saved = Remap.extras.dup
    Remap.extras.clear
    rows.each { |sym, vk, label| Remap.register_extra(sym, vk, label) }
    yield
  ensure
    Remap.extras.replace(saved) if saved
  end

  # Runs the block with the keyboard and the engine scripted, one extra the game reads by the name of M, shipped on Alt
  # plus it, and the mod's coordinates on that letter; the keys and the keyboard's picture are put back after.
  def with_shipped_extra(map = { :pa_test_a => "Alt+M" })
    keys = PokeAccess::Config.keys.dup
    shipped = PokeAccess::Config.key_defaults.dup
    with_scripted_input do
      with_extras([:pa_test_a, :M, :btn_x]) do
        PokeAccess::Config.keys[:coords] = LETTER
        Remap.ship(map)
        2.times { PokeAccess::Keyboard.snapshot }
        yield
      end
    end
  ensure
    Remap.defaults.clear
    Remap.field_defaults.clear
    PokeAccess::Config.keys = keys
    PokeAccess::Config.key_defaults = shipped
    2.times { PokeAccess::Keyboard.snapshot }
  end

  # One frame with exactly these keys held: the picture the pulse takes, then the remapper's look at them.
  def key_frame(*vks)
    hold(*vks)
    PokeAccess::Keyboard.snapshot
    poll
  end

  # Runs the block with the mod switched off, as Ctrl+Alt+F8 does, and back on after.
  def with_mod_off
    was = PokeAccess::Keys.instance_variable_get(:@enabled)
    PokeAccess::Keys.instance_variable_set(:@enabled, false)
    yield
  ensure
    PokeAccess::Keys.instance_variable_set(:@enabled, was)
  end

  # Runs the block with another window in front of the game's: the window recorded as the game's is not the one the
  # stub reports in front.
  def in_background
    was = PokeAccess::Focus.instance_variable_get(:@game_hwnd)
    PokeAccess::Focus.instance_variable_set(:@game_hwnd, 0x1234)
    yield
  ensure
    PokeAccess::Focus.instance_variable_set(:@game_hwnd, was)
  end

  # Runs the block without GetAsyncKeyState, as on a system that lacks it.
  def without_keyboard_probe
    real = PokeAccess::Keyboard::GAKS
    swap_const(PokeAccess::Keyboard, :GAKS, nil)
    swap_const(PokeAccess::Keys, :GAKS, nil)
    yield
  ensure
    swap_const(PokeAccess::Keyboard, :GAKS, real)
    swap_const(PokeAccess::Keys, :GAKS, real)
  end

  # Runs the block with the engine's Input having an F8 button (a number of its own where the stand-in lacks one) and
  # the remapper's chord buttons resolved anew, both put back after.
  def with_f8
    added = !Input.const_defined?(:F8)
    Input.const_set(:F8, 9001) if added
    Remap.instance_variable_set(:@chord_buttons, nil)
    yield
  ensure
    Input.send(:remove_const, :F8) if added
    Remap.instance_variable_set(:@chord_buttons, nil)
  end

  # Sets a module's constant to value.
  def swap_const(mod, name, value)
    mod.send(:remove_const, name)
    mod.const_set(name, value)
  end

  # Runs the block with the engine's Input lacking the constant name, the remapper's lookups built anew without it,
  # and again with it after; the block gets the integer the constant had.
  def without_input_constant(name)
    value = Input.send(:remove_const, name)
    forget_lookups
    yield value
  ensure
    Input.const_set(name, value) if value
    forget_lookups
  end

  # Drops the remapper's memoised Input lookups, so the next one resolves the constants again.
  def forget_lookups
    Remap.instance_variable_set(:@btn_int_map, nil)
    Remap.instance_variable_set(:@int_sym_map, nil)
  end

  # Runs the block with the methods of these names of mod (the remapper, or the input layer it asks) raising, the real
  # ones put back after.
  def failing(mod, *names)
    real = names.map { |name| [name, mod.method(name)] }
    names.each { |name| mod.define_singleton_method(name) { |*_args| raise "#{mod}.#{name} failed" } }
    yield
  ensure
    real.each { |name, method| mod.define_singleton_method(name, method) } if real
  end

  # Evaluates the Input hooks at the end of core/input/remap.rb again, as a second load of the file does, under another
  # name so the file's coverage stays its own.
  def load_hooks_again
    src = Harness.source(REMAP_FILE)
    eval(src[src.index("\nbegin\n")..-1], TOPLEVEL_BINDING, "remap.rb loaded again")
  end
end
