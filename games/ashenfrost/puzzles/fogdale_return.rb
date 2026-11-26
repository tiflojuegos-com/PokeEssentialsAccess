# Return to Fogdale Isle, parts three and four: Twisting Cave (map 695, mud EV9, EV23 to EV25, variable 374), Jete
# Logging Camp (map 795, snow piles EV16 to EV20, variable 377; step 375), the cabin basket (map 796, EV5), Jete Valley
# (map 798, small trees, east ones EV28 to EV30) and the Academy presentation (map 792, EV25, mistakes in 379).
module PokeAccess
  module AshenFogdaleReturn
    CAVE = 695
    MUD = [9, 23, 24, 25]
    OTHER_SMELLS = [26, 27]
    MUD_VAR = 374
    QUEST = 373
    NOSE = 71
    IVAN = 20
    JELLYBEAN = 21
    CAMP = 795
    PILES = [16, 17, 18, 19, 20]
    NINJA = 19
    PILE_VAR = 377
    JETE = 375
    FRONT_DOOR = 5
    CABIN = 796
    BASKET = 5
    VALLEY = 798
    TREES = (23..30).to_a
    EAST_TREE = 28
    ACADEMY = 792
    PRESENTER = 25
    MISTAKES = 379

    # Whether a self switch of an event on a map is on.
    def self.on?(map, ev, letter = "A")
      $game_self_switches[[map, ev, letter]] ? true : false
    end

    # The mud patches sniffed, at most the four the count asks for.
    def self.mud_found
      [$game_variables[MUD_VAR].to_i, MUD.length].min
    end

    # Whether Ivan's errand runs in the cave: the quest at his step and the mud not all sniffed.
    def self.cave_live?
      $game_variables[QUEST].to_i >= 2 && $game_variables[MUD_VAR].to_i < 4
    end

    # Whether Jellybean is sniffing for the mud.
    def self.sniffing?
      cave_live? && $game_switches[NOSE] ? true : false
    end

    # Before the sniffing: who to talk to first, Ivan until he has spoken, Jellybean after; nil once she sniffs.
    def self.cave_first
      return nil if !cave_live? || $game_switches[NOSE]
      on?(CAVE, JELLYBEAN) ? JELLYBEAN : IVAN
    end

    # The memory's step on the camp, variable 375.
    def self.jete; $game_variables[JETE].to_i; end

    # Whether the snow piles are the task: the partner chosen and the piles not all cleared.
    def self.clearing_snow?
      jete == 3 && $game_variables[PILE_VAR].to_i < 5
    end

    # Whether a pile is done: the Ninja stays drawn after its fight, the others vanish.
    def self.pile_done?(ev)
      on?(CAMP, ev)
    end

    # Whether the trees by the east exits have fallen.
    def self.east_open?; on?(VALLEY, EAST_TREE); end

    # Whether the trees are to cut: the valley at step 7 and the east trees standing.
    def self.trees_left?
      jete >= 7 && !east_open?
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  fog = PokeAccess::AshenFogdaleReturn
  mechanic(:state, fog::CAVE, :part => :mud) do
    auto
    active { fog.cave_live? }
    name fog::MUD, :afi_mud_smell,
         :when => lambda { |ev| fog.sniffing? && !(PokeAccess::Puzzles.assist? && fog.on?(fog::CAVE, ev.id)) }
    name fog::OTHER_SMELLS, :afb_smell, :when => lambda { |_ev| fog.sniffing? }
    hide fog::MUD, :assist => true, :when => lambda { |ev| fog.on?(fog::CAVE, ev.id) }
    count :afi_mud_found, :value => lambda { fog.mud_found }, :of => fog::MUD.length, :assist => true
    phase lambda { PokeAccess::Puzzles.assist? && fog.cave_first == fog::IVAN }, :quiet => true,
          :hint => :afi_cave_ivan, :hidden => right_way(fog::IVAN)
    phase lambda { PokeAccess::Puzzles.assist? && fog.cave_first == fog::JELLYBEAN }, :quiet => true,
          :hint => :afi_cave_jellybean, :hidden => right_way(fog::JELLYBEAN)
    phase lambda { PokeAccess::Puzzles.assist? && fog.sniffing? }, :quiet => true, :hint => :afi_cave_mud
    solved(nil, :quiet => true) { $game_variables[fog::MUD_VAR].to_i >= 4 }
  end

  mechanic(:state, fog::CAMP, :part => :snow) do
    auto
    active { fog.jete >= 3 && fog.jete < 5 }
    name fog::PILES, :afi_snow_pile, :when => lambda { |ev| !(PokeAccess::Puzzles.assist? && fog.pile_done?(ev.id)) }
    hide fog::NINJA, :assist => true, :when => lambda { |ev| fog.pile_done?(ev.id) }
    count :afi_snow_piles, :var => fog::PILE_VAR, :of => fog::PILES.length, :assist => true
    phase lambda { PokeAccess::Puzzles.assist? && fog.clearing_snow? }, :quiet => true, :hint => :afi_snow_hint
    phase lambda { PokeAccess::Puzzles.assist? && fog.jete == 4 }, :quiet => true, :hint => :afi_basket_door,
          :hidden => right_way(fog::FRONT_DOOR)
    solved(nil, :quiet => true) { fog.jete >= 5 }
  end

  mechanic(:state, fog::CABIN, :part => :basket) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? && fog.jete == 4 }, :quiet => true, :hint => :afi_basket_take,
          :hidden => right_way(fog::BASKET)
  end

  mechanic(:state, fog::VALLEY, :part => :trees) do
    auto
    active { fog.trees_left? }
    name fog::TREES, :afi_small_tree
    phase lambda { PokeAccess::Puzzles.assist? && fog.trees_left? }, :quiet => true, :hint => :afi_trees_hint,
          :hidden => right_way(fog::EAST_TREE)
    solved(nil, :quiet => true) { fog.east_open? }
  end

  mechanic(:state, fog::ACADEMY, :part => :presentation) do
    auto
    right_choice fog::PRESENTER, :avoids => { :var => fog::MISTAKES }
  end
end
