# Skyflyer's rotation battles (plugins/rotation_battle.rb): the command menu's question said again, cutting in, as a
# rotation paints it for the Pokemon now in the centre; the rotation key once as the menu opens, while hints are said
# and the side can rotate; and the hidden fight menu the rotation resets kept quiet.

# The scene's rotation parts as the plugin has them: the button shown as the command menu opens, and a frame's check
# that, on D, rotates the player's side and paints the menu's question for the new centre Pokemon, resetting the hidden
# fight menu as the game's does.
class Battle::Scene
  attr_accessor :rotation_press

  def pbShowRotationButton(idxBattler)
    @rotation_button_idxBattler = idxBattler
  end

  def pbCheckRotationInput(cw = nil)
    return unless @rotation_press
    @rotation_press = false
    name = @battle.rotate
    cw.setTexts(["¿Qué debería hacer\n#{name}?", "Luchar", "Mochila", "Pokémon", "Huir"])
    @sprites["fightWindow"].setIndexAndMode(0, 0)
  end
end

verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "plugins", "rotation_battle.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

class RotationBattleGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # The command menu as far as its question goes: setTexts paints the first text in its message box.
  class Menu
    Box = Struct.new(:text)
    def initialize(question); @msgBox = Box.new(question); end
    def setTexts(texts); @msgBox.text = texts[0]; end
  end

  # The battle as the rotation asks it: whether a side can rotate, and the player's three turning one place.
  class Rotation
    def initialize(names, can = true); @names = names; @can = can; end
    def pbCanRotate?(_side); @can; end
    def rotate; @names.push(@names.shift); @names.first; end
  end

  # The fight menu the rotation resets while it is hidden.
  class Fight < Battle::Scene::MenuBase
    def refresh; end
  end

  test "a rotation says the question the menu paints for the Pokemon now in the centre, cutting in" do
    scene, menu = opened(%w[Pikachu Mareep Zubat])
    rotate(scene, menu)
    rotate(scene, menu)
    assert_equal [["¿Qué debería hacer Mareep?", true], ["¿Qué debería hacer Zubat?", true]], SpeakCapture.log
  end

  test "a frame without a rotation says nothing" do
    scene, menu = opened(%w[Pikachu Mareep])
    2.times { scene.pbCheckRotationInput(menu) }
    assert_nothing_spoken
  end

  test "the rotation key is said once, queued, on the first frame of an opening, while hints are said" do
    said = vb_levels do
      SpeakCapture.clear
      scene, menu = opened(%w[Pikachu Mareep], true, false)
      2.times { scene.pbCheckRotationInput(menu) }
      SpeakCapture.log.dup
    end
    key = [T.t(:hint_label_key, :label => T.t(:rot_rotate), :key => "D"), false]
    assert_equal [[], [key], [key]], said, "at brief, medium, full"
  end

  test "a side that cannot rotate says no key" do
    with_hints do
      scene, menu = opened(%w[Pikachu Mareep], false, false)
      scene.pbCheckRotationInput(menu)
    end
    assert_nothing_spoken
  end

  test "the fight menu the rotation resets, hidden, is kept quiet" do
    scene, menu = opened(%w[Pikachu Mareep])
    rotate(scene, menu)
    assert_equal ["¿Qué debería hacer Mareep?"], SpeakCapture.lines
    assert_includes PokeAccess::Hooks.suppressed, "pbCheckRotationInput>Battle::Scene::MenuBase#setIndexAndMode"
  end

  private

  # A scene whose command menu opened for the first of names, the player's centre Pokemon at slot 2, past the opening
  # frame (its key said or not) unless skip is false; the battle can rotate or not.
  def opened(names, can = true, skip = true)
    scene = Battle::Scene.new
    scene.instance_variable_set(:@battle, Rotation.new(names.dup, can))
    scene.instance_variable_set(:@sprites, { "fightWindow" => Fight.new })
    menu = Menu.new("¿Qué debería hacer\n#{names.first}?")
    scene.pbShowRotationButton(2)
    if skip
      without_hints { scene.pbCheckRotationInput(menu) }
      SpeakCapture.clear
    end
    [scene, menu]
  end

  # One frame of the menu with D pressed.
  def rotate(scene, menu)
    scene.rotation_press = true
    scene.pbCheckRotationInput(menu)
  end

  # Runs the block at the verbosity where hints are said, put back after.
  def with_hints(&block)
    at_verbosity(:medium, &block)
  end

  # Runs the block at the verbosity where no hints are said, put back after.
  def without_hints(&block)
    at_verbosity(:brief, &block)
  end

  def at_verbosity(level)
    PokeAccess::Config.verbosity = level
    yield
  ensure
    PokeAccess::Config.verbosity = :full
  end
end
