# Urayne's levers (map 250). The laser gate: three levers alike but for their colour, green on the left (event 83), blue
# in the middle (82) and red on the right (28), count in variable 156 as they are pulled in the order of the manual to the
# east (green, red, blue); any other pull, or one pulling a lever back up, sets it to 0. At 3 the lasers south of the
# first room go out. The conveyor maze behind them: escalators carry the player along fixed routes, three switch levers
# (103, 133 and 91) turn some of them, and eight of the nine capacity levers (variable 155, said by the game) open the
# south door.
module PokeAccess
  module UrayneLaser
    # The levers in the order that opens the gate, with their names.
    def self.order; [83, 28, 82]; end
    def self.names; { 83 => :ura_rp_laser_green, 28 => :ura_rp_laser_red, 82 => :ura_rp_laser_blue }; end
    def self.nexts; { 83 => :ura_rp_laser_next_green, 28 => :ura_rp_laser_next_red, 82 => :ura_rp_laser_next_blue }; end

    def self.down?(id); $game_self_switches[[250, id, "A"]] ? true : false; end
    def self.step; [$game_variables[156].to_i, 0].max; end
    def self.open?; step >= 3; end

    # Whether the player is in the rooms of the levers and the gate, north of the lasers: the box ends at the doorways
    # to the east, the way in from the other maps.
    def self.near?
      $game_player.x.between?(8, 37) && $game_player.y.between?(17, 33)
    end

    # The rule's phase: from the first time in the box this visit until the gate opens.
    def self.live?; PokeAccess::UraniumVisit.since(:laser) { near? } && !open?; end

    # A lever's name, with its position once pulled down.
    def self.lever_name(ev)
      key = names[ev.id]
      down?(ev.id) ? [:ura_rp_lever_down, { :lever => PokeAccess::I18n.t(key) }] : key
    end

    # The next pull: the lever the count waits for, or, with a lever down out of turn, pulling those back up first.
    def self.hint
      return "" if open?
      return :ura_rp_laser_raise if order[step..-1].any? { |id| down?(id) }
      nexts[order[step]]
    end
  end

  module UrayneMaze
    # The capacity levers in an order the maze lets the player take them from its entrance, each with the switch levers
    # it needs moved (true) or as they start (false).
    def self.plan
      [[102, {}], [98, {}], [96, { 103 => false }], [33, { 103 => true }], [92, { 103 => true, 91 => false }],
       [95, { 103 => true }], [100, { 103 => true, 91 => false }], [93, { 103 => true, 91 => true }], [94, { 103 => true }]]
    end

    def self.capacity; plan.map { |id, _needs| id }; end
    def self.switches; [103, 133, 91]; end
    def self.pulled?(id); $game_self_switches[[250, id, "A"]] ? true : false; end
    def self.charged; $game_variables[155].to_i; end
    def self.open?; charged >= 8; end

    # Whether the player is in the maze, south of the wire rooms.
    def self.near?
      $game_player.x.between?(4, 100) && $game_player.y.between?(80, 140)
    end

    # The rule's phase: from the first time in the box this visit until the door opens.
    def self.live?; PokeAccess::UraniumVisit.since(:maze) { near? } && !open?; end

    def self.capacity_name(ev); pulled?(ev.id) ? :ura_rp_capacity_pulled : :ura_rp_capacity; end
    def self.switch_name(ev); pulled?(ev.id) ? :ura_rp_switch_moved : :ura_rp_switch; end

    # The next capacity lever of the plan still up, or the switch lever to set first for the escalators to reach it.
    def self.hint
      return "" if open?
      found = plan.find { |id, _needs| !pulled?(id) }
      return "" unless found
      id, needs = found
      wrong = switches.find { |switch| needs.key?(switch) && pulled?(switch) != needs[switch] }
      target = $game_map.events[wrong || id]
      return "" unless target
      [wrong ? :ura_rp_maze_switch_first : :ura_rp_maze_next, { :x => target.x, :y => target.y }]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 250, :part => :laser) do
    auto
    name PokeAccess::UrayneLaser.order, lambda { |ev| PokeAccess::UrayneLaser.lever_name(ev) }
    phase lambda { PokeAccess::UrayneLaser.live? },
          :title => :ura_rp_laser_rule,
          :entry_title => true, :hint => lambda { PokeAccess::UrayneLaser.hint }
    solved(nil) { PokeAccess::UrayneLaser.open? }
  end

  mechanic(:state, 250, :part => :maze) do
    auto
    name PokeAccess::UrayneMaze.capacity, lambda { |ev| PokeAccess::UrayneMaze.capacity_name(ev) },
         :when => lambda { |ev| !PokeAccess::UrayneMaze.pulled?(ev.id) }
    name PokeAccess::UrayneMaze.switches, lambda { |ev| PokeAccess::UrayneMaze.switch_name(ev) }
    count :ura_rp_maze_count, :var => 155, :of => 8, :announce => false
    phase lambda { PokeAccess::UrayneMaze.live? },
          :title => :ura_rp_maze_rule,
          :entry_title => true, :hint => lambda { PokeAccess::UrayneMaze.hint }
    solved(nil) { PokeAccess::UrayneMaze.open? }
  end
end
