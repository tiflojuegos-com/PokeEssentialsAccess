# The randomizer of the engine Reborn and Desolation share, from the keyboard (games/rv_common/randomizer_rv.rb):
# J/K/L/I move a focus through the animation editor's controls, confirm presses a button or ticks a checkbox, the
# arrows step a slider, and each change lands in the control after its window's update, where the scene's own loop
# reads it as a click. The rig names its classes as the games do and runs through the real hooks: the scene's
# initialize holds the loop and calls sidewinLoop and mainwinloop every frame, as both games do.
Harness.load_common("rv_common")
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

  # The pointer is never over a control here, so the game's update only clears the flag.
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

  # Reborn's seed field, which types only with the pointer over the window: never, here.
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

# Reborn's scene cut to two pages and a short sidebar (pages first, a spacer, Cancel, Done); one script entry is
# one frame's keys, a String the text typed in it.
class RandomizerScene
  attr_accessor :mainwin, :pages, :settings, :seen, :seed
  def initialize(script)
    @settings = {}
    @seen = []
    side = ControlWindow.new(0, 0, 240, 512)
    side.addButton("Species Traits")
    side.addButton("Trainers")
    side.addSpace
    side.addButton("Cancel")
    side.addButton("Done")
    @pages = makePages
    @mainwin = @pages[0]
    script.each { |keys| RvRandKeys.frame(keys) { sidewinLoop(side); mainwinloop } }
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
    spec.addTextSlider("", ["Unchanged", "Random", "Shuffle", "Flipped!"], 0, proc { |v| @settings[:stats] = v })
    spec.addCheckbox("Follow Evolutions", proc { |v| (@settings[:follow] ||= []).push(v) })
    spec.addLabel("Types:")
    spec.addTextSlider("Dual Type Chance:", Array.new(11) { |i| "#{i * 10}%" }, 5,
                       proc { |v| @settings[:dual] = v * 10 })
    trainer = ControlWindow.new(240, 0, 560, 512)
    trainer.visible = false
    trainer.addLabel("Trainer Options:")
    trainer.addCheckbox("Have all trainers randomize", proc { |v| @settings[:trainers] = v })
    trainer.addLabel("Evolution Level:")
    trainer.addSlider("", 0, 120, 30, proc { |v| @settings[:evo_level] = v })
    @seed = RvRandRig::TextBox.new("Enter a custom seed:", "")
    trainer.addControl(@seed)
    [spec, trainer]
  end
end

# The frame's keys: J/K/L/I, shift and Enter as the raw keys the mod reads, confirm and the arrows as the game's
# buttons, typed text through Input.gets; the game window focused throughout.
module RvRandKeys
  VK = { :j => 0x4A, :k => 0x4B, :l => 0x4C, :i => 0x49, :shift => 0x10, :enter => 0x0D }
  BUTTONS = { :c => Input::C, :left => Input::LEFT, :right => Input::RIGHT }
  @down = []

  def self.vk_down?(vk); VK.any? { |k, v| v == vk && @down.include?(k) }; end
  def self.button?(b); BUTTONS.any? { |k, v| v == b && @down.include?(k) }; end

  def self.typed
    t = @typed.to_s
    @typed = nil
    t
  end

  def self.frame(keys)
    if keys.is_a?(String)
      @typed = keys
      @down = []
    else
      @down = keys
    end
    yield
  ensure
    @down = []
  end

  def self.install
    class << PokeAccess::Keyboard
      alias_method :rv_spec_raw_down?, :raw_down?
      def raw_down?(vk); RvRandKeys.vk_down?(vk); end
    end
    class << PokeAccess::Focus
      alias_method :rv_spec_focused?, :focused?
      def focused?; true; end
    end
    class << Input
      alias_method :rv_spec_trigger?, :trigger?
      alias_method :rv_spec_repeat?, :repeat?
      def trigger?(b); RvRandKeys.button?(b); end
      def repeat?(b); RvRandKeys.button?(b); end
      def gets; RvRandKeys.typed; end
    end
  end

  def self.remove
    class << PokeAccess::Keyboard
      alias_method :raw_down?, :rv_spec_raw_down?
    end
    class << PokeAccess::Focus
      alias_method :focused?, :rv_spec_focused?
    end
    class << Input
      alias_method :trigger?, :rv_spec_trigger?
      alias_method :repeat?, :rv_spec_repeat?
      remove_method :gets
    end
    PokeAccess::Keys.instance_variable_set(:@typing_ttl, 0)
  end
end

# Each key a frame of its own and a released frame after it, so every press is a fresh edge.
def rv_taps(*keys)
  keys.map { |k| [k.is_a?(Symbol) ? [k] : k, []] }.flatten(1)
