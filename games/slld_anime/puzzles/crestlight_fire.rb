# Crestlight's Dynaball fire (map 41, from switch 452): the house asks for a Pokemon with foam, Salatad alone (switch
# 453); upstairs a 25-second countdown (switch 454) starts, and each action press sets Bubble Beam (event 20) on the
# player's tile, putting out a fire on or beside it (events_touching?) and adding one to variable 373; eight (switch
# 456) ends it. A retry lights the seven fires again but not the trash can (event 7), so one after it went out cannot
# reach eight. No auto: the core's watcher would take Ash's stand-in and the bubble's page for walls.
module PokeAccess
  module SlldFire
    MAP = 41
    TRASH = 7
    FIRES = [7, 10, 11, 12, 13, 14, 15, 16]
    # Each shot: where the player stands, the way they face (at one of its fires) and the fires it puts out.
    SHOTS = [[[26, 7], 6, [15]], [[23, 9], 2, [12]], [[21, 8], 8, [16]], [[21, 12], 2, [14]], [[24, 12], 2, [13]],
             [[25, 12], 6, [11]], [[28, 12], 2, [7, 10]]]
    LABELS = { 2 => :fx_slld_fire_shot_down, 6 => :fx_slld_fire_shot_right, 8 => :fx_slld_fire_shot_up }

    # True while the countdown runs.
    def self.burning?
      $game_switches[454] && !$game_switches[456] ? true : false
    end

    # True while fire id burns.
    def self.lit?(id)
      $game_switches[453] && !$game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # True while a shot is still to take: one of its fires burns and, for the trash can's, no other does, so a retry
    # after the time runs out still finds all eight to put out.
    def self.due?(ids)
      return false unless burning? && ids.any? { |id| lit?(id) }
      !ids.include?(TRASH) || (FIRES - ids).none? { |id| lit?(id) }
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  fire = PokeAccess::SlldFire
  mechanic(:state, fire::MAP) do
    on_reach 4, { :text => /foam/ },
             lambda { |_ev| [:puzzle_answer, { :a => PokeAccess::Data.species_name(:SALATAD).to_s }] }, :assist => true
    name 7, :fx_slld_fire_trash, :when => lambda { |ev| fire.lit?(ev.id) }
    name(/\AFire\z/, :fx_slld_fire_flame, :when => lambda { |ev| fire.lit?(ev.id) })
    fire::SHOTS.each do |at, dir, ids|
      spot :at => at, :label => fire::LABELS[dir], :onto => true, :assist => true, :when => lambda { fire.due?(ids) }
    end
    count :fx_slld_fires, :var => 373, :of => 8, :assist => true, :hide_zero => true
    active { $game_switches[452] && !$game_switches[456] }
    solved(nil, :quiet => true) { $game_switches[456] }
    hint :fx_slld_fire_hint
  end
end
