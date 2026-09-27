module PokeAccess
  # The banner Infinite Fusion shows when the Poke Radar is used (PokeRadar_UI, built by displayPokeradarBanner): the
  # route's species by icon, an unseen one as a black silhouette, the radar's rare ones ringed (a silhouette too
  # while unseen); then the light, green when a rare one can appear, red when not.
  module IFRadarBanner
    # A species list as the banner holds it, or [] for anything else.
    def self.list(v)
      v.is_a?(Array) ? v : []
    end

    # Whether the Pokedex has seen a species, which the banner draws as its icon instead of a silhouette.
    def self.seen?(species)
      $Trainer.seen?(species) ? true : false
    rescue StandardError
      false
    end

    # The names of the species the banner shows by their icons.
    def self.names(species)
      species.map { |sp| PokeAccess::Data.species_name(sp) }.compact.map { |n| PokeAccess.clean(n.to_s) }.join(", ")
    end

    # The banner's line: the seen species by name, how many are silhouettes, and the rare ones alike; nil when empty.
    def self.line(ui)
      rare_seen, rare_unseen = list(PokeAccess.ivar(ui, :@rare_pokemon)).partition { |sp| seen?(sp) }
      seen = list(PokeAccess.ivar(ui, :@seen_pokemon))
      unseen = list(PokeAccess.ivar(ui, :@unseen_pokemon))
      parts = []
      parts.push(PokeAccess::I18n.t(:if_radar_seen, :list => names(seen))) unless seen.empty?
      parts.push(PokeAccess::I18n.t(:if_radar_unseen, :n => unseen.length)) unless unseen.empty?
      parts.push(PokeAccess::I18n.t(:if_radar_rare, :list => names(rare_seen))) unless rare_seen.empty?
      parts.push(PokeAccess::I18n.t(:if_radar_rare_unseen, :n => rare_unseen.length)) unless rare_unseen.empty?
      parts.empty? ? nil : PokeAccess.sentences(parts)
    rescue StandardError
      nil
    end

    # Says a banner the call has just built; a call that finds one already up (the chain goes on) builds none.
    def self.opened(before)
      ui = ($PokemonTemp.pokeradar_ui rescue nil)
      return if ui.nil? || ui.equal?(before)
      t = line(ui)
      PokeAccess.speak(t, true) if t
    end

    # Says the light the radar flashes: whether a rare Pokemon can appear here.
    def self.light(rare_allowed)
      PokeAccess.speak(PokeAccess::I18n.t(rare_allowed ? :if_radar_rare_on : :if_radar_rare_off), false)
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  kernel("displayPokeradarBanner", :around) do |_args, nxt|
    before = ($PokemonTemp.pokeradar_ui rescue nil)
    r = nxt.call
    PokeAccess::IFRadarBanner.opened(before)
    r
  end
  kernel("playPokeradarLightAnimation", :before) { |args, _r| PokeAccess::IFRadarBanner.light(args[0]) }
end
