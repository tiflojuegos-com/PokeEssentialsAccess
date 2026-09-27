# Relict's plate prompt (games/relict/plates.rb), gamedata pass: the "[D Key]" beside the battle menus' prompts, the
# only sign that D opens the Arcy Plate selector, is said once a round as a key hint, with the key the player uses.
class Battle::Scene
  # The prompts slide in (or show at once) with the command and fight menus, the plate sprite with them; a battle's
  # first slide starts from the sprite's full width off screen and stops short of it (@plate_lands_at).
  def pbRefreshUIPrompt(_idx = nil, _window = nil)
    @sprites["plate"].visible = true
    @sprites["plate"].x = @plate_lands_at || 0
    :shown
  end

  def pbActivateArcyPlates; :picked; end
  def rewriteArcyPlates(_plates, _index); :drawn; end
end

RelictPlateSprite = Struct.new(:visible, :opacity, :x) unless defined?(RelictPlateSprite)

unless $relict_plates_loaded
  $relict_plates_loaded = true
  load File.expand_path("../../../games/relict/plates.rb", File.dirname(__FILE__))
end

Suite.define("relict plates: the [D Key] prompt is said once a round, as a hint, with the key in use") do
  t = PokeAccess::I18n
  battle = Struct.new(:turnCount).new(0)
  scene = Battle::Scene.new
  scene.instance_variable_set(:@sprites, { "plate" => RelictPlateSprite.new(false, 255, -640) })
  scene.instance_variable_set(:@battle, battle)
  scene.instance_variable_set(:@plate_lands_at, -476)
  SpeakCapture.clear
  eq "the menu's prompt still shows", scene.pbRefreshUIPrompt(nil, 0), :shown
  silent "the battle's first slide leaves the plate off screen: nothing yet"
  scene.instance_variable_set(:@plate_lands_at, 0)
  scene.pbRefreshUIPrompt(nil, 1)
  eq "said queued once it is on screen", SpeakCapture.log, [[t.t(:rel_plates_hint, :key => "D"), false]]
  SpeakCapture.clear
  scene.pbRefreshUIPrompt(nil, 0)
  silent "not again in the same round"
  battle.turnCount = 1
  scene.pbRefreshUIPrompt(nil, 0)
  eq "a new round says it again", SpeakCapture.lines, [t.t(:rel_plates_hint, :key => "D")]

  begin
    PokeAccess::Config.rebinds = { :z => 0x46 }
    battle.turnCount = 2
    SpeakCapture.clear
    scene.pbRefreshUIPrompt(nil, 0)
    eq "a remapped button names the key it moved to", SpeakCapture.lines,
       [t.t(:rel_plates_hint, :key => PokeAccess::ConfigMenu.keyname(0x46))]
  ensure
    PokeAccess::Config.rebinds = {}
  end

  PokeAccess::Config.verbosity = :brief
  begin
    battle.turnCount = 3
    SpeakCapture.clear
    scene.pbRefreshUIPrompt(nil, 0)
    silent "without hints, silent"
  ensure
    PokeAccess::Config.verbosity = :full
  end

  bare = Battle::Scene.new
  bare.instance_variable_set(:@sprites, { "plate" => RelictPlateSprite.new(false, 0, 0) })
  bare.instance_variable_set(:@battle, Struct.new(:turnCount).new(0))
  SpeakCapture.clear
  bare.pbRefreshUIPrompt(nil, 0)
  silent "with no plate in the bag (the icon's opacity 0), nothing"
end
