# Battle.announce_field: a fork's battlefield, the weather, rooms and terrain, then each side's screens and hazards,
# the player's first; a section that raises drops only itself, nothing on is said so, and out of battle the overworld.
class AnnounceFieldTest < PokeAccessTest
  # A gen-6 battle as the field key reads it: the weather pbWeather reports, and the @field and @sides it keeps.
  class FieldBattle
    def initialize(weather, field = nil, sides = nil)
      @weather = weather
      @field = field
      @sides = sides
    end

    def pbWeather; @weather; end
  end

  # A battle from before pbWeather, whose weather is its weather attribute.
  OldBattle = Struct.new(:weather)

  # A field, a side or a battle state: its effects by id.
  Effects = Struct.new(:effects)

  # The Reborn engine's battlefield, by its id.
  Battlefield = Struct.new(:effect)

  # A modern field, which keeps its terrain as a symbol.
  ModernField = Struct.new(:effects, :terrain)

  # A battle whose kept fields cannot be read.
  class SealedBattle < FieldBattle
    def instance_variable_get(_name); raise "boom"; end
  end

  # A field or a side list whose every read raises.
  class Broken
    def effects; raise "boom"; end
    def respond_to?(*_args); raise "boom"; end
    def [](_index); raise "boom"; end
  end

  test "out of battle says the overworld's weather instead" do
    with_screen_weather(1) do
      assert_equal [[t(:bt_weather, :w => t(:w_rain)), true]], field_of(nil)
    end
  end

  test "says the weather whichever way the battle reports it" do
    { FieldBattle.new(1) => t(:bt_weather, :w => t(:w_sun)),
      OldBattle.new(2) => t(:bt_weather, :w => t(:w_rain)),
      FieldBattle.new(:Hail) => t(:bt_weather, :w => t(:w_hail)) }.each do |battle, line|
      assert_equal [[line, true]], field_of(battle), "for #{battle.inspect}"
    end
  end

  test "says the Reborn engine's battlefield first, by its name, and nothing for its plain indoor one" do
    sun = t(:bt_weather, :w => t(:w_sun))
    with_battlefields(:FOREST => "Bosque", :INDOOR => "Interior") do
      { :FOREST => [t(:bt_field_effect, :f => "Bosque"), sun].join(", "), :INDOOR => sun }.each do |effect, line|
        assert_equal [[line, true]], field_of(on_battlefield(effect)), "on #{effect.inspect}"
      end
    end
  end

  test "says that no condition is on when none is" do
    battle = FieldBattle.new(0, Effects.new({}), [Effects.new({}), Effects.new({ PBEffects::Spikes => 0 })])
    assert_equal [[t(:bt_no_field), true]], field_of(battle)
  end

  test "names trick room and gravity while their turns last" do
    { { PBEffects::TrickRoom => 3 } => [t(:bt_trickroom)],
      { PBEffects::Gravity => 5 } => [t(:bt_gravity)],
      { PBEffects::TrickRoom => 1, PBEffects::Gravity => 2 } => [t(:bt_trickroom), t(:bt_gravity)],
      { PBEffects::TrickRoom => 0, PBEffects::Gravity => 0 } => [t(:bt_no_field)] }.each do |effects, parts|
      assert_equal [[parts.join(", "), true]], field_of(FieldBattle.new(0, Effects.new(effects))), "for #{effects.inspect}"
    end
  end

  test "names the terrain a gen-6 field keeps among its effects while it lasts" do
    { { PBEffects::GrassyTerrain => 1 } => t(:bt_grassy), { PBEffects::MistyTerrain => 5 } => t(:bt_misty),
      { PBEffects::ElectricTerrain => 2 } => t(:bt_electric), { PBEffects::PsychicTerrain => 3 } => t(:bt_psychic),
      { PBEffects::GrassyTerrain => 0 } => t(:bt_no_field) }.each do |effects, line|
      assert_equal [[line, true]], field_of(FieldBattle.new(0, Effects.new(effects))), "for #{effects.inspect}"
    end
  end

  test "names the terrain a modern field keeps by its symbol, and none for another symbol" do
    { :Electric => t(:bt_electric), :Psychic => t(:bt_psychic), :None => t(:bt_no_field) }.each do |terrain, line|
      battle = FieldBattle.new(0, ModernField.new({ PBEffects::GrassyTerrain => 5 }, terrain))
      assert_equal [[line, true]], field_of(battle), "for #{terrain.inspect}"
    end
  end

  test "a field whose effects cannot be read adds no room nor terrain" do
    assert_equal [[t(:bt_no_field), true]], field_of(FieldBattle.new(0, Object.new))
  end

  test "names the Reborn engine's trick room, gravity and terrain from their counters" do
    counters = { :ELECTERRAIN => 0, :GRASSY => 1, :MISTY => 0, :PSYTERRAIN => 0, :Gravity => -1 }
    assert_equal [[[t(:bt_trickroom), t(:bt_gravity), t(:bt_grassy)].join(", "), true]],
                 field_of(reborn_battle(counters, 1)), "a permanent gravity stands below 0"
  end

  test "a battle state without the Reborn engine's terrain counters leaves the rooms to the field's effects" do
    field = Effects.new({ PBEffects::TrickRoom => 2 })
    states = { "with other counters" => Effects.new({ :Gravity => 3 }), "with no counters to look in" => Effects.new([]) }
    states.each do |what, state|
      battle = FieldBattle.new(0, field)
      battle.instance_variable_set(:@state, state)
      assert_equal [[t(:bt_trickroom), true]], field_of(battle), what
    end
  end

  test "the Reborn engine's counters at 0, and a battle with no Trick Room counter, are off" do
    off = { :ELECTERRAIN => 0, :GRASSY => 0, :MISTY => 0, :PSYTERRAIN => 0, :Gravity => 0 }
    assert_equal [[t(:bt_no_field), true]], field_of(reborn_battle(off, 0)), "every counter at 0"
    assert_equal [[t(:bt_no_field), true]], field_of(reborn_battle(off)), "no Trick Room counter"
  end

  test "names each side's screens and hazards, the player's side first" do
    sides = [Effects.new({ PBEffects::Reflect => 5, PBEffects::Spikes => 1, PBEffects::Tailwind => 0 }),
             Effects.new({ PBEffects::StealthRock => true, PBEffects::ToxicSpikes => 2, PBEffects::StickyWeb => false })]
    line = [side_effect(:bt_reflect, :bt_side_yours), side_effect(:bt_spikes, :bt_side_yours),
            side_effect(:bt_stealthrock, :bt_side_foe), side_effect(:bt_toxicspikes, :bt_side_foe)].join(", ")
    assert_equal [[line, true]], field_of(FieldBattle.new(0, nil, sides))
  end

  test "says the weather, then the rooms and terrain, then the sides" do
    field = Effects.new({ PBEffects::TrickRoom => 2, PBEffects::GrassyTerrain => 3 })
    sides = [nil, Effects.new({ PBEffects::LightScreen => 4 })]
    line = [t(:bt_weather, :w => t(:w_sandstorm)), t(:bt_trickroom), t(:bt_grassy),
            side_effect(:bt_lightscreen, :bt_side_foe)].join(", ")
    assert_equal [[line, true]], field_of(FieldBattle.new(3, field, sides))
  end

  test "a section that raises drops only itself" do
    reflect = Effects.new({ PBEffects::Reflect => 5 })
    gravity = Effects.new({ PBEffects::Gravity => 2 })
    sun = t(:bt_weather, :w => t(:w_sun))
    { "the field" => [FieldBattle.new(1, Broken.new, [reflect]), [sun, side_effect(:bt_reflect, :bt_side_yours)]],
      "the sides" => [FieldBattle.new(1, gravity, Broken.new), [sun, t(:bt_gravity)]],
      "the battle's kept fields" => [SealedBattle.new(1, gravity, [reflect]), [sun]] }.each do |what, (battle, parts)|
      assert_equal [[parts.join(", "), true]], field_of(battle), "with #{what} raising"
    end
  end

  private

  # What the field key says for this battle, as [text, interrupt] pairs.
  def field_of(battle)
    SpeakCapture.clear
    PokeAccess::Battle.set_battle(battle)
    PokeAccess::Battle.announce_field
    SpeakCapture.log.dup
  end

  # The Reborn engine's battle: Gravity and the terrains in its @state's effects, and Trick Room's turns on the battle
  # when given.
  def reborn_battle(effects, trickroom = nil)
    b = Object.new
    b.instance_variable_set(:@state, Effects.new(effects))
    b.define_singleton_method(:trickroom) { trickroom } unless trickroom.nil?
    b
  end

  # A battle under the sun on the Reborn engine's battlefield effect.
  def on_battlefield(effect)
    b = FieldBattle.new(1)
    b.define_singleton_method(:field) { Battlefield.new(effect) }
    b
  end

  # Runs the block with the Reborn engine's $cache naming these battlefields, put back after.
  def with_battlefields(names)
    saved = $cache
    $cache = Struct.new(:FEData).new(names.map { |id, name| [id, Struct.new(:name).new(name)] }.to_h)
    yield
  ensure
    $cache = saved
  end

  # Runs the block with the map's screen under this PBFieldWeather, put back after.
  def with_screen_weather(id)
    saved = $game_screen
    $game_screen = Struct.new(:weather_type).new(id)
    yield
  ensure
    $game_screen = saved
  end

  # A side effect's line, as the field key words it.
  def side_effect(effect, side)
    t(:bt_side_effect, :effect => t(effect), :side => t(side))
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
