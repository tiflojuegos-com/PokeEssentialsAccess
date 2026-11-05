# Royal's gym of Hoyuelo (map 125): three pens of Wooloo that run from the player, north, to a blue patch where two fit in each
# column. Variable 77 leads the trial (2, 5 and 8 the pens, 3-4, 6-7 and 9-10 the fences going down, 11 the way out) and
# variables 78 to 82 count the Wooloo stopped in each column of the patch. The game's script renames each Wooloo as it acts:
# wooloo1, wooloo1run while running, wooloo1stop in the patch.
module PokeAccess
  module RoyalHerd
    MAP = 125
    WOOLOO = [1..6, 20..23]
    NARROW = [78, 79, 80]
    WIDE = [81, 78, 79, 80, 82]

    # A test for a phase: variable 77 is one of the stages.
    def self.stage(*stages)
      lambda { stages.include?($game_variables[77].to_i) }
    end

    # A Wooloo's name by what it is doing now.
    def self.label(ev)
      name = ev.name.to_s
      return :royal_g1_wooloo_in if name =~ /stop\z/
      return :royal_g1_wooloo_run if name =~ /run\z/
      :royal_g1_wooloo
    end

    # The columns of a blue patch, left to right, as the numbers a phase lists.
    def self.columns(vars)
      idx = 0
      vars.map { |v| { :var => v, :label => [:royal_g1_column, { :n => idx += 1 }] } }
    end
  end
end

PokeAccess::Game.define("royal") do
  herd = PokeAccess::RoyalHerd
  mechanic(:state, herd::MAP) do
    name herd::WOOLOO, lambda { |ev| herd.label(ev) }
    phase herd.stage(2), :title => :royal_g1_pen1, :hint => :royal_g1_hint1, :values => herd.columns(herd::NARROW),
          :sum => true, :spots => [{ :at => [11, 73], :label => :royal_g1_goal }]
    phase herd.stage(3, 4), :title => :royal_g1_fences
    phase herd.stage(5), :title => :royal_g1_pen2, :hint => :royal_g1_hint2, :values => herd.columns(herd::NARROW),
          :sum => true, :spots => [{ :at => [11, 54], :label => :royal_g1_goal }]
    phase herd.stage(6, 7), :title => :royal_g1_fences
    phase herd.stage(8), :title => :royal_g1_pen3, :hint => :royal_g1_hint3, :values => herd.columns(herd::WIDE),
          :sum => true, :spots => [{ :at => [11, 26], :label => :royal_g1_goal }]
    phase herd.stage(9, 10), :title => :royal_g1_fences
    phase herd.stage(11), :title => :royal_g1_last
    solved(nil) { $game_variables[77].to_i >= 12 }
    arrival_hint :royal_g1_rule
  end
end
