# Sky's animated species picture (games/skyflyer_common/animated_pokemon.rb), as pbMostrarPkmnAnimado shows a starter
# or a gift: the species, the shiny word for a shiny Pokemon and the type its background paints, said as it comes up.

# The picture as the game draws it: the background only when one is asked for and its type's picture exists (a seam
# here), the Pokemon's sprite always; the reader file is evaluated over it below, since hooks bind at load.
class MostrarPokemonAnimado
  class << self
    attr_accessor :background_found
  end
  self.background_found = true

  def initialize(pokemon, bg = false); @pokemon = pokemon; @bg = bg; @sprites = {}; end

  def mostrar_poke_animado
    @sprites["bg"] = :background if @bg && self.class.background_found
    @sprites["poke_sprite"] = :sprite
    :shown
  end
end
animated_path = File.join(Harness::ROOT, "games", "skyflyer_common", "animated_pokemon.rb")
eval(Harness.source(animated_path), TOPLEVEL_BINDING, animated_path)

class SkyAnimatedPokemonGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # A Pokemon with types of its own, which the background follows rather than its species'.
  Typed = Struct.new(:species, :types) do
    def shiny?; false; end
  end

  # The Monotype challenge as the picture asks it: running, with the type it holds the run to.
  module Monotype
    def self.enabled?; true; end
    def self.type; :WATER; end
  end

  test "says a species and the type its background paints, queued, as the picture comes up" do
    assert_equal :shown, show(:BULBASAUR, true), "the picture's own result"
    assert_equal [["SpeciesBULBASAUR, #{type('TypeTYPE1')}", false]], SpeakCapture.log
  end

  test "says the species alone when the picture has no background, asked for or found" do
    show(:BULBASAUR, false)
    without_background_picture { show(:CHARMANDER, true) }
    assert_equal ["SpeciesBULBASAUR", "SpeciesCHARMANDER"], SpeakCapture.lines
  end

  test "says a shiny Pokemon with the shiny word before the type" do
    show(Poke.build(:species => :PIKACHU, :shiny => true), true)
    assert_equal ["SpeciesPIKACHU, #{T.t(:pk_shiny)}, #{type('TypeTYPE1')}"], SpeakCapture.lines
  end

  test "says the first of a Pokemon's own types, the one its background paints" do
    show(Typed.new(:ROTOM, [:ELECTRIC, :GHOST]), true)
    assert_equal ["SpeciesROTOM, #{type('TypeELECTRIC')}"], SpeakCapture.lines
  end

  test "says the type of a running Monotype challenge, which the background paints instead" do
    with_monotype { show(Typed.new(:ROTOM, [:ELECTRIC, :GHOST]), true) }
    assert_equal ["SpeciesROTOM, #{type('TypeWATER')}"], SpeakCapture.lines
  end

  test "says nothing for a picture whose species has no name" do
    with_unnamed_species { show(:MISSINGNO, true) }
    assert_nothing_spoken
  end

  private

  # Shows the picture of a species or a Pokemon, with or without a background.
  def show(pokemon, bg)
    MostrarPokemonAnimado.new(pokemon, bg).mostrar_poke_animado
  end

  # The words for the type the background paints.
  def type(name)
    T.t(:bt_type, :t => name)
  end

  # Runs the block with the background's picture missing from the game's folder.
  def without_background_picture
    MostrarPokemonAnimado.background_found = false
    yield
  ensure
    MostrarPokemonAnimado.background_found = true
  end

  # Runs the block with a Monotype challenge running, taken away after.
  def with_monotype
    Object.const_set(:MonotypeChallenge, Monotype)
    yield
  ensure
    Object.send(:remove_const, :MonotypeChallenge) if Object.const_defined?(:MonotypeChallenge)
  end

  # Runs the block with the game's species data naming no species.
  def with_unnamed_species
    real = GameData::Species.instance_method(:name)
    GameData::Species.send(:define_method, :name) { "" }
    yield
  ensure
    GameData::Species.send(:define_method, :name, real)
  end
end
