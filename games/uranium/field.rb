module PokeAccess
  # Uranium's own overlays and screens over the field: the eighth gym's tile counter, the scoreboard of Tandor's
  # championship, the Nuzlocke game over and the post-game letter.
  module UraniumField
    # Runs a paint of the eighth gym's counter (on creation, and when the white count changes) and says the lines it
    # painted; the first, queued, with the goal that opens the door: half of the room's tiles white. The info key
    # keeps the counter and the goal while the counter is on show.
    def self.gym_counter(win, opening)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      if (PokeAccess.ivar(win, :@overlay).disposed? rescue false)
        gym_gone(win)
        return ret
      end
      lines = PokeAccess::PaintCapture.lines(pairs).map { |l| unpadded(l) }
      return ret if lines.empty?
      text = PokeAccess.sentences(lines)
      goal = PokeAccess::I18n.t(:ura_gym8_goal, :n => PokeAccess.ivar(win, :@tiles).to_i / 2)
      whole = PokeAccess.sentences([text, goal])
      PokeAccess::Info.set_info(:text, whole)
      win.instance_variable_set(:@access_gym_info, whole)
      PokeAccess.speak(opening ? whole : text, !opening)
      ret
    end

    # Takes the counter off the info key once its overlay is gone (the room solved, the map left), unless another
    # screen has put its own line there since.
    def self.gym_gone(win)
      kept = PokeAccess.ivar(win, :@access_gym_info)
      return if kept.nil?
      win.instance_variable_set(:@access_gym_info, nil)
      PokeAccess::Info.clear_text if PokeAccess::Info.info_text == kept
    end

    # A painted line with the padding zeros of its numbers dropped ("07" is said as 7).
    def self.unpadded(line)
      line.gsub(/\b0+(\d)/) { $1 }
    end

    # Runs the creation of a championship scoreboard and says the two names it paints, one against the other, once
    # per map: the stadium builds two boards with the same names.
    def self.scoreboard
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      names = PokeAccess::PaintCapture.laid_out(pairs).map { |t| PokeAccess.clean(t) }.reject { |t| t.empty? }
      return ret unless names.length == 2
      t = PokeAccess::I18n.t(:ura_score_vs, :a => names[0], :b => names[1])
      key = [($game_map.map_id rescue nil), t]
      PokeAccess.speak(t, false) unless @score == key
      @score = key
      ret
    end

    # Says a letter as pbDisplayLetter shows it, the message with the player's name in place and then its sender,
    # kept for the repeat key.
    def self.letter(message, sender)
      parts = [PokeAccess.clean(message.to_s)]
      parts.push(PokeAccess::I18n.t(:mail_from, :name => sender)) unless sender.to_s.strip.empty?
      t = PokeAccess.sentences(parts)
      return if t.empty?
      PokeAccess.note_dialogue(t)
      PokeAccess.speak(t, true)
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("GymWindow", :initialize) { |win, nxt, _a| PokeAccess::UraniumField.gym_counter(win, true) { nxt.call } }
  around("GymWindow", :update) { |win, nxt, _a| PokeAccess::UraniumField.gym_counter(win, false) { nxt.call } }
  before("GymWindow", :dispose) { |win, _a| PokeAccess::UraniumField.gym_gone(win) }
  around("ScoreWindow", :initialize) { |_w, nxt, _a| PokeAccess::UraniumField.scoreboard { nxt.call } }
  before("Scene_Gameover", :main) { |_s, _a| PokeAccess.speak(PokeAccess::TitleScreen.prompt(:ura_gameover), false) }
  kernel("pbDisplayLetter", :before) { |args, _r| PokeAccess::UraniumField.letter(args[0], args[1]) }
end
