# The randomizer Reborn and Desolation share, from the keyboard (games/rv_common/randomizer_rv.rb): J/K/L/I move a focus
# over its mouse-only controls, confirm and the arrows work them, and each change reaches the scene's loop as a click.
Harness.load_common("rv_common")

# The animation editor's controls the randomizer is built of; the pointer is never over one here, so each update only
# clears its changed flag. Board is the physical keyboard of the frames the scene below runs.
module RvRandRig
  class UIControl
    attr_accessor :label, :x, :y, :changed, :parent
    def initialize(label, setblock = nil)
      @label = label
      @setProc = setblock
      @x = 0
      @y = 0
      @changed = false
    end
    def update; end
    def invalidate; @invalid = true; end
    def setvalue; @setProc.call(curvalue); end
  end

  class Label < UIControl; end

  class Button < UIControl
    def update; self.changed = false; end
  end

  class Checkbox < Button
    attr_reader :checked
    def checked=(v); @checked = v; invalidate; end
    def curvalue; @checked; end
    def update
      super
      @checked = !@checked if changed
    end
  end

  class Slider < UIControl
    attr_reader :curvalue
    def initialize(label, min, max, cur, setblock = nil)
      super(label, setblock)
      @min = min
      @max = max
      @curvalue = cur
    end
    def curvalue=(v); @curvalue = [[v, @min].max, @max].min; invalidate; end
    def update; self.changed = false; end
  end

  class TextSlider < UIControl
    attr_reader :curvalue, :options
    def initialize(label, options, cur, setblock = nil)
      super(label, setblock)
      @options = options
      @curvalue = cur
    end
    def curvalue=(v); @curvalue = [[v, 0].max, @options.length - 1].min; invalidate; end
    def update; self.changed = false; end
  end

  # Reborn's seed field, which types itself only with the pointer over its window.
  class TextBox < UIControl
    attr_reader :text
    def initialize(label, text)
      super(label)
      @text = text
      @cursor = text.length
      @captured = false
    end
    def captured?; @captured; end
    def insert(ch); @text += ch; @cursor += 1; self.changed = true; end
    def delete; @text = @text[0...-1]; @cursor -= 1; self.changed = true; end
    def update; self.changed = false; end
  end

  # The keys down in the frame the scene runs: J/K/L/I, shift and Enter as the raw keys the mod reads, Backspace as
  # the game's extended key, confirm and the arrows as its buttons, a String as the text typed in that frame. It
  # notes each switch of the game's text input, and whether the game window has the focus.
  module Board
    VK = { :j => 0x4A, :k => 0x4B, :l => 0x4C, :i => 0x49, :shift => 0x10, :enter => 0x0D }
    BUTTONS = { :c => Input::C, :left => Input::LEFT, :right => Input::RIGHT }
    @down = []
    @typed = nil
    @away = false
    @text_input = []

    def self.vk_down?(vk); VK.any? { |k, v| v == vk && @down.include?(k) }; end
    def self.button?(b); BUTTONS.any? { |k, v| v == b && @down.include?(k) }; end
    def self.backspace?(key); key == :BACKSPACE && @down.include?(:backspace); end
    def self.focused?; !@away; end
    def self.text_input; @text_input; end

    # What was typed this frame, handed over once.
    def self.typed
      t = @typed.to_s
      @typed = nil
      t
    end

    # Runs one game frame with keys down (a String: that text typed), Input.update first, as the game's loop does.
    def self.frame(keys)
      @typed, @down = keys.is_a?(String) ? [keys, []] : [nil, keys]
      Input.update
      yield
    ensure
      @down = []
    end
  end
end

class ControlWindow
  attr_accessor :x, :y, :visible
  attr_reader :controls
  def initialize(x, y, _w, _h)
    @x = x
    @y = y
    @visible = true
    @controls = []
  end
  def addControl(c)
    c.x = 0
    c.y = @controls.length * 32
    c.parent = self
    @controls.push(c)
    @controls.length - 1
  end
  def addLabel(l); addControl(RvRandRig::Label.new(l)); end
  def addButton(l); addControl(RvRandRig::Button.new(l)); end
  def addCheckbox(l, pr); addControl(RvRandRig::Checkbox.new(l, pr)); end
  def addSlider(l, min, max, cur, pr); addControl(RvRandRig::Slider.new(l, min, max, cur, pr)); end
  def addTextSlider(l, opts, cur, pr); addControl(RvRandRig::TextSlider.new(l, opts, cur, pr)); end
  def addSpace; addControl(RvRandRig::UIControl.new("")); end
  def update; @controls.each { |c| c.update }; end
  def changed?(i); @controls[i].changed; end
  def repaint; end
