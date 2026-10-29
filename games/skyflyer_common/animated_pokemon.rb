module PokeAccess
  # Sky's animated species picture (MostrarPokemonAnimado, shown by pbMostrarPkmnAnimado for a starter or a gift): the
  # Pokemon's sprite, over a background of its type when one is asked for, with no text; said as it comes up. Pokemon
  # Z, on the gen-6 engine, reads its own copy in its profile.
  module SkyAnimatedPokemon
    # The species a shown value stands for: a Pokemon's own, else the value itself (a species id).
    def self.species_of(shown)
      shown.respond_to?(:species) ? shown.species : shown
    end

    # The type the background paints (fondo_poke_<type>): a running Monotype challenge's, else the Pokemon's first type
    # or its species'; nil where the picture drew no background.
    def self.background_type(pic, shown)
      return nil unless (PokeAccess.ivar(pic, :@sprites) || {})["bg"]
      mono = PokeAccess.const_at("MonotypeChallenge")
      return PokeAccess::Data.type_name(mono.type) if mono && (mono.enabled? rescue false)
      types = shown.respond_to?(:types) ? PokeAccess::Data.pokemon_types(shown) : PokeAccess::Data.species_types(shown)
      types.first
    end

    # The picture as said: the species' name, the shiny word for a shiny Pokemon and the background's type; nil when
    # the species has no name.
    def self.text(pic)
      shown = PokeAccess.ivar(pic, :@pokemon)
      name = PokeAccess::Data.species_name(species_of(shown))
      return nil if name.nil? || name.to_s.strip.empty?
      parts = [name.to_s]
      parts.push(PokeAccess::Party.shiny_word(shown)) if (shown.shiny? rescue false)
      type = background_type(pic, shown)
      parts.push(PokeAccess::I18n.t(:bt_type, :t => type)) if type
      parts.join(", ")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("MostrarPokemonAnimado", :mostrar_poke_animado, :optional => true) do |pic, _r, _a|
  t = PokeAccess::SkyAnimatedPokemon.text(pic)
  PokeAccess.speak_clean(t, false) if t
end
