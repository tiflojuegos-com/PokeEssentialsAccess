# New Orleans City Gym (map 388): the leaders' event (119) carries the editor name Norman, but its battle is against Tate
# and Liza; it goes by the trainer name its own battle call gives them.
module PokeAccess
  module GcrLeaderNames
    LEADERS = { 388 => [119] }
    BATTLE_RE = /pbTrainerBattle\(\s*:\w+\s*,\s*"([^"]+)"/

    # The trainer name an event's pages battle under, or nil.
    def self.battle_name(ev)
      PokeAccess::Locator.event_command_lists(ev).each do |list|
        PokeAccess::Locator.script_calls(list).each do |s|
          m = s.match(BATTLE_RE)
          return m[1] if m
        end
      end
      nil
    end

    # A listed leader's name on this map, or nil.
    def self.name(ev)
      ids = LEADERS[$game_map.map_id]
      ids && ids.include?(ev.id) ? battle_name(ev) : nil
    end
  end
end

PokeAccess::Game.define("goldencrown") do
  event_name { |ev| PokeAccess::GcrLeaderNames.name(ev) }
end
