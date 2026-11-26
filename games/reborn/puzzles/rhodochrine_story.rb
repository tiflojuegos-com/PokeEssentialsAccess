# Rhodochrine Jungle (map 150), the story's way on by variable 77, simulated with the mod's moves: the pit, the cage,
# Cain, the vines' two trees (variables 655 and 656) and the way round through Beryl Ward. Only Beryl Ward's Cut tree at
# (19,17) shuts it; the bridges' switch 96 changes no leg. A visit's part of a map is told by the landing.
module PokeAccess
  module RebornRhodochrineStory
    AROUND = [
      [150, [148, 82], [31], :rbre_rj_around_east], [150, [158, 62], [88], :rbre_rj_tree2],
      [150, nil, [5], :rbre_rj_around_down], [153, nil, [8], :rbre_rj_around_up],
      [149, [9, 24], [40, 45], :rbre_rj_around_house], [149, [11, 15], [84], :rbre_rj_around_back],
      [155, nil, [1], :rbre_rj_around_out]
    ]
    STEPS = [
      [150, 3, [59], :rbre_rj_pit], [150, 7, [248], :rbre_rj_lever], [150, 8, [250], :rbre_rj_cain],
      [150, 10, [272], :rbre_rj_leave]
    ]
    VINES_DONE = [150, nil, [328], :rbre_rj_vines_done]
    TREE1 = [150, nil, [51], :rbre_rj_tree1]

    # Forgets where the visit began.
    def self.forget
      @entry = nil
    end

    # The story's stage, variable 77.
    def self.stage
      $game_variables[77].to_i
    end

    # The tile the visit of this map began on.
    def self.entry(map)
      @entry = [map, $game_player.x, $game_player.y] unless @entry && @entry[0] == map
      @entry[1, 2]
    end

    # The step that goes on from this map, [map, landing, events, hint], or nil.
    def self.step(map)
      s = stage
      return STEPS.find { |st| st[0] == map && st[1] == s } unless s == 9
      first = $game_variables[655].to_i >= 4
      second = $game_variables[656].to_i >= 6
      return(map == 150 ? VINES_DONE : nil) if first && second
      return(map == 150 ? TREE1 : nil) if second || (map == 150 && !first && !away?)
      at = entry(map)
      AROUND.find { |st| st[0] == map && st[1] == at } || AROUND.find { |st| st[0] == map && st[1].nil? }
    end

    # True on a visit of 150 that began on one of the landings past the first vine's side.
    def self.away?
      [[148, 82], [158, 62]].include?(entry(150))
    end

    # Every step a map can give, each once.
    def self.steps(map)
      out = []
      [STEPS, AROUND, [VINES_DONE, TREE1]].each { |list| out.concat(list.select { |s| s[0] == map }) }
      out
    end
  end
end

PokeAccess::Game.define("reborn") do
  story = PokeAccess::RebornRhodochrineStory
  [149, 150, 153, 155].each do |map|
    mechanic(:state, map, :part => :story) do
      auto
      story.steps(map).each do |entry|
        phase(lambda { PokeAccess::Puzzles.assist? && story.step(map).equal?(entry) }, :quiet => true,
              :hint => entry[3], :hidden => right_way(*entry[2]))
      end
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornRhodochrineStory.forget }
