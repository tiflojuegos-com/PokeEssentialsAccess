# Bastión-Cocina (map 115): each of three rooms, opened in turn as switches 198, 199 and 201 turn on, cooks a dish of two
# berries from its box (var 96 counts them) by a recipe read at its pot, drawn by var 98. The chart that tells the berries
# apart is a picture (picture_cues.rb) shown from wall tiles with no graphic, name or text, so nothing else lists it.
PokeAccess::Game.define("pokemon_z") do
  rooms = [[lambda { !$game_switches[198] }, [5, 4], 28, 31,
            [[:CHERIBERRY, :SITRUSBERRY], [:ORANBERRY, :CHESTOBERRY], [:ORANBERRY, :SITRUSBERRY]]],
           [lambda { $game_switches[198] && !$game_switches[199] }, [49, 5], 33, 36,
            [[:CHERIBERRY, :CHESTOBERRY], [:ORANBERRY, :SITRUSBERRY], [:CHERIBERRY, :SITRUSBERRY]]],
           [lambda { $game_switches[199] && !$game_switches[201] }, [15, 47], 39, 40,
            [[:ORANBERRY, :LUMBERRY], [:SITRUSBERRY, :LUMBERRY], [:CHERIBERRY, :LUMBERRY]]]]
  mechanic(:state, 115) do
    rooms.each_with_index do |(live, chart, box, pot, answers), i|
      phase live, :title => [:z_kitchen_dish, { :n => i + 1 }], :quiet => true,
            :progress => { :var => 96, :of => 2, :label => :z_kitchen_berries, :hide_zero => true },
            :spots => [{ :at => chart, :label => :z_kitchen_chart }, { :event => box, :label => :z_kitchen_box },
                       { :event => pot, :label => :z_kitchen_pot }],
            :hint => lambda {
              a, b = answers[$game_variables[98]].map { |berry| PokeAccess::Data.item_id(berry)[1] }
              PokeAccess::I18n.t(:z_kitchen_hint, :a => a, :b => b)
            }
    end
  end
end
