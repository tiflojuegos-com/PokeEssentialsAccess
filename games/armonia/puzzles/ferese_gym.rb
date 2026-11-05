# Ferese's gym (maps 6, 7 and 4): three rooms, each with its own heating and a curtain before the way on that opens once the
# room is at a neutral temperature. The switches are buttons in Milotic statues that look all alike. Rooms 1 and 2 (maps 6
# and 7) take one press of the statue that holds the button. Room 3 (map 4) keeps its temperature in variable 29: events 4
# and 23 cool it by one each press, event 11 warms it by one once, and the curtain (event 1) opens the moment it reads 2.
# Event 22 thins the room's haze (fog nieblacalor, opacity 200, 150, 100 at -1, 0, 1) as it cools, which is all that event 4
# shows of its press: the temperature words say what a sighted player sees. Each statue is an event; the statue's tiles
# (base 500 under top 492) wear no other place in the three maps. The third room's curtain open ends it: its rule is said no
# more on arriving.
module PokeAccess
  module ArmoniaFerese
    CURTAINS = { 6 => 7, 7 => 6, 4 => 1 }
    ROLES = { 6 => { 11 => :room }, 7 => { 5 => :room }, 4 => { 4 => :cool, 23 => :cool, 11 => :warm } }
    LABELS = { :room => :arm_ferese_statue_room, :cool => :arm_ferese_statue_cool, :warm => :arm_ferese_statue_warm }
    TEMPERATURE = 29
    NEUTRAL = 2

    # Whether the curtain of the current map is open.
    def self.open?
      $game_self_switches[[$game_map.map_id, CURTAINS[$game_map.map_id], "A"]] ? true : false
    end

    # Whether a statue's button was pressed for good, which its own self switch records.
    def self.used?(ev)
      $game_self_switches[[$game_map.map_id, ev.id, "A"]] ? true : false
    end

    # Whether a statue is still worth listing: its room is not open and its button is not spent.
    def self.pending?(ev)
      !open? && !used?(ev)
    end

    # A statue's name: all alike; with the assist, what its button does.
    def self.label(ev)
      return :arm_ferese_statue_used if used?(ev)
      return :arm_ferese_statue unless PokeAccess::Puzzles.assist?
      LABELS[ROLES[$game_map.map_id][ev.id]] || :arm_ferese_statue_plain
    end

    # The hint of the third room: how many cooling presses it still takes.
    def self.hint
      [:arm_ferese_hint, { :n => [NEUTRAL - $game_variables[TEMPERATURE].to_i, 0].max }]
    end
  end
end

PokeAccess::Game.define("armonia") do
  ferese = PokeAccess::ArmoniaFerese
  statue = lambda { |ev| ferese.label(ev) }
  pending = lambda { |ev| ferese.pending?(ev) }
  words = { -1 => :arm_ferese_t_m1, 0 => :arm_ferese_t_0, 1 => :arm_ferese_t_1, 2 => :arm_ferese_t_2 }

  mechanic(:state, 6) do
    auto
    name [10, 11], statue, :when => pending
    obstacle(/aacortina/, :label => :arm_ferese_curtain)
    watch :self => [7, "A"], :label => :arm_ferese_curtain, :on => :arm_ferese_open, :off => :arm_ferese_closed
    active { !ferese.open? }
    hint :arm_ferese_hint_room
    arrival_hint :arm_ferese_rule, :once => true
  end

  mechanic(:state, 7) do
    auto
    name 5, statue, :when => pending
    obstacle(/aacortina/, :label => :arm_ferese_curtain)
    watch :self => [6, "A"], :label => :arm_ferese_curtain, :on => :arm_ferese_open, :off => :arm_ferese_closed
    active { !ferese.open? }
    hint :arm_ferese_hint_room
    arrival_hint :arm_ferese_rule, :once => true
  end

  mechanic(:state, 4) do
    auto
    name [4, 11, 23, 24], statue, :when => pending
    obstacle(/aacortina/, :label => :arm_ferese_curtain)
    phase lambda { !ferese.open? }, :title => :arm_ferese_title, :hint => lambda { ferese.hint },
          :values => [{ :var => ferese::TEMPERATURE, :label => :arm_ferese_temp, :words => words }]
    arrival_hint :arm_ferese_rule, :once => true
    solved { ferese.open? }
  end
end
