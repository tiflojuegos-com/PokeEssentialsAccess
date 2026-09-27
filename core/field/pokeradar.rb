module PokeAccess
  # The Poke Radar's shaking grass (pbPokeRadarHighlightGrass, stock in every era): after each search, the patches it
  # shook, nearest ring first, each by how it shakes and where it lies from the player.
  module PokeRadar
    # The rarity a patch carries (0 normal, 1 vigorous, 2 shiny) => the key of its spoken kind.
    KINDS = [:radar_kind_normal, :radar_kind_vigorous, :radar_kind_shiny]

    # The radar's state, [species, level, chain, patches]: $game_temp.poke_radar_data from v20, $PokemonTemp before.
    def self.data
      d = ($game_temp.poke_radar_data rescue nil)
      d = ($PokemonTemp.pokeradar rescue nil) unless d.is_a?(Array)
      d.is_a?(Array) ? d : nil
    end

    # One patch as spoken, or nil for an entry without the stock [x, y, ring, rarity] shape.
    def self.patch(g, px, py)
      return nil unless g.is_a?(Array) && g[0].is_a?(Integer) && g[1].is_a?(Integer) && g[2].is_a?(Integer)
      kind = PokeAccess::I18n.t(KINDS[g[3].to_i] || KINDS[0])
      PokeAccess::I18n.t(:radar_patch, :kind => kind, :where => PokeAccess::Locator.dir_phrase(g[0] - px, g[1] - py))
    end

    # The patches the last search shook as one line, or nil when it shook none.
    def self.grass_line
      d = data
      return nil unless d && d[3].is_a?(Array) && $game_player
      rows = d[3].map { |g| patch(g, $game_player.x, $game_player.y) }.compact
      rows.empty? ? nil : rows.join("; ")
    rescue StandardError
      nil
    end

    # Speaks the patches, queued after whatever the search's use already said.
    def self.say_grass
      t = grass_line
      PokeAccess.speak(t, false) if t
    end
  end
end

PokeAccess::Hooks.wrap_kernel("pbPokeRadarHighlightGrass", "hook_pokeradar_grass", :after) do |_args, _r|
  PokeAccess::PokeRadar.say_grass
end
