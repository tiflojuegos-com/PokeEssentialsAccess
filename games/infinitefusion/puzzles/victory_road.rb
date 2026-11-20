# Victory Road (maps 304, 306, 307): a boulder pushed onto a marked floor tile sets a switch (308 on map 304; 309 and 310
# on 306; 311 and 312 on 307) that opens a barrier. The boulder of map 307 that sets 311 falls to map 306 and shows the
# second boulder there, which sets 310.
PokeAccess::Game.define("infinitefusion") do
  plate = lambda do |n, switch|
    { :switch => switch, :label => [:ifk_vr_plate, { :n => n }], :on => :ifk_vr_pressed, :off => :ifk_vr_free }
  end

  mechanic(:state, 304) do
    watch plate.call(1, 308)
    spot :event => 3, :label => :ifk_vr_target
    obstacle({ :events => 5 }, :label => :ifk_vr_barrier)
    hint :ifk_vr_hint_304
  end

  mechanic(:state, 306) do
    watch plate.call(2, 309)
    watch plate.call(3, 310)
    spot :event => 9, :label => :ifk_vr_target
    spot :event => 11, :label => :ifk_vr_target
    obstacle({ :events => [7, 8] }, :label => :ifk_vr_barrier)
    hint :ifk_vr_hint_306
  end

  mechanic(:state, 307) do
    watch plate.call(4, 311)
    watch plate.call(5, 312)
    spot :event => 8, :label => :ifk_vr_target
    obstacle({ :events => 9 }, :label => :ifk_vr_barrier)
    hint :ifk_vr_hint_307
  end
end
