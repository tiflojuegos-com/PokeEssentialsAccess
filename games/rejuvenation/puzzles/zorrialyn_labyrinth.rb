# Zorrialyn Labyrinth (maps 533, 536, 537, 541, then 542), the paid run with a step budget: variable 595, one per step,
# set to 600, 850, 650 and 450 as each floor starts; at 0 the floor's parallel event throws the player back to the
# guide. Variable 559 marks the floors; each floor's inscription gives an objective that opens its sealed door.
module PokeAccess
  module RejuvLabyrinth
    LUVDISC = [37, 39, 38, 36]
    POOL = [53, 8]
    SURFACE = [25, 85]
    # B1 to B3 by map: the floor, its inscription, sealed door, objective and exit, the value of 559 its objective
    # sets, and the assist's lines.
    FLOORS = {
      533 => { :n => 1, :panel => 42, :door => 43..51, :goal => 42, :open => 1,
               :exit => { :event => 53, :label => :rjra_lab_exit },
               :hint => lambda { hint_line(:rjra_lab_b1_hint) }, :out => :rjra_lab_b1_out },
      536 => { :n => 2, :panel => [4, 16], :door => 7..15, :goal => 6, :open => 4, :coffin => 6,
               :exit => { :event => 83, :label => :rjra_lab_exit },
               :hint => lambda { hint_line(:rjra_lab_b2_hint) }, :out => :rjra_lab_b2_out },
      537 => { :n => 3, :panel => 85, :door => 74..82, :goal => 85, :open => 7,
               :exit => { :at => POOL, :label => :rjra_lab_pool },
               :hint => lambda { b3_hint }, :out => :rjra_lab_b3_out }
    }

    # The floors' variable, the steps left and the Luvdisc beaten.
    def self.stage; $game_variables[559].to_i; end
    def self.steps; $game_variables[595].to_i; end
    def self.hearts; $game_variables[560].to_i; end

    # True on B4's stretch past the Luvdisc door, where the way back from 542 leads.
    def self.past_door?
      $game_player.x.between?(52, 54) && $game_player.y.between?(67, 81)
    end

    # True once B4's door is open, or behind the player.
    def self.b4_open?
      hearts >= 4 || past_door?
    end

    # A hint with the steps left.
    def self.hint_line(key)
      [key, { :steps => steps }]
    end

    # The party's Pokémon that are both Rock and Water, by name.
    def self.rock_water
      party = (PokeAccess::Engine.player.party rescue nil) || []
      party.compact.select do |pk|
        !(pk.egg? rescue false) && (pk.hasType?(:ROCK) rescue false) && (pk.hasType?(:WATER) rescue false)
      end.map { |pk| PokeAccess.clean(pk.name.to_s) }
    end

    # B3's hint: the objective and which party member does it, if any.
    def self.b3_hint
      names = rock_water
      party = if names.empty? then PokeAccess::I18n.t(:rjra_lab_b3_none)
              else PokeAccess::I18n.t(:rjra_lab_b3_party, :names => names.join(", "))
              end
      PokeAccess::I18n.t(:rjra_lab_b3_hint, :party => party, :steps => steps)
    end

    # True while a Luvdisc event still stands on the map.
    def self.standing?(id)
      ev = $game_map.events[id]
      !ev.nil? && !(ev.instance_variable_get(:@erased) rescue false) && PokeAccess::World::Mechanics::State.drawn?(ev)
    end

    # The Luvdisc to go for next, in the shortest order from the floor plates, while the door is shut.
    def self.next_luvdisc
      return nil if hearts >= 3 || past_door?
      LUVDISC.find { |id| standing?(id) }
    end

    # A floor's line, by its number.
    def self.floor_line(key, n)
      [key, { :n => n }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  lab = PokeAccess::RejuvLabyrinth
  shown = lambda { |ev| PokeAccess::World::Mechanics::State.drawn?(ev) }
  watchers(533)

  lab::FLOORS.each do |map, f|
    shut = lambda { lab.stage < f[:open] }
    open = lambda { lab.stage == f[:open] }
    mechanic(:state, map, :part => :labyrinth) do
      auto
      name f[:panel], :rjra_lab_panel, :grouped => true
      name f[:door], :rjra_lab_door, :grouped => true, :when => shown
      name f[:coffin], :rjra_lab_coffin, :when => lambda { |_ev| shut.call } if f[:coffin]
      spot :event => f[:goal], :label => :rjra_lab_goal, :assist => true, :when => shut
      spot f[:exit].dup.merge!(:onto => true, :assist => true, :when => open)
      phase(shut, :title => lab.floor_line(:rjra_lab_shut, f[:n]), :quiet => true, :hint => f[:hint])
      phase(open, :title => lab.floor_line(:rjra_lab_open, f[:n]), :hint => lambda { lab.hint_line(f[:out]) })
      solved(nil, :quiet => true) { lab.stage > f[:open] }
    end
  end

  mechanic(:state, 541, :part => :labyrinth) do
    auto
    name 76, :rjra_lab_panel
    name 104..112, :rjra_lab_door, :grouped => true, :when => shown
    count :rjra_lab_luvdisc, :value => lambda { [lab.hearts, 3].min }, :of => 3, :hide_zero => true, :reset => false
    lab::LUVDISC.each do |id|
      spot :event => id, :label => :rjra_lab_luvdisc_next, :assist => true, :when => lambda { lab.next_luvdisc == id }
    end
    spot :event => 79, :label => :rjra_lab_exit, :onto => true, :assist => true, :when => lambda { lab.b4_open? }
    phase(lambda { !lab.b4_open? }, :title => lab.floor_line(:rjra_lab_shut, 4), :quiet => true,
          :hint => lambda { lab.hint_line(:rjra_lab_b4_hint) })
    phase(lambda { lab.b4_open? }, :title => lab.floor_line(:rjra_lab_open, 4),
          :hint => lambda { lab.hint_line(:rjra_lab_b4_out) })
  end

  mechanic(:state, 542, :part => :labyrinth) do
    auto
    spot :at => lab::SURFACE, :label => :rjra_lab_surface, :onto => true, :assist => true
    phase(lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => :rjra_lab_b5_hint)
  end
end
