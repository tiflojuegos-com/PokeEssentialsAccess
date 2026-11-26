# Slums Playground (map 321): jump tiles like 1F's stand while switch 410 is off; down the side stairs (410 on) their
# pages are blank, so the routes take both floors (World::Floors). North of it, the Scraggy quest (variable 156): each
# side room's Pangoro lets its Scraggy press a wall device (events 60, 67); at 4 the last one opens.
module PokeAccess
  module RebornPlayground
    MAP = 321
    LOWER = 410
    QUEST = 156
    DEVICES = { 60 => 411, 67 => 412 }
    SUN_STONE = 32

    # True once a wall device was pressed (its self switch A).
    def self.pressed?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # A wall device's name, by whether it was pressed.
    def self.device(ev)
      pressed?(ev.id) ? :rbh_pg_device_pressed : :rbh_pg_device
    end

    # With the assist, the Sun Stone's ball seen from above: it is picked up from below.
    def self.sun_stone(_ev)
      $game_switches[LOWER] || $game_self_switches[[MAP, SUN_STONE, "A"]] ? nil : :rbh_pg_sun_stone
    end

    # With the assist, the quest's next step: a side room's Pangoro, then its device, and with both the last Pangoro.
    def self.hint
      v = $game_variables[QUEST].to_i
      return nil if v < 2 || v >= 5
      return :rbh_pg_hint_boss if v >= 4
      id = DEVICES.keys.sort.find { |d| !pressed?(d) }
      return nil unless id
      side = id == 60 ? :left : :right
      return :"rbh_pg_hint_pangoro_#{side}" unless $game_switches[DEVICES[id]]
      :"rbh_pg_hint_device_#{side}"
    end
  end
end

PokeAccess::Game.define("reborn") do
  pg = PokeAccess::RebornPlayground
  mechanic(:state, pg::MAP) do
    auto
    arrival_hint :rbh_pg_rule
    name pg::DEVICES.keys, lambda { |ev| pg.device(ev) }
    name pg::SUN_STONE, lambda { |ev| pg.sun_stone(ev) }, :assist => true
    hint lambda { pg.hint }
    active { PokeAccess::Puzzles.assist? && !pg.hint.nil? }
  end
end
