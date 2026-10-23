# The key remapper (core/input/remap.rb): the controls menu's list, labels and collision check over both key tables,
# and a rebound key reaching the game through the Input hooks, with the keyboard and the engine's answers scripted.
class RemapTest < PokeAccessTest
  Remap = PokeAccess::Remap
  REMAP_FILE = File.join(Harness::ROOT, "core", "input", "remap.rb")
  Q = 0x51
  W = 0x57
  E = 0x45
  R = 0x52
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
