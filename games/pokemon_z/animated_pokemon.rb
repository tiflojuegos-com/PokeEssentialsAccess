# Pokemon Z's animated species picture (MostrarPokemonAnimado, drawn by pbMostrarPkmnAnimado for its random
# starters): the Pokemon's sprite over a background of its first type, with no text, said as it comes up.
module PokeAccess
  module ZAnimatedPokemon
    # The species a shown value stands for: a Pokemon object's own, else the value itself (a symbol or a number).
    def self.species_of(shown)
      shown.respond_to?(:species) ? shown.species : shown
    end

    # A species as the key the game's data takes: its number for a symbol (nil for one it lacks), any other value as
    # it comes.
    def self.species_key(species)
      return species unless species.is_a?(Symbol) && !defined?(GameData)
      id = (getID(PBSpecies, species) rescue nil)
      (id.is_a?(Integer) && id > 0) ? id : nil
    end

    # The type the background shows (fondo_poke_<type1>): a Pokemon's own first type, else its species'.
    def self.type_of(shown, key)
      list = shown.respond_to?(:species) ? PokeAccess::Data.pokemon_types(shown) : PokeAccess::Data.species_types(key)
      (list || []).compact.first
    end

    # The shown Pokemon as its species' name and its background's type, or nil when its species has no name.
    def self.text(shown)
      key = species_key(species_of(shown))
      return nil if key.nil?
      name = PokeAccess::Data.species_name(key)
      return nil if name.nil? || name.to_s.strip.empty?
      type = type_of(shown, key)
      type ? "#{name}, #{PokeAccess::I18n.t(:bt_type, :t => type)}" : name.to_s
    rescue StandardError
      nil
    end

    # Says the picture's Pokemon, queued after what is being said.
    def self.announce(picture)
      t = text(PokeAccess.ivar(picture, :@pokemon))
      PokeAccess.speak_clean(t, false) if t
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  after("MostrarPokemonAnimado", :mostrar_poke_animado, :optional => true) do |pic, _r, _a|
    PokeAccess::ZAnimatedPokemon.announce(pic)
  end
end
