# Infinite Fusion Hoenn's visible wild Pokemon (games/infinitefusion_hoenn/overworld.rb), gamedata pass: each is named
# by the species its follower sprite shows, never by its template's event name ("OW_normal", "OverworldPokemon"), and
# a roaming legendary by the species its event name carries. The stand-in comes before the profile file loads.
class OverworldPokemonEvent
  attr_accessor :id, :name, :character_name, :species, :pokemon
  def initialize(name, sprite, species)
    @id = 77
    @name = name
    @character_name = sprite
    @species = species
  end
end

ifh_overworld = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "overworld.rb")
eval(Harness.source(ifh_overworld), TOPLEVEL_BINDING, ifh_overworld)

class IfhOverworldGdTest < PokeAccessTest
  Overworld = PokeAccess::IF2Overworld
  Loc = PokeAccess::Locator
  ZIG = "SpeciesZIGZAGOON"

  # One whose sprite cannot be read.
  class BrokenEvent < OverworldPokemonEvent
    def character_name; raise "no sprite"; end
  end

  # On a map no other test tags events on, as the player's tags outlive a test.
  def setup
    super
    $game_map.map_id = 901
  end

  test "names a spawned one by the species its follower sprite shows, not by its template's name" do
    assert_equal wild(ZIG), Loc.target_name(spawned("Followers/ZIGZAGOON", :ZIGZAGOON))
  end

  test "names a static one by its species, its pose left out" do
    %w[fly notice swim].each do |pose|
      ev = OverworldPokemonEvent.new("OverworldPokemon", "Followers/WINGULL_#{pose}", :WINGULL)
      assert_equal wild("SpeciesWINGULL"), Loc.target_name(ev), pose
    end
  end

  test "keeps an underscore of the species' own that is no pose" do
    assert_equal wild("SpeciesMR_MIME"), Loc.target_name(spawned("Followers/MR_MIME", :MR_MIME))
  end

  test "adds the shiny mark its sprite folder shows" do
    assert_equal "#{wild(ZIG)}, #{t(:pk_shiny)}", Loc.target_name(spawned("Followers/Shiny/ZIGZAGOON", :ZIGZAGOON))
  end

  test "names a disguised Ditto as the species it shows" do
    ditto = spawned("Followers/POOCHYENA", :DITTO)
    ditto.instance_variable_set(:@disguised, true)
    assert_equal wild("SpeciesPOOCHYENA"), Loc.target_name(ditto)
  end

  test "names a fusion by its body's silhouette, which never tells which fusion it is" do
    fusion = spawned("Followers/Fusions/ZIGZAGOON", :B263H41)
    fusion.pokemon = Struct.new(:speciesName).new("Zigzarmie")
    assert_equal t(:if2_ow_fusion, :name => ZIG), Loc.target_name(fusion)
  end

  test "names a shiny fusion by its outline, its pose left out" do
    fusion = spawned("Followers/Fusions/Shiny/ZIGZAGOON_swim", :B263H41)
    assert_equal "#{t(:if2_ow_fusion, :name => ZIG)}, #{t(:pk_shiny)}", Loc.target_name(fusion)
  end

  test "names a roaming legendary by the species in its event name" do
    legend = Struct.new(:id, :name, :character_name).new(12, "Legendary(RAIKOU)", "POKEMON_RAIKOU")
    assert_equal wild("SpeciesRAIKOU"), Overworld.wild_name(legend)
  end

  test "names one that draws no follower sprite yet by its own species" do
    assert_equal wild("SpeciesWINGULL"), Overworld.wild_name(spawned("", :WINGULL))
  end

  test "does not name one that draws no follower sprite and is disguised, which that would give away" do
    bare = spawned("", :WINGULL)
    bare.instance_variable_set(:@disguised, true)
    assert_nil Overworld.wild_name(bare)
  end

  test "does not name one that draws no follower sprite and has no species" do
    assert_nil Overworld.wild_name(spawned("", nil))
  end

  test "leaves any other event to the core" do
    plain = Struct.new(:id, :name, :character_name).new(13, "OW_normal", "POKEMON_WINGULL_perched")
    assert_nil Overworld.wild_name(plain)
  end

  test "survives one whose sprite cannot be read" do
    assert_nil Overworld.wild_name(BrokenEvent.new("OW_normal", "", :WINGULL))
  end

  private

  def t(key, opts = {}); PokeAccess::I18n.t(key, opts); end

  # The name said for a wild Pokemon of the species named.
  def wild(name)
    t(:loc_wild, :name => name)
  end

  # One copied from the "OW_normal" template, drawn with sprite.
  def spawned(sprite, species)
    OverworldPokemonEvent.new("OW_normal", sprite, species)
  end
end
