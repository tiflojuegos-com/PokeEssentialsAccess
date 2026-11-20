# Kopiranga's trainer school, ground floor (map 300): the teacher at (41, 12), event 25, asks for every item laid out in
# the room to be read. Six exhibits (events 2 to 6 and 8) each add one to variable 58 the first time they are read, and
# at 6 the teacher gives an Air Balloon (the teacher's self switch A). Read and unread exhibits look alike, so the ones left and
# the teacher are listed with the assist alone.
PokeAccess::Game.define("herolegacy") do
  exhibits = [2, 3, 4, 5, 6, 8]
  rewarded = lambda { $game_self_switches[[300, 25, "A"]] }
  all_read = lambda { $game_variables[58].to_i >= exhibits.length }
  mechanic(:state, 300) do
    auto
    name exhibits, :hl_school_item, :numbered => true,
         :when => lambda { |ev| PokeAccess::Puzzles.assist? && !rewarded.call && !$game_self_switches[[300, ev.id, "A"]] }
    spot :event => 25, :label => :hl_school_prize, :assist => true, :when => lambda { all_read.call && !rewarded.call }
    phase lambda { !rewarded.call }, :quiet => true,
          :hint => lambda { all_read.call ? [:hl_school_hint, { :x => 41, :y => 12 }] : nil },
          :progress => { :var => 58, :of => exhibits.length, :label => :hl_school_count, :announce => true,
                         :assist => true }
    solved { rewarded.call }
  end
end