end

# Reborn's scene cut to two pages and a short sidebar (the pages' buttons first, a spacer, Cancel, Done). Its
# initialize holds the loop, as both games' does: a frame per script entry, sidewinLoop then mainwinloop, each changed
# control taken as its click, then the block given, if any, to look at the mod between frames. seen notes the clicks
# on Cancel, Done and the seed field; clicks, what each setter got.
class RandomizerScene
  attr_reader :mainwin, :pages, :seen, :clicks, :seed
  def initialize(script)
    @seen = []
    @clicks = []
    side = ControlWindow.new(0, 0, 240, 512)
    side.addButton("Species Traits")
    side.addButton("Trainers")
    side.addSpace
    side.addButton("Cancel")
    side.addButton("Done")
    @pages = makePages
    @mainwin = @pages[0]
    script.each do |keys|
      RvRandRig::Board.frame(keys) { sidewinLoop(side); mainwinloop }
      yield self if block_given?
    end
  end

  def sidewinLoop(side)
    side.update
    (0...@pages.length).each { |i| pbUpdateSidebar(i) if side.changed?(i) }
    @seen.push(:cancel) if side.changed?(3)
    @seen.push(:done) if side.changed?(4)
  end

  def mainwinloop
    @mainwin.update
    @mainwin.controls.each_with_index do |c, i|
      next unless @mainwin.changed?(i)
      c.is_a?(RvRandRig::TextBox) ? @seen.push(:typed) : c.setvalue
    end
  end

  def pbUpdateSidebar(i)
    return if @mainwin == @pages[i]
    @mainwin.visible = false
    @mainwin = @pages[i]
    @mainwin.visible = true
  end

  def makePages
    spec = ControlWindow.new(240, 0, 560, 512)
    spec.addLabel("Base Stats:")
    spec.addTextSlider("", ["Unchanged", "Random", "Shuffle", "Flipped!"], 0, click(:stats))
    spec.addCheckbox("Follow Evolutions", click(:follow))
    spec.addLabel("Types:")
    spec.addTextSlider("Dual Type Chance:", Array.new(11) { |i| "#{i * 10}%" }, 5, click(:dual))
    trainer = ControlWindow.new(240, 0, 560, 512)
    trainer.visible = false
    trainer.addLabel("Trainer Options:")
    trainer.addCheckbox("Have all trainers randomize", click(:trainers))
    trainer.addLabel("Evolution Level:")
    trainer.addSlider("", 0, 120, 30, click(:evo_level))
    @seed = RvRandRig::TextBox.new("Enter a custom seed:", "")
    trainer.addControl(@seed)
    [spec, trainer]
  end

  # A control's setter, noting each value it gets under name.
  def click(name)
    proc { |v| @clicks.push([name, v]) }
  end
end

# The engine's file binds its hooks only on this engine, told by its $cache, and where the scene exists: evaluated once
# more here, with a $cache of the engine's shape and the scene above.
[:KINDS, :BIG_STEP, :VK_RETURN].each do |c|
  PokeAccess::RandomizerRV.send(:remove_const, c) if PokeAccess::RandomizerRV.const_defined?(c, false)
end
begin
  had_cache = $cache
  $cache = Struct.new(:pkmn, :moves, :abil).new({}, {}, {})
  randomizer = File.join(Harness::ROOT, "games", "rv_common", "randomizer_rv.rb")
  eval(Harness.source(randomizer), TOPLEVEL_BINDING, randomizer)
ensure
  $cache = had_cache
end

