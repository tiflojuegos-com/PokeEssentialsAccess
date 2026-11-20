# Eridanus Tunnels (maps 442, 454, 456, 457 and 458) and their Secret Chamber (map 481), the quest "A Witch's Ramblings"
# (V182). Two statuettes a floor ask a riddle as a menu in the message (V192); the one option the page compares with gives a
# disc and adds to V182, any other wakes the guardian. At V182 11 the chamber opens: Casper (event 18) sends the player into
# four rooms in turn, each with a 15-second timer (events 19, 23, 24 and 27) that ends in a count about what the room held,
# one of four drawn at random, whose right option jumps to the label that adds to V182. His anchor (event 30) answers last.
module PokeAccess
  module SS2Eridanus
    FLOORS = [442, 454, 456, 457, 458]
    ROOMS = { 19 => :ss2_pz_casper_room1, 23 => :ss2_pz_casper_room2, 24 => :ss2_pz_casper_room3, 27 => :ss2_pz_casper_room4 }

    # True while a room's timer runs: Casper has set its self switch A and the room is not passed yet.
    def self.in_room?(id)
      s = $game_self_switches
      s[[481, id, "A"]] && !s[[481, id, "B"]] ? true : false
    end

    # The seconds the game's timer has left, or nil when it is not running.
    def self.seconds
      sys = $game_system
      return nil unless sys && sys.timer_working
      sys.timer / Graphics.frame_rate
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, PokeAccess::SS2Eridanus::FLOORS) do
    auto
    name(/Statuette Riddle/, :ss2_pz_statuette,
         :when => lambda { |ev| $game_variables[182] >= 1 && !$game_self_switches[[$game_map.map_id, ev.id, "A"]] })
    right_choice(/Statuette Riddle/, :takes => { :var => 182 })
  end

  mechanic(:state, 481) do
    auto
    name 30, :ss2_pz_casper_anchor, :when => lambda { |_ev| $game_variables[182] == 17 }
    PokeAccess::SS2Eridanus::ROOMS.each do |id, room|
      phase lambda { PokeAccess::SS2Eridanus.in_room?(id) }, :title => room
    end
    right_choice(PokeAccess::SS2Eridanus::ROOMS.keys, :takes => { :var => 182 })
    active { PokeAccess::SS2Eridanus::ROOMS.keys.any? { |id| PokeAccess::SS2Eridanus.in_room?(id) } }
    info do
      s = PokeAccess::SS2Eridanus.seconds
      s ? PokeAccess::I18n.t(:ss2_pz_casper_time, :n => s) : nil
    end
  end
end
