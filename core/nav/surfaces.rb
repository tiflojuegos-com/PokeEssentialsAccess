module PokeAccess
  # What the player stands on and faces, said as it changes, each map frame with control free (Frame's :surfaces step):
  # the terrain underfoot and water ahead (surface_cues), and the hidden area on a Lens-of-Truth tile.
  module Surfaces
    # Drops what was said on the last map.
    def self.reset_map_state
      @surf_here = nil
      @surf_front = nil
      @surf_pos = nil
      @lens_pos = nil
    end
    reset_map_state

    # One map frame: the surface notices, then the lens tile.
    def self.tick
      return unless $game_map && $game_player
      return unless PokeAccess::Control.free?
      surfaces
      lens_tile
    end

    # The terrain under the player when it changes, and water right ahead (once until it changes), surfable or not as
    # the game would let the player start Surf there, resolved through World::Terrain so they read the same in every era.
    def self.surfaces
      return unless PokeAccess::Config.surface_cues
      pos = [$game_player.x, $game_player.y, $game_player.direction]
      return if pos == @surf_pos
      @surf_pos = pos
      here = here_label
      if here != @surf_here
        @surf_here = here
        PokeAccess.speak(PokeAccess::I18n.t(here), false) if here
      end
      fx, fy = PokeAccess::Control.front_tile
      ahead = water_ahead_kind(fx, fy)
      surfing = ($PokemonGlobal && $PokemonGlobal.surfing rescue false)
      if ahead && !surfing && @surf_front != [fx, fy]
        @surf_front = [fx, fy]
        PokeAccess.speak(PokeAccess::I18n.t(ahead == :surf ? :surf_ahead : :water_ahead), false)
      end
      @surf_front = nil if !ahead || surfing
    end

    # The surface label of the player's tile; a bridge they walk or surf under (the engine's bridge height at 0, where it
    # ignores the bridge) reads as under the bridge.
    def self.here_label
      here = PokeAccess::World::Terrain.label($game_player.x, $game_player.y)
      return here unless here == :surf_bridge && PokeAccess::World::Engine.bridge_height == 0
      :surf_under_bridge
    end

    # The water freely surfed (not falling) on the tile ahead, with the player's tile open toward it: :surf where the
    # game would let the player start Surf, :water where it will not now (a bike-only map, the party, the company).
    def self.water_ahead_kind(fx, fy)
      return nil unless water_ahead?(fx, fy)
      return nil unless ($game_map.passable?($game_player.x, $game_player.y, $game_player.direction) rescue false)
      return :water if PokeAccess::MapMeta.always_bicycle?(($game_map.map_id rescue 0))
      return :water if PokeAccess::FieldMoves.can?(:SURF) == false || !PokeAccess::Pathfinder.surf_with_company?
      :surf
    end

    # True when (fx, fy) is water surfed freely (not falling): on this map, or past its edge on the connected map, whose
    # terrain the game reads to let the player surf across the seam.
    def self.water_ahead?(fx, fy)
      return PokeAccess::Routes::Moves.surf_water?(fx, fy) if ($game_map.valid?(fx, fy) rescue true)
      far = PokeAccess::Locator.across(fx, fy)
      return false unless far
      t = PokeAccess::World::Terrain
      bits = t.tag_bits(PokeAccess::MapMeta.terrain_on(far[0], far[1], far[2]))
      (bits & t::SURF) != 0 && (bits & t::FALLING) == 0
    end

    # A generic "hidden area" line on arriving at a tile that holds a Lens-of-Truth (#EOT) event; generic because each
    # game names the lens differently.
    def self.lens_tile
      pos = [$game_player.x, $game_player.y]
      return if pos == @lens_pos
      @lens_pos = pos
      ev = PokeAccess::Control.event_at(pos[0], pos[1])
      return unless ev && (PokeAccess::Locator.lens_tile?(ev) rescue false)
      PokeAccess.speak(PokeAccess::I18n.t(:lens_tile_here), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# Drops what was said on the last map on a map change or a load (Caches.reset_all).
PokeAccess::Caches.register(:surfaces) { PokeAccess::Surfaces.reset_map_state }
