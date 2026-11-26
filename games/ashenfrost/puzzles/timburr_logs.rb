# The Timburr's logs in Olde Riverviewe Weste (map 346, variable 94 at 6 or more): two piles pushed, event 30 then event
# 31 (shown once the first is in), onto (14, 27) or (15, 27) right of the Timburr (event 28); the check (event 32) waits
# for each, its self switch A marking the first and B the second.
module PokeAccess
  module AshenTimburrLogs
    MAP = 346
    GOAL = [14, 27, 15, 27]

    # Whether the Timburr gathers logs now.
    def self.on?
      $game_variables[94].to_i >= 6
    end

    # Whether a self switch of the check is on.
    def self.done?(letter)
      $game_self_switches[[MAP, 32, letter]] ? true : false
    end

    # The pile the check waits for: 30, then 31; nil before or after.
    def self.pile
      return nil unless on? && !done?("B")
      done?("A") ? 31 : 30
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  tl = PokeAccess::AshenTimburrLogs
  mechanic(:state, tl::MAP, :part => :timburr_logs) do
    auto
    name [30, 31], :afg_tl_log, :when => lambda { |ev| tl.pile == ev.id }
    [[30, :afg_tl_first], [31, :afg_tl_second]].each do |id, title|
      phase lambda { tl.pile == id }, :title => title, :quiet => true,
                                      :track => { :event => id, :label => :afg_tl_log, :goal => tl::GOAL,
                                                  :goal_label => :afg_tl_goal }
    end
    solved(nil, :quiet => true) { tl.done?("B") }
    active { !tl.pile.nil? }
  end
end
