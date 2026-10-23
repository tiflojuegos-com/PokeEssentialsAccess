# Relict's Arcy Plates (games/relict/plates.rb): the "[D Key]" prompt beside the battle menus' prompts, the only sign
# that D opens the plate selector, said once a round as a key hint; and the selector's focused plate, by name and type.
class Battle::Scene
  # The prompts slide in (or show at once) with the command and fight menus, the plate sprite with them, unless the
  # game's prompt option is off (@prompts_off). The slide's frames redraw the databoxes; a battle's first slide starts
  # from the sprite's full width off screen and stops short of it (@plate_lands_at).
  def pbRefreshUIPrompt(_idx = nil, _window = nil)
    return :off if @prompts_off
    @sprites.each { |key, sprite| sprite.refresh if key.start_with?("dataBox_") }
    @sprites["plate"].visible = true
    @sprites["plate"].x = @plate_lands_at || 0
    :shown
  end

  # The plate selector opening, and its repaint of the plate at index as the cursor moves.
  def pbActivateArcyPlates; :picked; end
  def rewriteArcyPlates(_plates, _index); :drawn; end
end

# The game's plate table (ArcyPlateChange.rb), each plate with the type it gives; two plates are enough here.
PLATE_TYPES = { :FLAMEPLATE => :FIRE, :SPLASHPLATE => :WATER } unless defined?(PLATE_TYPES)

unless defined?(PokeAccess::RelictPlates)
  relict_plates = File.join(Harness::ROOT, "games", "relict", "plates.rb")
  eval(Harness.source(relict_plates), TOPLEVEL_BINDING, relict_plates)
end

class RelictPlatesGdTest < PokeAccessTest
  # The prompt's plate icon: shown with the prompts, drawn transparent while the bag holds no plate.
  PlateSprite = Struct.new(:visible, :opacity, :x)
  # The plates the bag holds, in the selector's order.
  PLATES = [:FLAMEPLATE, :SPLASHPLATE]

  test "says the prompt as a key hint, queued, with the D key the game paints" do
    plate_scene.pbRefreshUIPrompt(nil, 0)
    assert_equal [[hint("D"), false]], SpeakCapture.log
  end

  test "waits for the plate to land on screen, then says it in that same round" do
    scene = plate_scene
    scene.instance_variable_set(:@plate_lands_at, -476)
    scene.pbRefreshUIPrompt(nil, 0)
    assert_nothing_spoken "the battle's first slide leaves the plate off screen"
    scene.instance_variable_set(:@plate_lands_at, 0)
    scene.pbRefreshUIPrompt(nil, 1)
    assert_equal [[hint("D"), false]], SpeakCapture.log, "once it is on screen"
  end

  test "says the prompt once a round" do
    scene = plate_scene
    scene.pbRefreshUIPrompt(nil, 0)
    scene.pbRefreshUIPrompt(nil, 1)
    assert_equal [hint("D")], SpeakCapture.lines
  end

  test "says the prompt again in a new round" do
    scene = plate_scene
    scene.pbRefreshUIPrompt(nil, 0)
    SpeakCapture.clear
    scene.instance_variable_get(:@battle).turnCount = 1
    scene.pbRefreshUIPrompt(nil, 0)
    assert_equal [[hint("D"), false]], SpeakCapture.log
  end

  test "names the key the player moved the button to" do
    PokeAccess::Config.rebinds = { :z => 0x46 }
    plate_scene.pbRefreshUIPrompt(nil, 0)
    assert_equal [hint(PokeAccess::ConfigMenu.keyname(0x46))], SpeakCapture.lines
  end

  test "stays silent without key hints" do
    PokeAccess::Config.verbosity = :brief
    plate_scene.pbRefreshUIPrompt(nil, 0)
    assert_nothing_spoken
  end

  test "says the prompt only while its icon is drawn at all: none with no plate in the bag" do
    { 0 => [], 1 => [hint("D")] }.each do |opacity, want|
      SpeakCapture.clear
      plate_scene(opacity).pbRefreshUIPrompt(nil, 0)
      assert_equal want, SpeakCapture.lines, "at opacity #{opacity}"
    end
  end

  test "stays silent while the game's prompts are off, the plate left hidden" do
    scene = plate_scene
    scene.instance_variable_set(:@prompts_off, true)
    scene.pbRefreshUIPrompt(nil, 0)
    assert_nothing_spoken
  end

  test "stays silent in a scene with no battle round" do
    scene = plate_scene
    scene.instance_variable_set(:@battle, nil)
    scene.pbRefreshUIPrompt(nil, 0)
    assert_nothing_spoken
  end

  test "leaves the hooks inside the prompts' slide speaking: a foe's databox drawn there is read" do
    scene = plate_scene
    box = Battle::Scene::PokemonDataBox.new(Struct.new(:index, :name, :pokemon).new(1, "Pidgey", Object.new))
    box.owned = true
    scene.instance_variable_get(:@sprites)["dataBox_1"] = box
    scene.pbRefreshUIPrompt(nil, 0)
    marks = PokeAccess::I18n.t(:bt_marks_entry, :name => "Pidgey", :marks => PokeAccess::I18n.t(:dex_caught))
    assert_equal [[marks, false], [hint("D"), false]], SpeakCapture.log
  end

  test "says each plate the cursor moves to by name and type, interrupting" do
    scene = plate_scene
    scene.rewriteArcyPlates(PLATES, 0)
    scene.rewriteArcyPlates(PLATES, 1)
    assert_equal [[plate_line(:FLAMEPLATE, :FIRE), true], [plate_line(:SPLASHPLATE, :WATER), true]], SpeakCapture.log
  end

  test "says a plate once while the cursor stays on it" do
    scene = plate_scene
    scene.rewriteArcyPlates(PLATES, 1)
    scene.rewriteArcyPlates(PLATES, 1)
    assert_equal [plate_line(:SPLASHPLATE, :WATER)], SpeakCapture.lines
  end

  test "says the focused plate again once the selector opens anew" do
    scene = plate_scene
    scene.rewriteArcyPlates(PLATES, 1)
    SpeakCapture.clear
    scene.pbActivateArcyPlates
    scene.rewriteArcyPlates(PLATES, 1)
    assert_equal [plate_line(:SPLASHPLATE, :WATER)], SpeakCapture.lines
  end

  test "says a plate's name alone where the plate table gives it no type" do
    plate_scene.rewriteArcyPlates([:LEGENDPLATE], 0)
    assert_equal [GameData::Item.get(:LEGENDPLATE).name], SpeakCapture.lines
  end

  test "says nothing for a cursor outside the plates" do
    { "before the first" => [PLATES, -1], "past the last" => [PLATES, 2], "no index" => [PLATES, nil],
      "no list" => [nil, 0] }.each do |what, (plates, index)|
      plate_scene.rewriteArcyPlates(plates, index)
      assert_nothing_spoken "for #{what}"
    end
  end

  private

  # The prompt as the mod says it, with the key named.
  def hint(key)
    PokeAccess::I18n.t(:rel_plates_hint, :key => key)
  end

  # A plate as the selector line says it: the item's name and the type it gives, as the game's data names them.
  def plate_line(item, type)
    "#{GameData::Item.get(item).name}, #{GameData::Type.get(type).name}"
  end

  # A battle scene in its first round whose plate icon is hidden until the prompts show, at the given opacity.
  def plate_scene(opacity = 255)
    scene = Battle::Scene.new
    scene.instance_variable_set(:@sprites, { "plate" => PlateSprite.new(false, opacity, -640) })
    scene.instance_variable_set(:@battle, Struct.new(:turnCount).new(0))
    scene
  end
end
