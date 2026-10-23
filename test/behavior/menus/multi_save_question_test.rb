# Multi Save (plugins/multi_save.rb): the slot submenu says the question its message window opens with, queued, and
# the slot's detail box is said once while it stays and again on each return to it.

# The submenu's message window.
class MultiSaveSpecWindow
  attr_reader :text
  def initialize(text); @text = text; end
end

# Binds the plugin's hooks again, its file from the first hook on: they bound at boot, before these classes existed.
multi_save_path = File.join(Harness::ROOT, "plugins", "multi_save.rb")
bind_multi_save = lambda do
  src = Harness.source(multi_save_path)
  at = src.index(/^PokeAccess::Hooks\./)
  eval(src[at..-1], TOPLEVEL_BINDING, multi_save_path, src[0, at].count("\n") + 1)
end

# The stock save screen and save scene, as a game without the plugin has them: bound first, the plugin's methods
# absent, then reopened with them below.
class PokemonSaveScreen
  attr_accessor :question
  def initialize(scene = Object.new); @scene = scene; @question = "Which slot to save in?"; end
end
class PokemonSave_Scene; end
bind_multi_save.call

# The engine's layout function, which every copy calls on its question window as soon as it is built.
def pbBottomLeftLines(window, _lines, _width = nil); window; end

# The plugin's slot submenu: the question window (each copy in its own words), a frame of the submenu's loop (the
# block), then a later window; with no slots to offer it fails before its question. And the scene's detail box,
# rebuilt every frame.
class PokemonSaveScreen
  def slotSelectCommands(choices, _info, _default = 0)
    raise ArgumentError, "no slots" if choices.nil?
    pbBottomLeftLines(MultiSaveSpecWindow.new(@question), 2)
    yield if block_given?
    pbBottomLeftLines(MultiSaveSpecWindow.new("Overwrite the save?"), 2)
    0
  end
end
class PokemonSave_Scene
  def pbUpdateSlotInfo(text); text; end
end
bind_multi_save.call

class MultiSaveQuestionTest < PokeAccessTest
  test "the submenu's question is said, queued, as its window is laid out, and no later window" do
    PokemonSaveScreen.new.slotSelectCommands([], [])
    assert_equal [["Which slot to save in?", false]], SpeakCapture.log
  end

  test "a submenu on a screen holding no scene still says its question" do
    PokemonSaveScreen.new(nil).slotSelectCommands([], [])
    assert_equal [["Which slot to save in?", false]], SpeakCapture.log
  end

  test "the hooked submenu and detail box keep their own return values" do
    assert_equal 0, PokemonSaveScreen.new.slotSelectCommands([], [])
    assert_equal "Vacío", PokemonSave_Scene.new.pbUpdateSlotInfo("Vacío")
  end

  test "after the submenu a window's layout says nothing" do
    PokemonSaveScreen.new.slotSelectCommands([], [])
    SpeakCapture.clear
    pbBottomLeftLines(MultiSaveSpecWindow.new("Hola."), 2)
    assert_nothing_spoken
  end

  test "a submenu that fails before its question leaves no question armed" do
    assert_raises(ArgumentError) { PokemonSaveScreen.new.slotSelectCommands(nil, []) }
    pbBottomLeftLines(MultiSaveSpecWindow.new("Hola."), 2)
    assert_nothing_spoken
  end

  test "a question window with no text says nothing, and no later window takes its turn" do
    screen = PokemonSaveScreen.new
    screen.question = ""
    screen.slotSelectCommands([], [])
    assert_nothing_spoken
  end

  test "the slot's detail box is said queued, its fields as pauses" do
    PokemonSave_Scene.new.pbUpdateSlotInfo("Ruta 5<r>12:30")
    assert_equal [["Ruta 5, 12:30", false]], SpeakCapture.log
  end

  test "an empty detail box says nothing" do
    PokemonSave_Scene.new.pbUpdateSlotInfo("<r>")
    assert_nothing_spoken
  end

  test "the same detail box again says nothing" do
    scene = PokemonSave_Scene.new
    scene.pbUpdateSlotInfo("Vacío")
    SpeakCapture.clear
    scene.pbUpdateSlotInfo("Vacío")
    assert_nothing_spoken
  end

  test "a move onto a slot that reads alike says its detail again" do
    with_jump_keys do
      { "a press" => [:trigger?, :DOWN], "a held repeat" => [:repeat?, :UP],
        "a page down" => [:trigger?, :JUMPDOWN], "a held page up" => [:repeat?, :JUMPUP] }.each do |what, (query, name)|
        scene = PokemonSave_Scene.new
        scene.pbUpdateSlotInfo("Vacío")
        SpeakCapture.clear
        key = Input.const_get(name)
        with_input(query, lambda { |k| k == key }) { scene.pbUpdateSlotInfo("Vacío") }
        assert_equal [["Vacío", false]], SpeakCapture.log, what
      end
    end
  end

  test "a key off the slot list is no move" do
    scene = PokemonSave_Scene.new
    scene.pbUpdateSlotInfo("Vacío")
    SpeakCapture.clear
    with_input(:trigger?, lambda { |k| k == Input::LEFT }) { scene.pbUpdateSlotInfo("Vacío") }
    assert_nothing_spoken
  end

  test "a key query that fails counts as no move" do
    scene = PokemonSave_Scene.new
    scene.pbUpdateSlotInfo("Vacío")
    SpeakCapture.clear
    with_input(:trigger?, lambda { |_k| raise "no input" }) { scene.pbUpdateSlotInfo("Vacío") }
    assert_nothing_spoken
  end

  test "the detail box is said again under the submenu's question and back on the list" do
    scene = PokemonSave_Scene.new
    screen = PokemonSaveScreen.new(scene)
    scene.pbUpdateSlotInfo("Vacío")
    SpeakCapture.clear
    screen.slotSelectCommands([], []) { scene.pbUpdateSlotInfo("Vacío") }
    assert_equal [["Which slot to save in?", false], ["Vacío", false]], SpeakCapture.log, "under the question"
    SpeakCapture.clear
    scene.pbUpdateSlotInfo("Vacío")
    assert_equal [["Vacío", false]], SpeakCapture.log, "back on the list"
  end

  test "binding to a game without the plugin reports nothing missing" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\APokemonSave(Screen|_Scene)#/)
  end

  private

  # Runs the block with the paging keys (Input::JUMPUP, Input::JUMPDOWN) defined where the stubs lack them; the ones
  # it defined are removed after.
  def with_jump_keys
    added = [[:JUMPUP, 101], [:JUMPDOWN, 102]].reject { |k, _v| Input.const_defined?(k, false) }
    added.each { |k, v| Input.const_set(k, v) }
    yield
  ensure
    (added || []).each { |k, _v| Input.send(:remove_const, k) }
  end

  # Runs the block with Input's query (trigger? or repeat?) answered by answer, a lambda of the key; the stub's own
  # answer is put back after.
  def with_input(query, answer)
    saved = Input.method(query)
    Input.define_singleton_method(query, &answer)
    yield
  ensure
    Input.define_singleton_method(query, saved)
  end
end