end

def rv_t(key); PokeAccess::I18n.t(key); end

# The core file binds its hooks only on this engine, told by its $cache: loaded again here, once, with one.
unless defined?(RvRandRig::HOOKED)
  [:KINDS, :BIG_STEP, :VK_RETURN].each do |c|
    PokeAccess::RandomizerRV.send(:remove_const, c) if PokeAccess::RandomizerRV.const_defined?(c, false)
  end
  had_cache = $cache
  $cache = Struct.new(:pkmn, :moves, :abil).new({}, {}, {})
  begin
    load File.expand_path("../../../games/rv_common/randomizer_rv.rb", File.dirname(__FILE__))
  ensure
    $cache = had_cache
  end
  RvRandRig::HOOKED = true
end

Suite.define("randomizer (Reborn, Desolation): J/K/L/I, confirm and the arrows work the mouse-only controls") do
  RvRandKeys.install
  begin
    button = rv_t(:rv_randomizer_button)
    edge = rv_t(:rv_randomizer_edge)

    SpeakCapture.clear
    RandomizerScene.new(rv_taps(:k, :k, :k, :l, :i, :i, :i, :i, :j, :j))
    eq "the keys first, then the sidebar from the top; down keeps to the column past its spacer, right lands on the " \
       "page's nearest row, crossing into another section says its heading first, and a slider painted without a " \
       "label takes the one above it",
       SpeakCapture.lines,
       [rv_t(:rv_randomizer_keys), "Species Traits, #{button}", "Trainers, #{button}", "Cancel, #{button}", "Types:",
        "Base Stats:, Follow Evolutions, #{rv_t(:rv_randomizer_checkbox)}, #{rv_t(:rv_randomizer_unchecked)}",
        "Base Stats:, #{rv_t(:rv_randomizer_slider)}, Unchanged", "Base Stats:", edge,
        "Species Traits, #{button}", edge]
    eq "and the focus is dropped with the scene", PokeAccess::RandomizerRV.focus, nil

    SpeakCapture.clear
    scene = RandomizerScene.new(rv_taps(:k, :l, :k, :right, :k, :c, :c, :k, :k, [:shift, :right]))
    eq "an arrow steps the option slider, confirm ticks and unticks, shift steps by ten up to the end",
       SpeakCapture.lines[4..-1],
       ["Random", "Follow Evolutions, #{rv_t(:rv_randomizer_checkbox)}, #{rv_t(:rv_randomizer_unchecked)}",
        rv_t(:rv_randomizer_checked), rv_t(:rv_randomizer_unchecked), "Types:",
        "Dual Type Chance:, #{rv_t(:rv_randomizer_slider)}, 50%", "100%"]
    eq "and the scene's loop took each change as a click, through the controls' own setters",
       [scene.settings[:stats], scene.settings[:follow], scene.settings[:dual]], [1, [true, false], 100]

    SpeakCapture.clear
    scene = RandomizerScene.new(rv_taps(:k, :right, :c, :left))
    eq "on a button the arrows step nothing and confirm presses it: no Cancel, no Done", scene.seen, []
    eq "and pressing the button of the page already on screen still says its heading",
       SpeakCapture.lines[1..-1], ["Species Traits, #{button}", "Base Stats:"]

    SpeakCapture.clear
    scene = RandomizerScene.new(rv_taps(:k, :k, :c, :l, :k, :k, :right, :k, :c, "12", :enter, :j, :i, :c))
    eq "a page button puts its page up and says its heading; the number slider steps; the seed field types " \
       "until Enter; left from the page lands on the nearest sidebar row",
       SpeakCapture.lines[1..-1],
       ["Species Traits, #{button}", "Trainers, #{button}", "Trainer Options:",
        "Have all trainers randomize, #{rv_t(:rv_randomizer_checkbox)}, #{rv_t(:rv_randomizer_unchecked)}",
        "Evolution Level:", "Evolution Level:, #{rv_t(:rv_randomizer_slider)}, 30", "31",
        "Enter a custom seed:, #{rv_t(:rv_randomizer_text)}, #{rv_t(:rv_randomizer_empty)}",
        rv_t(:rv_randomizer_typing), "12", "Done, #{button}", "Cancel, #{button}"]
    eq "the scene saw the page change, the slider, the typing and Cancel",
       [scene.mainwin.equal?(scene.pages[1]), scene.settings[:evo_level], scene.seen], [true, 31, [:typed, :cancel]]
    eq "and the field holds the text, no longer captured", [scene.seed.text, scene.seed.captured?], ["12", false]
  ensure
    RvRandKeys.remove
  end
end
