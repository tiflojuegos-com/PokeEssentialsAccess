# Blake's apartment in Ametrine City (map 457): with switch 507 on, the way out is a secret passage. A key joined from
# the trash can (event 40) and drawer (39) pieces opens the cabinet (38); the computer tower (24), facing down, takes
# the cable then the disc (from console 37), and the monitor (25), facing down, asks for 5083164 and sets 508.
module PokeAccess
  module RebornBlake
    # Each piece: the switch set as it is found, the one set as it is used up, and its name.
    PIECES = [[512, 509, :rbb_blake_disc], [514, 513, :rbb_blake_head], [515, 513, :rbb_blake_handle],
              [513, 511, :rbb_blake_key], [511, 510, :rbb_blake_cable]]

    def self.s(id)
      $game_switches[id] ? true : false
    end

    # What the player carries now, as the game's messages told it.
    def self.held_line
      got = PIECES.select { |found, used, _k| s(found) && !s(used) }.map { |_f, _u, k| PokeAccess::I18n.t(k) }
      got.empty? ? nil : [:rbb_blake_held, { :list => got.join(", ") }]
    end

    # The next thing to do, with the puzzle assist.
    def self.hint
      return :rbb_blake_h_console unless s(512)
      return :rbb_blake_h_key unless s(513)
      return :rbb_blake_h_cabinet unless s(511)
      return :rbb_blake_h_plug unless s(510)
      return :rbb_blake_h_disc unless s(509)
      :rbb_blake_h_monitor
    end
  end
end

PokeAccess::Game.define("reborn") do
  blake = PokeAccess::RebornBlake
  mechanic(:state, 457, :part => :secret_passage) do
    auto
    name 37, :rbb_blake_console
    name 40, :rbb_blake_trash
    name 39, :rbb_blake_drawer
    name 38, :rbb_blake_cabinet
    name 24, :rbb_blake_tower
    name 25, :rbb_blake_monitor
    info { blake.held_line }
    hint lambda { blake.hint }
    active { $game_switches[507] }
    solved(nil, :quiet => true) { $game_switches[508] }
  end
end
