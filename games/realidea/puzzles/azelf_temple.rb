# The Temple of Azelf (map 186): fifteen rows of spikes rise and fall by themselves, each with its switch (195 to 209);
# standing within a row's three by three tiles while its switch is on halves the party's HP (the game's pinchos and
# dolor). The spikes at (15, 10 to 12) stay up until the lever at (7, 16) turns switch 210 on. Beating Azelf sets 316.
module PokeAccess
  module RealideaAzelf
    MAP = 186
    BEATEN = 316
    LEVER = 210
    # Each row by its switch: its middle column, its top and bottom tiles, and its spike events.
    ROWS = {
      195 => [7, 54, 56, [1, 2, 3]], 196 => [2, 50, 52, [6, 7, 8]], 197 => [2, 47, 49, [9, 10, 11]],
      198 => [8, 43, 45, [12, 13, 14]], 199 => [14, 46, 48, [15, 16, 17]], 200 => [17, 46, 48, [18, 19, 20]],
      201 => [24, 42, 44, [21, 22, 23]], 202 => [24, 39, 41, [24, 25, 26]], 203 => [24, 36, 38, [27, 28, 29]],
      204 => [14, 34, 36, [30, 31, 35]], 205 => [14, 31, 33, [32, 33, 34]], 206 => [2, 25, 27, [36, 37, 38]],
      207 => [29, 21, 23, [39, 40, 41]], 208 => [29, 18, 20, [42, 43, 44]], 209 => [15, 18, 20, [45, 46, 47]]
    }
    GATE = [15, 10, 12, [48, 49, 50]]
    SWITCH_OF = {}
    ROWS.each { |sw, r| r[3].each { |id| SWITCH_OF[id] = sw } }
    # How far from a row the info key still speaks of it.
    NEAR = 2

    # True while the spikes of a row hurt: its switch on, or for the gate, the lever not yet pulled.
    def self.up?(sw)
      sw == LEVER ? !$game_switches[LEVER] : ($game_switches[sw] ? true : false)
    end

    # The name of a spike, up or down as its row stands now.
    def self.spike(ev)
      sw = SWITCH_OF[ev.id] || LEVER
      up?(sw) ? :rea_azelf_spikes_up : :rea_azelf_spikes_down
    end

    # The switch of the row nearest the player within NEAR tiles of its three by three, or nil.
    def self.near_row
      px = $game_player.x
      py = $game_player.y
      best = nil
      ROWS.dup.merge!(LEVER => GATE).each do |sw, r|
        dx = [(px - r[0]).abs - 1, 0].max
        dy = py < r[1] ? r[1] - py : (py > r[2] ? py - r[2] : 0)
        d = [dx, dy].max
        best = [d, sw] if d <= NEAR && (best.nil? || d < best[0])
      end
      best ? best[1] : nil
    end

    # The info key's line: how the nearest row stands, or nil far from all.
    def self.info
      sw = near_row
      return nil unless sw
      up?(sw) ? :rea_azelf_near_up : :rea_azelf_near_down
    end
  end
end

PokeAccess::Game.define("realidea") do
  temple = PokeAccess::RealideaAzelf
  spikes = temple::SWITCH_OF.keys.concat(temple::GATE[3])
  mechanic(:state, temple::MAP) do
    auto
    name spikes, lambda { |ev| temple.spike(ev) }, :grouped => true
    info { temple.info }
    arrival_hint :rea_azelf_rule
    solved { $game_switches[temple::BEATEN] }
  end
end