class RandomizerRvTest < PokeAccessTest
  Board = RvRandRig::Board
  # From the opening to the focus on the seed field: the Trainers page put up, then down its column.
  TO_SEED = [:k, :k, :c, :l, :k, :k, :k]

  test "says how the screen is worked as it opens" do
    run_scene
    assert_equal [[PokeAccess::I18n.t(:rv_randomizer_keys, PokeAccess::ConfigMenu.key_vars), true]], SpeakCapture.log
  end

  test "names the locator's keys and shift as the player has them bound" do
    keys = PokeAccess::Config.keys
    was = keys.dup
    { :prev => 0x41, :next => 0x44, :route => 0x57, :where => 0x53, :shift => 0x12 }.each { |sym, code| keys[sym] = code }
    run_scene
    said = SpeakCapture.lines.first.to_s
    assert_equal [PokeAccess::I18n.t(:rv_randomizer_keys, PokeAccess::ConfigMenu.key_vars)], SpeakCapture.lines
    assert_equal [true, false], [said.include?("A, D, W"), said.include?("J, L")], said
  ensure
    keys.replace(was) if keys
  end

  test "with no focus yet, any direction lands on the sidebar's first control" do
    [:j, :k, :l, :i].each do |key|
      run_scene(key)
      assert_equal ["Species Traits, #{button}"], said, "with #{key}"
      SpeakCapture.clear
    end
  end

  test "down keeps to the sidebar's column, passing its spacer" do
    run_scene(:k, :k, :k)
    assert_equal ["Species Traits, #{button}", "Trainers, #{button}", "Cancel, #{button}"], said
  end

  test "right lands on the page's control at the nearest row" do
    run_scene(:k, :k, :k, :l)
    assert_equal "Types:", said.last
  end

  test "left from the page lands on the sidebar's control at the nearest row" do
    run_scene(:k, :k, :k, :l, :j)
    assert_equal "Cancel, #{button}", said.last
  end

  test "moving into another section says its heading first" do
    run_scene(:k, :k, :k, :l, :i)
    assert_equal "Base Stats:, Follow Evolutions, #{t(:rv_randomizer_checkbox)}, #{t(:rv_randomizer_unchecked)}",
                 said.last
  end

  test "a slider painted without a label is named by the heading above it" do
    run_scene(:k, :l, :k)
    assert_equal ["Species Traits, #{button}", "Base Stats:", "Base Stats:, #{t(:rv_randomizer_slider)}, Unchanged"],
                 said
  end

  test "with no control further that way it says so, and the focus stays" do
    run_scene(:k, :l, :i, :k)
    assert_equal ["Species Traits, #{button}", "Base Stats:", t(:rv_randomizer_edge),
                  "Base Stats:, #{t(:rv_randomizer_slider)}, Unchanged"], said
  end

  test "an arrow steps an option slider, says the option it shows, and the scene takes it as a click" do
    scene = run_scene(:k, :l, :k, :right)
    assert_equal "Random", said.last
    assert_equal [[:stats, 1]], scene.clicks
  end

  test "the left arrow steps a slider back" do
    scene = run_scene(:k, :l, :k, :right, :left)
    assert_equal ["Random", "Unchanged"], said.last(2)
    assert_equal [[:stats, 1], [:stats, 0]], scene.clicks
  end

  test "shift steps a slider by ten, stopping at its end" do
    scene = run_scene(:k, :l, :k, :k, :k, :k, [:shift, :right])
    assert_equal ["Dual Type Chance:, #{t(:rv_randomizer_slider)}, 50%", "100%"], said.last(2)
    assert_equal [[:dual, 10]], scene.clicks
  end

  test "a number slider steps by one and says its number" do
    scene = run_scene(*TO_SEED[0..-2], :right)
    assert_equal ["Evolution Level:, #{t(:rv_randomizer_slider)}, 30", "31"], said.last(2)
    assert_equal [[:evo_level, 31]], scene.clicks
  end

  test "a step that leaves a slider where it was is no click" do
    scene = run_scene(:k, :l, :k, :left)
    assert_equal "Unchanged", said.last
    assert_equal [], scene.clicks
  end

  test "the arrows step nothing on a button" do
    scene = run_scene(:k, :right, :left)
    assert_equal ["Species Traits, #{button}"], said
    assert_equal [[], []], [scene.clicks, scene.seen]
  end

  test "confirm ticks and unticks a checkbox, each a click the scene takes" do
    scene = run_scene(:k, :l, :k, :k, :c, :c)
    assert_equal [t(:rv_randomizer_checked), t(:rv_randomizer_unchecked)], said.last(2)
    assert_equal [[:follow, true], [:follow, false]], scene.clicks
  end

  test "confirm on a label or a slider says it again" do
    { [:k, :l, :c] => "Base Stats:",
      [:k, :l, :k, :c] => "Base Stats:, #{t(:rv_randomizer_slider)}, Unchanged" }.each do |keys, line|
      run_scene(*keys)
      assert_equal [line, line], said.last(2), "for #{keys.inspect}"
      SpeakCapture.clear
    end
  end

  test "confirm presses a sidebar button that puts up no page, and the scene takes it as a click" do
    scene = run_scene(:k, :k, :k, :c)
    assert_equal [:cancel], scene.seen
    assert_equal ["Species Traits, #{button}", "Trainers, #{button}", "Cancel, #{button}"], said
  end

  test "a page's button puts its page up and says its first heading" do
    scene = run_scene(:k, :k, :c)
    assert_equal "Trainer Options:", said.last
    assert_same scene.pages[1], scene.mainwin
  end

  test "the button of the page already up still says its heading" do
    run_scene(:k, :c)
    assert_equal ["Species Traits, #{button}", "Base Stats:"], said
  end

  test "the heading a page's button said is not said again on the way into its section" do
    run_scene(:k, :k, :c, :l)
    assert_equal "Have all trainers randomize, #{t(:rv_randomizer_checkbox)}, #{t(:rv_randomizer_unchecked)}", said.last
  end

  test "confirm on the seed field starts typing in it" do
    run_scene(*TO_SEED, :c)
    assert_equal ["Enter a custom seed:, #{t(:rv_randomizer_text)}, #{t(:rv_randomizer_empty)}",
                  t(:rv_randomizer_typing)], said.last(2)
  end

  test "what is typed goes into the seed field, and Enter ends the typing saying the text" do
    scene = run_scene(*TO_SEED, :c, "12", :enter)
    assert_equal [t(:rv_randomizer_typing), "12"], said.last(2)
    assert_equal ["12", false, [:typed]], [scene.seed.text, scene.seed.captured?, scene.seen]
  end

  test "typing turns the game's text input on, and Enter turns it off" do
    run_scene(*TO_SEED, :c, :enter)
    assert_equal [true, false], Board.text_input
  end

  test "on an engine with no text input switch, the seed field still takes what is typed" do
    scene = run_frames(taps(*TO_SEED, :c, "12", :enter), false)
    assert_equal [t(:rv_randomizer_typing), "12"], said.last(2)
    assert_equal "12", scene.seed.text
  end

  test "Backspace deletes the last letter typed, down to an empty field" do
    { "12" => "1", "7" => t(:rv_randomizer_empty) }.each do |typed, left|
      run_scene(*TO_SEED, :c, typed, :backspace, :enter)
      assert_equal left, said.last, "after #{typed.inspect}"
      SpeakCapture.clear
    end
  end

  test "Backspace on an empty field changes nothing" do
    scene = run_scene(*TO_SEED, :c, :backspace, :enter)
    assert_equal t(:rv_randomizer_empty), said.last
    assert_equal [], scene.seen
  end

  test "while typing, the mod's keys move nothing" do
    run_scene(*TO_SEED, :c, :j, :enter)
    assert_equal [t(:rv_randomizer_typing), t(:rv_randomizer_empty)], said.last(2)
  end

  test "the Enter that confirmed the field, still held, does not end its typing" do
    run_frames(taps(*TO_SEED) + [[:c, :enter], [:enter], [], "7", [:enter], []])
    assert_equal [t(:rv_randomizer_typing), "7"], said.last(2)
  end

  test "the field is left to type itself while the pointer is over its window" do
    with_pointer([12, 40]) do
      scene = run_scene(*TO_SEED, :c, "12", :enter)
      assert_equal t(:rv_randomizer_empty), said.last
      assert_equal "", scene.seed.text
    end
  end

  test "a field left typing gives the keyboard back as the scene closes" do
    scene = run_scene(*TO_SEED, :c)
    assert_equal false, scene.seed.captured?
    assert_equal [true, false], Board.text_input
  end

  test "keeps the focus on the control it said while the scene runs, and drops it once the loop returns" do
    seen = []
    run_frames(taps(:k)) { seen.push(PokeAccess::RandomizerRV.focus) }
    assert_equal [nil, "Species Traits", "Species Traits"], seen.map { |c| c && c.label }, "after each frame"
    assert_nil PokeAccess::RandomizerRV.focus, "after the scene"
  end

  test "a scene the game left by an error while typing hands neither its focus nor its typing to the next one" do
    assert_raises(RuntimeError) do
      run_frames(taps(*TO_SEED, :c)) { |s| raise "closed" if s.seed.captured? }
    end
    SpeakCapture.clear
    run_scene(:k)
    assert_equal ["Species Traits, #{button}"], said
  end

  test "every line its keys bring cuts in" do
    { [:k] => 1, [:k, :l, :i] => 3, [:k, :l, :k, :right] => 4, [:k, :l, :k, :k, :c] => 5, [:k, :k, :c] => 3,
      TO_SEED + [:c, "7", :enter] => 9 }.each do |keys, lines|
      run_scene(*keys)
      assert_equal [true] * lines, SpeakCapture.log[1..-1].map { |_text, cut| cut }, "for #{keys.inspect}"
      SpeakCapture.clear
    end
  end

  test "the keys move nothing with the mod's keys off, its menu open or the game window not focused" do
    [[PokeAccess::Keys, :@enabled, false], [PokeAccess::ConfigMenu, :@active, true], [Board, :@away, true]].each do |o, iv, v|
      with_ivar(o, iv, v) { run_scene(:k, :c) }
      assert_equal [], said, "with #{o}'s #{iv} #{v}"
      SpeakCapture.clear
    end
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end

  def button
    t(:rv_randomizer_button)
  end

  # What the mod said after the opening line.
  def said
    SpeakCapture.lines[1..-1]
  end

  # The scene run on keys, each pressed in a frame of its own and released in the next.
  def run_scene(*keys)
    run_frames(taps(*keys))
  end

  # The frames of keys pressed one by one, after an idle frame so the first is a fresh press: each key down in a frame
  # of its own and released in the next; [:shift, :right] holds both in one frame, a String is the text typed in it.
  def taps(*keys)
    [[]] + keys.map { |k| [k.is_a?(Symbol) ? [k] : k, []] }.flatten(1)
  end

  # The scene run on a script of frames as given, on an engine with a text input switch or, with switch false, none;
  # a block given looks at the mod after each frame.
  def run_frames(script, switch = true, &peek)
    with_keyboard(switch) { RandomizerScene.new(script, &peek) }
  end

  # Runs the block with the Board in place of the keyboard, the game's buttons, its typed text, its text input switch
  # (none with switch false) and the window's focus, and holding Backspace where the engine's extended keys answer; the
  # engine's own answers are put back after, and the switches noted dropped.
  def with_keyboard(switch)
    kept = [[PokeAccess::Keyboard, :raw_down?], [PokeAccess::Focus, :focused?], [Input, :trigger?], [Input, :repeat?],
            [Input, :triggerex?]].map { |o, m| [o, m, o.method(m)] }
    engine_triggerex = kept.last[2]
    PokeAccess::Keyboard.define_singleton_method(:raw_down?) { |vk| Board.vk_down?(vk) }
    PokeAccess::Focus.define_singleton_method(:focused?) { Board.focused? }
    Input.define_singleton_method(:trigger?) { |b| Board.button?(b) }
    Input.define_singleton_method(:repeat?) { |b| Board.button?(b) }
    Input.define_singleton_method(:triggerex?) { |k| Board.backspace?(k) || engine_triggerex.call(k) }
    Input.define_singleton_method(:gets) { Board.typed }
    Input.define_singleton_method(:text_input=) { |on| Board.text_input.push(on) } if switch
    Board.text_input.clear
    yield
  ensure
    kept.each { |o, m, f| o.define_singleton_method(m, f) }
    Input.singleton_class.send(:remove_method, :gets)
    Input.singleton_class.send(:remove_method, :text_input=) if switch
  end

  # Runs the block with the pointer at xy over the game, as mkxp's Mouse.getMousePos answers; Mouse taken away after.
  def with_pointer(xy)
    Object.const_set(:Mouse, Module.new)
    Mouse.define_singleton_method(:getMousePos) { xy }
    yield
  ensure
    Object.send(:remove_const, :Mouse)
  end

  # Runs the block with obj's instance variable iv set to value, the old value put back after.
  def with_ivar(obj, iv, value)
    had = obj.instance_variable_get(iv)
    obj.instance_variable_set(iv, value)
    yield
  ensure
    obj.instance_variable_set(iv, had)
  end
end
