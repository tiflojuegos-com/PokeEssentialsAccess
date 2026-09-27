# Hoenn's visible wild Pokemon (053 OverworldPokemon): events copied from the "OW_normal" template or named
# "OverworldPokemon", drawn with a follower sprite of the species they show (a Ditto or Zorua disguised as another of
# the route's), and the "Legendary(SPECIES)" events of the roaming legendaries.
module PokeAccess
  module IF2Overworld
    # The follower sprite the event draws: Followers/[Fusions/][Shiny/]<SPECIES>, with a _fly, _notice or _swim
    # pose suffix; a fusion's is its body's silhouette, filled black, or only outlined when shiny.
    SPRITE = /\AFollowers\/(Fusions\/)?(Shiny\/)?(.+?)(?:_(?:fly|notice|swim))?\z/
    LEGENDARY = /\ALegendary\(([^)]+)\)/

    # One of these events as its sprite shows it: "Wild <species>" for the species drawn (a disguise's included), a
    # fusion as its body's silhouette, and the shiny mark its sprite folder shows; nil for any other event.
    def self.wild_name(ev)
      return legendary(ev) unless defined?(::OverworldPokemonEvent) && ev.is_a?(::OverworldPokemonEvent)
      m = SPRITE.match(ev.character_name.to_s)
      return undrawn(ev) unless m
      name = species_name(m[3])
      w = PokeAccess::I18n.t(m[1] ? :if2_ow_fusion : :loc_wild, :name => name)
      m[2] ? "#{w}, #{PokeAccess::I18n.t(:pk_shiny)}" : w
    rescue StandardError
      nil
    end

    # An event whose sprite is not a follower's: its own species, unless it is disguised.
    def self.undrawn(ev)
      return nil if PokeAccess.ivar(ev, :@disguised) || ev.species.nil?
      PokeAccess::I18n.t(:loc_wild, :name => species_name(ev.species))
    end

    # A roaming legendary, "Wild <species>" from its "Legendary(SPECIES)" event name, read as the game reads it.
    def self.legendary(ev)
      m = LEGENDARY.match(ev.name.to_s)
      m ? PokeAccess::I18n.t(:loc_wild, :name => species_name(m[1])) : nil
    end

    def self.species_name(sym)
      (PokeAccess::Data.species_name(sym.to_s.to_sym) rescue nil) || sym.to_s
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  override("PokeAccess::Locator", :wild_pokemon_name) do |_mod, original, args|
    original.call || PokeAccess::IF2Overworld.wild_name(args[0])
  end
end
