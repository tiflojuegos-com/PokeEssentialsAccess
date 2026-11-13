require "tmpdir"

class GenericShiftMenuTest < PokeAccessTest
  registrations = []
  frame_registrar = PokeAccess::Frame.method(:each_pulse)
  menu_registrar = PokeAccess::Hooks.method(:around_hook)
  begin
    PokeAccess::Frame.define_singleton_method(:each_pulse) { |&block| registrations << [:pulse, block] }
    PokeAccess::Hooks.define_singleton_method(:around_hook) { |*args, &block| registrations << [:menu, args, block] }
    require File.join(Harness::ROOT, "games", "generic", "shift_menu")
  ensure
    PokeAccess::Frame.define_singleton_method(:each_pulse, frame_registrar)
    PokeAccess::Hooks.define_singleton_method(:around_hook, menu_registrar)
  end
  Registrations = registrations.freeze
  Guard = PokeAccess::GenericShiftMenu

  test "the profile registers one pulse and the real menu adapter without leaking hooks into other models" do
    assert_equal [:pulse, :menu], Registrations.map { |entry| entry[0] }
    assert_equal ["Scene_Map", :call_menu, { :optional => true }], Registrations.last[1]
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      assert_nil Registrations.last[2].call(scene, original, [:forwarded])
      state[:down][PokeAccess::Config.keys[:prev]] = true
      Registrations.first[1].call
      state[:down].clear
      assert_nil Registrations.last[2].call(scene, original, [:forwarded])
      assert_empty calls
    end
  end

  test "a bare Shift postpones the native menu until release and preserves its result and arguments" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      assert_nil Guard.intercept(scene, original, [:owned])
      assert_empty calls
      assert $game_temp.menu_calling
      3.times { assert_nil Guard.intercept(scene, original, [:owned]) }
      state[:down].clear
      assert_equal :original_menu, Guard.intercept(scene, original, [:owned])
      assert_equal [[:owned]], calls
      assert_nil Guard.instance_variable_get(:@scene)
    end
  end

  test "Shift and a locator key on the same frame cancel the game menu without moving the player" do
    with_menu do |state, scene, original, calls|
      before = [$game_player.x, $game_player.y, $game_player.instance_variable_get(:@through)]
      state[:down].merge!(0x10 => true, PokeAccess::Config.keys[:prev] => true)
      assert_nil Guard.intercept(scene, original, [])
      assert_empty calls
      refute $game_temp.menu_calling
      assert_equal before, [$game_player.x, $game_player.y, $game_player.instance_variable_get(:@through)]
    end
  end

  test "a locator key pressed after Shift cancels the pending menu, including after the key was released" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      Guard.intercept(scene, original, [])
      state[:down][PokeAccess::Config.keys[:next]] = true
      Guard.observe
      state[:down].clear
      assert_nil Guard.intercept(scene, original, [])
      assert_empty calls
      refute $game_temp.menu_calling
    end
  end

  test "Z still opens the menu immediately while Shift is held" do
    with_menu do |state, scene, original, calls|
      state[:down].merge!(0x10 => true, 0x5A => true)
      assert_equal :original_menu, Guard.intercept(scene, original, [7])
      assert_equal [[7]], calls
    end
  end

  test "an alternate action pressed after the modifier opens the pending menu before release" do
    [[:default, 0x5A], [:layout, 0x57], [:f1, 0x51]].each do |kind, alternate|
      with_menu do |state, scene, original, calls|
        if kind == :layout
          state[:vk][29] = alternate
        elsif kind == :f1
          File.write(state[:file], "owned binding marker")
          state[:table] = { :a => [0x10, alternate] }
        end
        state[:down][0x10] = true
        assert_nil Guard.intercept(scene, original, [:later])
        assert_empty calls
        state[:trigger] = false
        state[:down][alternate] = true
        assert_equal :original_menu, Guard.intercept(scene, original, [:later]), kind
        assert_equal [[:later]], calls
        assert_nil Guard.instance_variable_get(:@scene)
      end
    end
  end

  test "a changed current scene keeps its own original menu request" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      Guard.intercept(scene, original, [])
      replacement = Object.new
      $scene = replacement
      assert_equal :original_menu, Guard.intercept(replacement, original, [:replacement])
      assert_equal [[:replacement]], calls
    end
  end

  test "a request on an instance outside the current scene is not deferred" do
    with_menu do |state, _scene, original, calls|
      state[:down][0x10] = true
      assert_equal :original_menu, Guard.intercept(Object.new, original, [:external])
      assert_equal [[:external]], calls
    end
  end

  test "the Access settings loop consumes a pending request even if Shift was already released" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      Guard.intercept(scene, original, [])
      state[:down].clear
      state[:config] = true
      Guard.observe
      state[:config] = false
      assert_nil Guard.intercept(scene, original, [])
      assert_empty calls
      refute $game_temp.menu_calling
    end
  end

  test "the default alternate action key follows the actual keyboard layout" do
    with_menu do |state, scene, original, calls|
      state[:vk][29] = 0x57
      state[:down].merge!(0x10 => true, 0x57 => true)
      assert_equal :original_menu, Guard.intercept(scene, original, [:layout])
      assert_equal [[:layout]], calls
    end
  end

  test "a menu from another key or a programmatic call retains the original behavior" do
    with_menu do |state, scene, original, calls|
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      state[:down][0x10] = true
      state[:trigger] = false
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      state[:trigger] = true
      $game_temp.menu_calling = false
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 3, calls.length
    end
  end

  test "a customized F1 action on another key is preserved" do
    with_menu do |state, scene, original, calls|
      File.write(state[:file], "owned binding marker")
      state[:table] = { :a => [0x51] }
      state[:down][0x10] = true
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 1, calls.length
    end
  end

  test "a custom menu without the standard request reader or writer retains its own behavior" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      $game_temp = Object.new
      assert_equal :original_menu, Guard.intercept(scene, original, [:opaque])
      $game_temp = Class.new { def menu_calling; true; end }.new
      assert_equal :original_menu, Guard.intercept(scene, original, [:read_only])
      assert_equal [[:opaque], [:read_only]], calls
    end
  end

  test "an F1 action using the modifier is guarded, while its alternate key remains immediate" do
    with_menu do |state, scene, original, calls|
      File.write(state[:file], "owned binding marker")
      state[:table] = { :a => [0x10, 0x48] }
      state[:down][0x10] = true
      assert_nil Guard.intercept(scene, original, [])
      Guard.cancel
      $game_temp.menu_calling = true
      state[:down][0x48] = true
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 1, calls.length
    end
  end

  test "an explicit Access action binding takes priority over native defaults" do
    with_menu do |state, scene, original, calls|
      state[:bound] = 0x51
      state[:down][0x10] = true
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 1, calls.length
    end
  end

  test "disabled, unfocused, typing and non-native input leave new menu requests alone" do
    [:live, :focus, :native].each do |key|
      with_menu do |state, scene, original, calls|
        state[:down][0x10] = true
        state[key] = false
        assert_equal :original_menu, Guard.intercept(scene, original, []), key
        assert_equal 1, calls.length
      end
    end
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      state[:typing] = true
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 1, calls.length
    end
  end

  test "a lost window or disabled mod cancels its own deferred request without a later surprise menu" do
    [:live, :focus].each do |key|
      with_menu do |state, scene, original, calls|
        state[:down][0x10] = true
        Guard.intercept(scene, original, [])
        state[key] = false
        Guard.observe
        refute $game_temp.menu_calling
        assert_nil Guard.instance_variable_get(:@scene)
        assert_empty calls
      end
    end
  end

  test "an engine with a different action alias and an unbound modifier are left alone" do
    with_menu do |state, scene, original, calls|
      state[:down][0x10] = true
      Input.send(:remove_const, :ACTION)
      Input.const_set(:ACTION, Input::B)
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      Input.send(:remove_const, :ACTION)
      Input.const_set(:ACTION, Input::A)
      PokeAccess::Config.keys[:shift] = nil
      assert_equal :original_menu, Guard.intercept(scene, original, [])
      assert_equal 2, calls.length
    end
  end

  # Each case owns a temporary F1 path, scripted keyboard and native request; public methods and game objects return
  # to their previous values even after a failed assertion, so the generic profile cannot leak into other models.
  def with_menu
    previous_scene, previous_temp = $scene, $game_temp
    previous_action = Input.const_defined?(:ACTION) ? Input.const_get(:ACTION) : nil
    Input.send(:remove_const, :ACTION) if Input.const_defined?(:ACTION)
    Input.const_set(:ACTION, Input::A)
    Dir.mktmpdir("generic-shift-menu") do |dir|
      state = { :down => {}, :live => true, :focus => true, :native => true, :typing => false, :config => false,
                :vk => { 225 => 0x10, 29 => 0x5A },
                :trigger => true, :bound => nil, :table => {}, :file => File.join(dir, "keybindings.mkxp1") }
      scene = Object.new
      $scene = scene
      $game_temp = Struct.new(:menu_calling).new(true)
      calls = []
      original = proc { |*args| calls << args; :original_menu }
      answers = [[PokeAccess::Keys, :enabled, proc { state[:live] }],
                 [PokeAccess::Keys, :focused?, proc { state[:focus] }],
                 [PokeAccess::Keys, :typing?, proc { state[:typing] }],
                 [PokeAccess::Keyboard, :raw_down?, proc { |code| !!state[:down][code] }],
                 [PokeAccess::NativeKeys, :native_input?, proc { state[:native] }],
                 [PokeAccess::NativeKeys, :path, proc { state[:file] }],
                 [PokeAccess::NativeKeys, :table, proc { state[:table] }],
                 [PokeAccess::NativeKeys, :vk_of, proc { |scan| state[:vk][scan] }],
                 [PokeAccess::ConfigMenu, :active?, proc { state[:config] }],
                 [PokeAccess::Remap, :bound_code, proc { |_action| state[:bound] }],
                 [Input, :trigger?, proc { |_button| state[:trigger] }]]
      answering_all(answers) { yield state, scene, original, calls }
    end
  ensure
    Guard.reset
    $scene, $game_temp = previous_scene, previous_temp
    Input.send(:remove_const, :ACTION) if Input.const_defined?(:ACTION)
    Input.const_set(:ACTION, previous_action) unless previous_action.nil?
  end

  # Temporarily substitutes actual public query methods, retaining the exact method each object had.
  def answering_all(answers, &block)
    return block.call if answers.empty?
    obj, name, body = answers.first
    old = obj.method(name)
    obj.define_singleton_method(name, &body)
    answering_all(answers.drop(1), &block)
  ensure
    obj.define_singleton_method(name, old) if obj && old
  end
end
