# The team photo camera of the "Fotos del equipo" plugin (PartyPicture#main pans it with pbScrollMap): each step
# says the offset from the start, measured on the map's display, as a map edge can stop it while the plugin counts.
module PokeAccess
  module TeamPhoto
    # Takes the camera's starting position, as main begins.
    def self.start
      @origin = display
      @last = @origin
    end

    # Stops listening: a later pbScrollMap belongs to a cutscene, not to the camera.
    def self.stop; @origin = nil; end

    # The map's display position, [x, y] in display units.
    def self.display
      [($game_map.display_x rescue 0).to_f, ($game_map.display_y rescue 0).to_f]
    end

    # Display units per tile: 32 pixels times 4 subpixels in every era that ships the plugin.
    def self.tile
      (Game_Map::REAL_RES_X rescue 128).to_f
    end

    # Speaks where the camera stands after a step in direction dir (8, 2, 6 or 4). A step that travelled
    # less than three quarters of a tile ran into the map's edge, and says so.
    def self.step(dir)
      return if @origin.nil? || ![2, 4, 6, 8].include?(dir)
      now = display
      axis = (dir == 4 || dir == 6) ? 0 : 1
      edge = (now[axis] - @last[axis]).abs < tile * 0.75
      @last = now
      text = offset_text(tiles(now[0] - @origin[0]), tiles(@origin[1] - now[1]))
      text = "#{text}, #{PokeAccess::I18n.t(:photo_cam_edge)}" if edge
      PokeAccess.speak(text, true)
    end

    # Display units to tiles, to the nearest half (the camera starts off the tile grid, so it can stop between two).
    def self.tiles(units)
      v = (units.abs / tile * 2 + 0.5).floor / 2.0
      units < 0 ? -v : v
    end

    # A tile count as the language writes it: a whole number bare, a half with the language's decimal sign.
    def self.num(v)
      v == v.floor ? v.to_i.to_s : PokeAccess::Pokedex.fmt_float(v)
    end

    # The offset from the start, vertical part first ("2 up, 1 right"), or the centre.
    def self.offset_text(x, y)
      parts = []
      parts.push(PokeAccess::I18n.t(y > 0 ? :photo_cam_up : :photo_cam_down, :n => num(y.abs))) if y != 0
      parts.push(PokeAccess::I18n.t(x > 0 ? :photo_cam_right : :photo_cam_left, :n => num(x.abs))) if x != 0
      parts.empty? ? PokeAccess::I18n.t(:photo_cam_center) : parts.join(", ")
    end
  end
end

PokeAccess::Hooks.around_hook("PartyPicture", :main, :optional => true) do |_s, nxt, _a|
  PokeAccess::TeamPhoto.start
  begin
    nxt.call
  ensure
    PokeAccess::TeamPhoto.stop
  end
end

PokeAccess::Hooks.wrap_kernel("pbScrollMap", "team_photo_step", :after) do |args, _r|
  PokeAccess::TeamPhoto.step(args[0])
end
