# Pokemon Z's animated species picture (games/pokemon_z/animated_pokemon.rb), as its random starters show it: the
# species it was given (a number, a symbol or a Pokemon) said with the type its background shows, as it comes up.

# The picture as the game draws it; the profile file is evaluated again over it below, since hooks bind at load.
class MostrarPokemonAnimado
  def initialize(pokemon, bg = false); @pokemon = pokemon; @bg = bg; end
  def mostrar_poke_animado; @estado = :fadein; end
end

begin
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "games", "pokemon_z", "animated_pokemon.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

class AnimatedPokemonTest < PokeAccessTest
  # An engine's species data where Pikachu (25) has no type, and species 26 and 27, of one type, have no name.
  class SparseData
    NAMES = { 25 => "Pikachu", 26 => nil, 27 => "  " }
    def self.species_name(id); NAMES[id]; end
    def self.species_types(id); id == 25 ? [] : ["Tipo13"]; end
  end

  test "says a species number's name and its type, queued, as the picture comes up" do
    show(25)
    assert_equal [[line("Especie25", "Tipo13"), false]], SpeakCapture.log
  end

  test "says only the first of two types, the one its background shows" do
    show(7)
    assert_equal [line("Especie7", "Tipo1")], SpeakCapture.lines
  end

  test "reads a species symbol as the number the game keys it by, the first species' too" do
    PBSpecies.const_set(:BULBASAUR, 1)
    PBSpecies.const_set(:PIKACHU, 25)
    show(:PIKACHU)
    show(:BULBASAUR)
    assert_equal [line("Especie25", "Tipo13"), line("Especie1", "Tipo1")], SpeakCapture.lines
  ensure
    [:BULBASAUR, :PIKACHU].each { |c| PBSpecies.send(:remove_const, c) if PBSpecies.const_defined?(c, false) }
  end

  test "says nothing for a symbol the game has no species for" do
    show(:MISSINGNO)
    assert_nothing_spoken
  end

  test "says a Pokemon's species with its own first type, of one type or of two" do
    { [10, 10] => "Tipo10", [10, 11] => "Tipo10" }.each do |(first, second), type|
      SpeakCapture.clear
      show(typed_pokemon(4, first, second))
      assert_equal [line("Especie4", type)], SpeakCapture.lines, "for types #{first} and #{second}"
    end
  end

  test "says the species' name alone where its data gives it no type" do
    Harness.with_provider(SparseData) { show(25) }
    assert_equal ["Pikachu"], SpeakCapture.lines
  end

  test "says nothing for a species with no name, or a blank one" do
    Harness.with_provider(SparseData) { [26, 27].each { |species| show(species) } }
    assert_nothing_spoken
  end

  test "keeps the picture's own return" do
    assert_equal :fadein, MostrarPokemonAnimado.new(25, true).mostrar_poke_animado
  end

  private

  # Shows the animated picture of a species number, symbol or Pokemon.
  def show(pokemon)
    MostrarPokemonAnimado.new(pokemon, true).mostrar_poke_animado
  end

  # A Pokemon of a species with its own two type numbers, the same number for a single-typed one.
  def typed_pokemon(species, type1, type2)
    pk = Poke.build(:species => species)
    pk.define_singleton_method(:type1) { type1 }
    pk.define_singleton_method(:type2) { type2 }
    pk
  end

  # The line said for a species' name and its type's name.
  def line(name, type)
    "#{name}, #{PokeAccess::I18n.t(:bt_type, :t => type)}"
  end
end
