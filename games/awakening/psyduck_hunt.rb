# Awakening's PsyduckHunt (the tavern's shooting minigame, on BaseMinigame): the score, the hits counter, the pause and
# the time bar, said as they change, and the score as the round ends. Where the targets fly is not read.
module PokeAccess
  module AwakeningPsyduck
    # The fractions of the time bar, in percent, whose crossing is said.
    TIME_MARKS = [10, 25, 50, 75]

    def self.watch(scene); @scene = scene; @last = nil; end

    # Ends the watch as the round's loop returns, with the final score.
    def self.unwatch
      s = @scene
      @scene = nil
      @last = nil
      PokeAccess.speak(PokeAccess::I18n.t(:awk_duck_final, :n => PokeAccess.ivar(s, :@score).to_i), false) if s
    end

    # Once per frame while a round runs: what changed since the last frame, said at once.
    def self.poll
      s = @scene
      return unless s
      now = state(s)
      prev = @last
      @last = now
      return if prev.nil?
      parts = changes(prev, now)
      PokeAccess.speak(parts.join(". "), true) unless parts.empty?
    rescue StandardError
      nil
    end

    # [score, hits, paused, time mark] of the round on screen.
    def self.state(s)
      [PokeAccess.ivar(s, :@score).to_i, PokeAccess.ivar(s, :@hits).to_i, PokeAccess.ivar(s, :@pause) ? true : false,
       time_mark(s)]
    end

    # The smallest time mark the bar has come down to, or 100 above them all.
    def self.time_mark(s)
      total = PokeAccess.ivar(s, :@totalFrames).to_i
      return 100 if total <= 0
      pct = PokeAccess.ivar(s, :@framesLeft).to_i * 100 / total
      TIME_MARKS.find { |m| pct <= m } || 100
    end

    # The spoken changes between two frames: the pause (and, paused, how to quit), a new score with the hits, the
    # hits alone when a miss drops them, and the time bar crossing a mark.
    def self.changes(prev, now)
      out = []
      if now[2] && !prev[2]
        quit = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:awk_duck_quit_key))
        out.push(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:awk_duck_pause), quit))
      elsif prev[2] && !now[2]
        out.push(PokeAccess::I18n.t(:awk_duck_resume))
      end
      if now[0] != prev[0]
        out.push(PokeAccess::I18n.t(:awk_duck_score, :n => now[0], :hits => now[1]))
      elsif now[1] != prev[1]
        out.push(PokeAccess::I18n.t(:awk_duck_hits, :n => now[1]))
      end
      out.push(PokeAccess::I18n.t(:awk_duck_time, :n => now[3])) if now[3] < prev[3]
      out
    end
  end
end

PokeAccess::SceneWatcher.wire("PsyduckHunt", :pbUpdate, PokeAccess::AwakeningPsyduck)
