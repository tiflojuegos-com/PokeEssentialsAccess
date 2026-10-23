# Royal's new-game screens, gamedata pass: the controls picture said from its transcription with the keys as the
# player has them, each selector's option by what its picture shows, and the random-mode checklist's focused category.

# The difficulty selector: each select* lights one option and answers the game's own value.
class MenuSelector2OpcionesScene
  def selectOpc1; :normal; end
  def selectOpc2; :challenge; end
  def pbEndScene; :closed; end
end

# The gender selector, as Royal draws it: one picture per option.
class GenderSelectorScene
  def selectBoy; :boy; end
  def selectGirl; :girl; end
end

# The skin-tone selector: four portraits in a two-by-two grid.
class TonoPielSelectorScene
  (1..4).each { |n| define_method("selectTono#{n}") { n } }
end

# The random-mode checklist: @select over the four categories, each on while its modifier is in @added (the game's
# list, whose fifth, the static encounters, goes on and off with the encounters); pbUpdate is the screen's loop, each
# frame of which the test's block stands for.
class MenuSelectorRandomScene
  def initialize(added)
    @modifiers = [:TRAINERS, :ENCOUNTERS, :GIFTS, :ITEMS, :STATIC]
    @added = added
    @select = 0
  end

  def pbUpdate
    yield self if block_given?
    :looped
  end
end

# The selectors bind on the stand-ins above. Of the controls screen only the module is evaluated: Anil's hook on the
# same ButtonEventScene#set_up_screen runs in this pass, and a second binding there would speak in its tests too.
begin
  path = File.join(Harness::ROOT, "games", "royal", "selectors.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
  path = File.join(Harness::ROOT, "games", "royal", "controles.rb")
  src = Harness.source(path)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, path, src[0, src.index(part)].count("\n") + 1)
end

class RoyalIntroGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  # Each difficulty's select method and the words its picture shows: [the mode, the sentence under it].
  DIFFICULTIES = { :selectOpc1 => [:rsel_normal, :rsel_normal_desc],
                   :selectOpc2 => [:rsel_challenge, :rsel_challenge_desc] }

  test "says the transcribed controls picture, interrupting, on a screen that registered no paragraph" do
    [nil, {}].each do |labels|
      SpeakCapture.clear
      PokeAccess::RoyalControls.say(controls_scene(labels))
      assert_equal [[I18n.t(:royal_controls), true]], SpeakCapture.log, "paragraphs #{labels.inspect}"
    end
  end

  test "says each key the player rebound with the mod as the one in use, the others as painted" do
    PokeAccess::Config.rebinds = { :c => 0x4B, :l => 0x4A }
    PokeAccess::RoyalControls.say(controls_scene(nil))
    shown = I18n.t(:royal_controls).sub("C: aceptar", "K: aceptar").sub("Alt o Q:", "Alt o J:")
    assert_equal [[shown, true]], SpeakCapture.log
  end

  test "leaves a screen that registered paragraphs of its own to the core's controls help" do
    PokeAccess::RoyalControls.say(controls_scene(1 => ["Pulsa C para hablar."]))
    assert_nothing_spoken
  end

  test "leaves each selector's own value to the game" do
    { [MenuSelector2OpcionesScene, :selectOpc1] => :normal, [MenuSelector2OpcionesScene, :selectOpc2] => :challenge,
      [MenuSelector2OpcionesScene, :pbEndScene] => :closed, [GenderSelectorScene, :selectGirl] => :girl,
      [TonoPielSelectorScene, :selectTono3] => 3 }.each do |(klass, meth), value|
      assert_equal value, klass.new.send(meth), "#{klass}##{meth}"
    end
    assert_equal :looped, MenuSelectorRandomScene.new([]).pbUpdate, "MenuSelectorRandomScene#pbUpdate"
  end

  test "says a difficulty by its name, and in full the sentence under it" do
    DIFFICULTIES.each do |meth, (name, desc)|
      said = vb_levels do
        SpeakCapture.clear
        MenuSelector2OpcionesScene.new.send(meth)
        SpeakCapture.log.dup
      end
      whole = PokeAccess.sentences([I18n.t(name), I18n.t(desc)])
      assert_equal [[[I18n.t(name), true]], [[I18n.t(name), true]], [[whole, true]]], said, "#{meth} at brief, medium, full"
    end
  end

  test "keeps the difficulty's name and sentence on the info key, whatever the level" do
    DIFFICULTIES.each do |meth, (name, desc)|
      kept = vb_levels do
        PokeAccess::Info.set_info(nil, nil)
        MenuSelector2OpcionesScene.new.send(meth)
        PokeAccess::Info.info_text
      end
      assert_equal [PokeAccess.sentences([I18n.t(name), I18n.t(desc)])] * 3, kept, "#{meth} at brief, medium, full"
    end
  end

  test "takes the difficulty off the info key as the selector closes" do
    scene = MenuSelector2OpcionesScene.new
    scene.selectOpc1
    lit = PokeAccess::Info.info_text
    scene.pbEndScene
    assert_equal [PokeAccess.sentences([I18n.t(:rsel_normal), I18n.t(:rsel_normal_desc)]), nil],
                 [lit, PokeAccess::Info.info_text], "while the mode is lit, then closed"
  end

  test "says each skin-tone portrait by what it shows and its place among the four" do
    (1..4).each { |n| TonoPielSelectorScene.new.send("selectTono#{n}") }
    said = (1..4).map { |n| [I18n.t(:list_entry, :name => I18n.t("rsel_skin_#{n}".to_sym), :n => n, :tot => 4), true] }
    assert_equal said, SpeakCapture.log
  end

  test "drops a portrait's place where positions are left out" do
    said = vb_levels do
      SpeakCapture.clear
      TonoPielSelectorScene.new.selectTono2
      SpeakCapture.lines.dup
    end
    placed = I18n.t(:list_entry, :name => I18n.t(:rsel_skin_2), :n => 2, :tot => 4)
    assert_equal [[I18n.t(:rsel_skin_2)], [placed], [placed]], said, "at brief, medium, full"
  end

  test "says each gender by the word its picture shows" do
    GenderSelectorScene.new.selectBoy
    GenderSelectorScene.new.selectGirl
    assert_equal [[I18n.t(:gsel_boy), true], [I18n.t(:gsel_girl), true]], SpeakCapture.log
  end

  test "reads the checklist's focused category and its state, the first read queued and the next interrupting" do
    scene = MenuSelectorRandomScene.new([:ENCOUNTERS, :STATIC])
    scene.pbUpdate do
      PokeAccess::RoyalRandom.poll
      scene.instance_variable_set(:@select, 1)
      PokeAccess::RoyalRandom.poll
    end
    assert_equal [[row(I18n.t(:rrnd_trainers), false), false], [row(I18n.t(:rrnd_encounters), true), true]],
                 SpeakCapture.log
  end

  test "reads a category once while it stays, and again when it is switched" do
    added = []
    scene = MenuSelectorRandomScene.new(added)
    scene.instance_variable_set(:@select, 3)
    scene.pbUpdate do
      PokeAccess::RoyalRandom.poll
      PokeAccess::RoyalRandom.poll
      added.push(:ITEMS)
      PokeAccess::RoyalRandom.poll
    end
    assert_equal [row(I18n.t(:rrnd_items), false), row(I18n.t(:rrnd_items), true)], SpeakCapture.lines
  end

  test "reads the focused category again, queued, each time the checklist opens" do
    2.times { MenuSelectorRandomScene.new([]).pbUpdate { PokeAccess::RoyalRandom.poll } }
    assert_equal [[row(I18n.t(:rrnd_trainers), false), false]] * 2, SpeakCapture.log
  end

  test "names a place past the four categories by its number, on as the modifier behind it is" do
    { 4 => [row(I18n.t(:rrnd_option, :n => 5), true)], 5 => [row(I18n.t(:rrnd_option, :n => 6), false)] }.each do |place, said|
      SpeakCapture.clear
      scene = MenuSelectorRandomScene.new([:ENCOUNTERS, :STATIC])
      scene.instance_variable_set(:@select, place)
      scene.pbUpdate { PokeAccess::RoyalRandom.poll }
      assert_equal said, SpeakCapture.lines, "place #{place}, the static encounters on"
    end
  end

  test "reads nothing with no category focused" do
    scene = MenuSelectorRandomScene.new([])
    scene.instance_variable_set(:@select, nil)
    scene.pbUpdate { PokeAccess::RoyalRandom.poll }
    assert_nothing_spoken
  end

  test "reads nothing once the checklist's loop is over" do
    scene = MenuSelectorRandomScene.new([])
    scene.pbUpdate
    PokeAccess::RoyalRandom.poll
    assert_nothing_spoken
  end

  private

  # The opening's controls screen with the paragraphs it registered (nil when it registered none).
  def controls_scene(labels)
    scene = ButtonEventScene.new
    scene.instance_variable_set(:@access_labels, labels)
    scene
  end

  # A checklist row as the reader says it: the category's name and whether it is on.
  def row(name, on)
    "#{name}, #{I18n.t(on ? :val_on : :val_off)}"
  end
end
