module PokeAccess
  # The time trial on Route 110's cycling road (timeTrialStart): the clock starts silently as the player crosses the start
  # line on the bike, and nothing on screen shows the time, the bumps that add half a second each or the finish line
  # (the timeTrialStop event, drawn with no graphic). The start is said, queued; while the trial runs, the info key on
  # the map says the time so far, the bumps and where the finish line lies.
  module IF2TimeTrial
    FINISH = /\AtimeTrialStop/

    # Says the start, queued, with what the info key tells while key hints are said.
    def self.started
      line = PokeAccess::I18n.t(:if2_trial_start)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(line, PokeAccess::I18n.t(:if2_trial_hint)), false)
    end

    # Whether a trial runs now: the game's own switch for it.
    def self.running?
      defined?(::SWITCH_TIME_TRIAL) && $game_switches && $game_switches[::SWITCH_TIME_TRIAL] ? true : false
    end

    # The info key's line while a trial runs, else nil.
    def self.line
      return nil unless running? && defined?(::VAR_TIME_TRIAL_START)
      start = $game_variables[::VAR_TIME_TRIAL_START]
      return nil unless start.is_a?(Time)
      t = PokeAccess::I18n
      clock = t.t(:if2_trial_time, :n => [(Time.now - start).floor, 0].max)
      bumps = ($game_temp.time_trial_bumps rescue nil).to_i
      clock = "#{clock}, #{t.t(:if2_trial_bumps, :n => bumps)}" if bumps > 0
      PokeAccess.sentences([clock, goal])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Where the finish line's nearest tile lies from the player, or nil on a map without one.
    def self.goal
      p = $game_player
      ev = $game_map.events.values.find { |e| (e.name rescue "").to_s =~ FINISH }
      return nil unless ev && p
      tile = PokeAccess::World::Events.tiles_of(ev).min_by { |x, y| (x - p.x).abs + (y - p.y).abs }
      PokeAccess::I18n.t(:if2_trial_goal, :dir => PokeAccess::Locator.dir_phrase(tile[0] - p.x, tile[1] - p.y))
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  kernel("timeTrialStart", :after) { |_a, _r| PokeAccess::IF2TimeTrial.started }
  PokeAccess::Info.map_owner(:if2_time_trial) { PokeAccess::IF2TimeTrial.line }
end
