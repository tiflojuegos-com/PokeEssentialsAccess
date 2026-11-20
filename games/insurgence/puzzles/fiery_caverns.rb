# Fiery Caverns (map 281): the boulder (event 1, first at 42,10), pushed along the north cave to 40,24 and then right from
# 39,24, jumps over 41,24 onto 42,24 and turns switch 148 on. That draws the lava cascade events as floor (25 of the 35 are a floor
# tile) and joins the entrance side to the east side through the diagonal stairs at 33 to 34, 28 to 30 (events 43, 60 and
# 61); until then the exit at 68,26 cannot be reached from the entrance.
PokeAccess::Game.define("insurgence") do
  open_way = lambda { $game_switches[148] }
  mechanic(:state, 281) do
    auto
    spot :at => [40, 24], :label => :ins_u2_fiery_plate, :assist => true, :when => lambda { !open_way.call }
    active { !open_way.call }
    solved(nil, :quiet => true) { open_way.call }
    hint :ins_u2_fiery_hint
  end
end
