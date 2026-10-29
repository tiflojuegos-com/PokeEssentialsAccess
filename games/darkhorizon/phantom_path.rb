module PokeAccess
  # Dark Horizon's Phantom Path (PhantomPath, kept in a game variable by the map's events): a path of tiles lights up one
  # by one and fades, and the player walks it from memory, a step off it dropping them back at the start; on a later
  # visit it stays lit. The lit path is said as the presses that walk it from where the player stands, and on its map
  # the info key says the presses left.
  module DHPhantomPath
    # The game variable the map's events keep the puzzle in (PhantomPath::CURRENT_PHANTOM_PATH).
    VARIABLE = 90

    # The presses that walk tiles in order from (x, y), as direction codes: a tile out of line with the one before
    # costs the presses across, then along.
    def self.presses(x, y, tiles)
      out = []
      tiles.each do |tx, ty|
        dx = tx - x
        dy = ty - y
        dx.abs.times { out.push(dx > 0 ? 6 : 4) }
        dy.abs.times { out.push(dy > 0 ? 2 : 8) }
        x = tx
        y = ty
      end
      out
    end

    # The presses as legs ("3 up, 2 right"), or nil without any.
    def self.route_text(x, y, tiles)
      legs = PokeAccess::Routes::Text.legs(presses(x, y, tiles))
      return nil if legs.empty?
      legs.map { |l| PokeAccess::Routes::Text.leg(l[0], l[1]) }.join(", ")
    end

    # The tiles left from where the player stands: those past the last path tile under them, else the whole path.
    def self.left(path)
      tiles = path.getPathTiles
      at = tiles.rindex([$game_player.x, $game_player.y])
      at ? tiles[(at + 1)..-1] : tiles
    end

    # As the path lights up: the presses that walk it from where the player stands, queued.
    def self.shown(path)
      text = route_text($game_player.x, $game_player.y, left(path))
      PokeAccess.speak(PokeAccess::I18n.t(:dh_phantom_shown, :route => text), false) if text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The puzzle of the map the player stands on, or nil: the one its events keep, on the map PhantomPath names.
    def self.current
      path = $game_variables ? $game_variables[VARIABLE] : nil
      return nil unless path.respond_to?(:getPathTiles)
      maps = PokeAccess.const_at("PhantomPath::PHANTOM_PATHS") || []
      maps.any? { |m| m[0] == $game_map.map_id } ? path : nil
    end

    # The info key on the puzzle's map: the presses left to the path's end, or that the player stands on it.
    def self.info
      path = current
      return nil unless path
      text = route_text($game_player.x, $game_player.y, left(path))
      text ? PokeAccess::I18n.t(:dh_phantom_left, :route => text) : PokeAccess::I18n.t(:dh_phantom_end)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  # pbShowPathRoute lights the path tile by tile, then hides it; pbShowPathRouteDone keeps it lit on a later visit.
  [:pbShowPathRoute, :pbShowPathRouteDone].each do |meth|
    before("PhantomPath", meth) { |path, _a| PokeAccess::DHPhantomPath.shown(path) }
  end
end

PokeAccess::Info.map_owner(:dh_phantom_path) { PokeAccess::DHPhantomPath.info }
