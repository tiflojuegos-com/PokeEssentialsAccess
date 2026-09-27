# Infinite Fusion's own marks on a fusion: the summary's first page names its head and body where others write
# the dex number, both halves shiny read as such (a second star), and a shiny the game did not roll naturally is
# told apart (its star drawn black).
module PokeAccess
  module IFFusionMarks
    # The head and body names as the page writes them, or nil for a Pokemon that is not a fusion.
    def self.halves(pk)
      return nil unless (pk.isFusion? rescue false)
      head = (getPokemon(pk.species_data.get_head_species).name rescue nil)
      body = (getPokemon(pk.species_data.get_body_species).name rescue nil)
      return nil unless head && body
      "#{PokeAccess::I18n.t(:if_head, :n => head)} #{PokeAccess::I18n.t(:if_body, :n => body)}"
    end

    # Whether the star is drawn black (addShinyStarsToGraphicsArray): a shiny not rolled naturally, unless Hoenn
    # draws it blue as the radar's.
    def self.black_star?(pk)
      (pk.debugShiny? rescue false) && !(pk.radarShiny? rescue false)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::Party", :shiny_word) do |_mod, original, args|
    pk = args[0]
    both = (pk.headShiny? rescue false) && (pk.bodyShiny? rescue false)
    word = both ? PokeAccess::I18n.t(:if_shiny_both) : original.call
    PokeAccess::IFFusionMarks.black_star?(pk) ? PokeAccess::I18n.t(:if_shiny_unnatural, :shiny => word) : word
  end

  override("PokeAccess::SummaryGameData", :info_text) do |_mod, original, args|
    t = original.call
    h = PokeAccess::IFFusionMarks.halves(args[0])
    (t && h) ? "#{t.strip} #{h}" : t
  end
end
