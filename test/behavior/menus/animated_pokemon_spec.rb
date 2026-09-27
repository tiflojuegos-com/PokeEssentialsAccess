# Pokemon Z's animated species picture (MostrarPokemonAnimado), as its random starters show it: the species it was
# given, a number or a symbol, or a Pokemon, said with the type its background shows as the picture comes up. The class is defined here the way the
# game draws it, and the profile file re-evaluated over it, since hooks bind at load.
class MostrarPokemonAnimado
  def initialize(pokemon, bg = false); @pokemon = pokemon; @bg = bg; end
  def mostrar_poke_animado; @estado = :fadein; end
end

begin
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "games", "pokemon_z", "animated_pokemon.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

Suite.define("animated pokemon: the random starter's picture says its species and types, queued") do
  SpeakCapture.clear
  MostrarPokemonAnimado.new(25, true).mostrar_poke_animado
  eq "a species number: its name and the types its dex data gives, after what is being said", SpeakCapture.log,
     [["Especie25, tipo Tipo13", false]]

  SpeakCapture.clear
  MostrarPokemonAnimado.new(7, true).mostrar_poke_animado
  eq "two types: only the first, the one its background shows", SpeakCapture.lines, ["Especie7, tipo Tipo1"]

  PBSpecies.const_set(:PIKACHU, 25) unless PBSpecies.const_defined?(:PIKACHU)
  begin
    SpeakCapture.clear
    MostrarPokemonAnimado.new(:PIKACHU, true).mostrar_poke_animado
    eq "a species symbol reads as the number the game keys it by", SpeakCapture.lines, ["Especie25, tipo Tipo13"]
  ensure
    PBSpecies.send(:remove_const, :PIKACHU) if PBSpecies.const_defined?(:PIKACHU)
  end

  SpeakCapture.clear
  MostrarPokemonAnimado.new(:MISSINGNO, true).mostrar_poke_animado
  silent "a symbol the game has no species for says nothing"

  pk = Poke.build(:species => 4)
  def pk.type1; 10; end
  def pk.type2; 10; end
  SpeakCapture.clear
  MostrarPokemonAnimado.new(pk, true).mostrar_poke_animado
  eq "a Pokemon: its species and its own types", SpeakCapture.lines, ["Especie4, tipo Tipo10"]
end
