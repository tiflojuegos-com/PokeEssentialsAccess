# Illusion Grove (map 97): events with no graphic that call transfer_subtle(x, y), a silent jump inside the map that does
# nothing while the Zoroark hat is worn (some only when the player faces a given way, two on the action button); seven
# Zorua, disguised as other Pokémon, that count up variable 1031 as the player nears them in order; and the weather picking
# which legendary the passages at (10, 29) and (11, 29) lead to. Nothing shows the jumps, so the free camera names them
# with the assist alone.
module PokeAccess
  module HoennGrove
    PORTALS = [1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 30, 33, 52, 53, 54, 59]

    # True while the Zoroark hat is worn, which stops the jumps (transfer_subtle).
    def self.hat?
      (isWearingHat(HAT_ZOROARK) ? true : false) rescue false
    end

    # The free camera's line on a jump of the grove that works now, or nil.
    def self.camera_line(x, y)
      return nil if hat?
      PokeAccess::World::Events.at(x, y).any? { |rec| PORTALS.include?(rec.ev.id) } ? PokeAccess::I18n.t(:cam_warp) : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  grove = PokeAccess::HoennGrove
  zorua = [32, 36, 38, 34, 37, 61, 41]

  mechanic(:state, 97) do
    auto
    avoid grove::PORTALS - [21, 22]
    sent_back :if_ho_grove_moved, :events => grove::PORTALS
    name zorua, :if_ho_zorua, :assist => true
    count :if_ho_zorua_count, :value => lambda { [$game_variables[1031].to_i, 7].min }, :of => 7, :assist => true
    on_use 56, :if_ho_legend_west, :assist => true
    on_use 57, :if_ho_legend_east, :assist => true
    hint :if_ho_grove_hint
    active { PokeAccess::Puzzles.assist? }
  end
  camera_tile(:maps => [97], :assist => true) { |x, y| grove.camera_line(x, y) }
end
