module PokeAccess
  # RMXP's event timer (the Control Timer command), drawn by Sprite_Timer in a box at the top right in every era: a
  # countdown is said once as it starts, and the field key reads its time left while it runs. Whether it runs is the
  # game's own state, not the box: a gen-6 map keeps a timer sprite per connected map, and never shows a box it hid.
  module EventTimer
    # After a timer sprite's update: the seconds it counts while the game's timer runs, nil once it stops; the first
    # ones of a countdown are said, queued. Another $game_system (a new or loaded game) starts afresh.
    def self.update(sprite)
      sys = $game_system
      @left = nil unless sys.equal?(@system)
      @system = sys
      secs = running?(sys) ? PokeAccess.ivar(sprite, :@total_sec) : nil
      PokeAccess.speak(line_for(secs), false) if secs && @left.nil?
      @left = secs
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the game's timer runs: timer_start is set while it does from v21, timer_working before.
    def self.running?(sys)
      return false if sys.nil?
      return !sys.timer_start.nil? if sys.respond_to?(:timer_start)
      (sys.timer_working rescue false) ? true : false
    end

    # The running countdown as the field key says it, nil when no timer runs.
    def self.line
      @left ? line_for(@left) : nil
    end

    def self.line_for(secs)
      PokeAccess::I18n.t(:event_timer, :t => PokeAccess::Battle.fmt_mmss(secs))
    end
  end
end

PokeAccess::Hooks.after_hook("Sprite_Timer", :update, :optional => true) do |sprite, _r, _a|
  PokeAccess::EventTimer.update(sprite)
end
