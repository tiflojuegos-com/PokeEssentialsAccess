# Wetlands Laboratory (map 222), with variable 96 at 26 and 27: thirty floor arrows (object_arrowtile) push the player a
# tile each, and eleven wall consoles, used facing up, flip a group of them (switches 1151 to 1154); every door of the
# lab sets the four back. With them all off the way is open, ending at the touch at (63, 29) (96 to 28).
module PokeAccess
  module RejuvFloorArrows
    STEP = { 1 => 2, 2 => 4, 3 => 6, 4 => 8 }

    # The way the live page of a floor arrow moves the player: the first step of its move route on the player.
    def self.way(ev)
      (PokeAccess.ivar(ev, :@list) || []).each do |c|
        next unless c.code == 209 && c.parameters[0] == -1
        c.parameters[1].list.each { |mc| return STEP[mc.code] if STEP[mc.code] }
      end
      nil
    end

    # An arrow's name by the way its live page pushes, or nil (its own name) while no page pushes.
    def self.label(ev, key)
      dir = way(ev)
      dir ? [key, { :dir => PokeAccess::Puzzles.face_name(dir) }] : nil
    end
  end

  module RejuvWetlandsLab
    MAP = 222
    ARROWS = [2, 3, 4, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 29, 31, 34, 40, 41, 42, 43, 44, 45, 74, 75,
              76, 87]
    FLIPPERS = [11, 32, 33, 35, 36, 37, 38, 39, 46, 47]
    CONSOLES = FLIPPERS.dup.push(48)
    # [box [x0, x1, y0, y1], the door the way takes from it, the assisted hint]
    AREAS = [[[50, 54, 53, 56], 53, :rjf_wl_room2_hint], [[38, 54, 72, 88], 58, :rjf_wl_hall_hint],
             [[8, 27, 55, 74], 54, :rjf_wl_low_hint], [[1, 23, 12, 47], 60, :rjf_wl_west_hint],
             [[39, 50, 51, 70], 100, :rjf_wl_pool_hint], [[42, 51, 38, 50], 100, :rjf_wl_heal_hint],
             [[62, 88, 27, 56], 85, :rjf_wl_east_hint]]

    # The story's step, variable 96.
    def self.step; $game_variables[96].to_i; end

    # While the lab is crossed: from Ren's escape to the room with Nastasia.
    def self.live?; step >= 26 && step < 28; end

    # Whether the player stands in a box of tiles.
    def self.in?(box)
      x = $game_player.x
      y = $game_player.y
      x >= box[0] && x <= box[1] && y >= box[2] && y <= box[3]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  lab = PokeAccess::RejuvWetlandsLab
  arrows = PokeAccess::RejuvFloorArrows
  mechanic(:state, lab::MAP, :part => :arrows) do
    auto
    name lab::ARROWS, lambda { |ev| arrows.label(ev, :rjf_wl_arrow) }
    name lab::CONSOLES, :rjf_wl_console
    on_use lab::FLIPPERS, lambda { |_ev| $game_player.direction == 8 ? :rjf_wl_arrows_flip : nil }
    lab::AREAS.each do |box, door, hint|
      phase lambda { PokeAccess::Puzzles.assist? && lab.live? && lab.in?(box) }, :quiet => true, :hint => hint
      spot :event => door, :label => :rjf_wl_way_out, :assist => true, :when => lambda { lab.live? && lab.in?(box) }
    end
    active { lab.live? }
    solved(nil, :quiet => true) { lab.step >= 28 }
  end
end
