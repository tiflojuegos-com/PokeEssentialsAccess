# Villa Nos (map 51): three doors and four edges send the player back to the south, V97 keeps the order they were taken in, and
# only the whole order opens the north edge, to map 89. Without the assist the sign in the middle (event 8) is the only gauge.
module PokeAccess
  module EdasVillage
    MAP = 51
    ORDER = 97
    SOUTH = [13, 16, 27, 33]
    NAMES = [[3, :edas_nos_door_church], [5, :edas_nos_door_lab], [13, :edas_nos_door_warehouse],
             [[12, 16], :edas_nos_exit_north], [[4, 10], :edas_nos_exit_south], [[6, 17], :edas_nos_exit_west],
             [[7, 15], :edas_nos_exit_east]]
    WAYS = [[5, :edas_nos_hint_lab], [10, :edas_nos_hint_south], [13, :edas_nos_hint_warehouse],
            [6, :edas_nos_hint_west], [3, :edas_nos_hint_church], [12, :edas_nos_hint_north]]

    # How many right steps the order stands at, from 0 to the last of the ways.
    def self.step
      [[$game_variables[ORDER].to_i - 1, 0].max, WAYS.length - 1].min
    end
  end
end

PokeAccess::Game.define("edas") do
  village = PokeAccess::EdasVillage
  mechanic(:state, village::MAP) do
    village::NAMES.each { |ids, label| name ids, label, :when => false }
    count :edas_nos_steps, :var => village::ORDER, :from => 1, :of => village::WAYS.length, :hide_zero => true,
          :reset => :edas_nos_reset, :assist => true
    sent_back :edas_nos_back, :to => village::SOUTH
    arrival_hint :edas_nos_rule
    village::WAYS.each_with_index do |(event, hint), i|
      phase lambda { village.step == i }, :hint => hint, :hidden => right_way(event)
    end
  end
end
