# The Elite Battle System's battle UI as Uranium's and Sevii's copies paint it alike: a battle question's choice boxes
# (NewChoiceSel), and the command prompt with the party balls drawn beside it, written by either game's command window
# (NewCommandWindow, or NextGenCommandWindow under the Next Generation style).
module PokeAccess
  module EbsUi
    # After the prompt is written over the command buttons: in a double battle where the player orders both Pokemon
    # (no partner commands the second), which one the order is for, queued; and for the info key, the foes as the core
    # describes them and the party balls drawn beside the prompt.
    def self.prompt(cw, msg)
      battle = PokeAccess.ivar(cw, :@battle)
      return if battle.nil?
      both = (battle.doublebattle && battle.pbOwnedByPlayer?(2) rescue false)
      PokeAccess.speak(PokeAccess.clean(msg.to_s), false) if both
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([PokeAccess::Battle.foe_info, balls(cw, battle)]))
    end

    # Whether the window draws the party balls: not in the Safari Zone, nor where it paints them through drawLineup
    # (the Next Generation style) while the game's SHOWPARTYARROWS is off.
    def self.balls_drawn?(cw)
      return false if PokeAccess.ivar(cw, :@safaribattle)
      return true unless cw.respond_to?(:drawLineup) && defined?(::SHOWPARTYARROWS)
      ::SHOWPARTYARROWS ? true : false
    end

    # The party balls the prompt shows, as counts by the state each ball is drawn in: the six slots of the player's
    # side (a partner's Pokemon, stored after them, get none), and against a trainer the foe's six, the last three of
    # a double battle taken from where the foe's second party begins; none where the window draws none.
    def self.balls(cw, battle)
      return nil unless balls_drawn?(cw)
      mine = (0...6).map { |i| battle.party1[i] }
      parts = [PokeAccess::I18n.t(:ura_balls_mine, :list => ball_counts(mine))]
      if battle.opponent
        second = battle.doublebattle ? battle.pbSecondPartyBegin(1) : 3
        foe = (0...6).map { |i| battle.party2[i < 3 ? i : (i % 3) + second] }
        parts.push(PokeAccess::I18n.t(:ura_balls_foe, :list => ball_counts(foe)))
      end
      PokeAccess.sentences(parts)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A side's members by ball: healthy, with a status problem, and fainted (an egg is drawn as fainted).
    def self.ball_counts(party)
      n = [0, 0, 0]
      (party || []).each do |pk|
        next unless pk
        if pk.hp <= 0 || (pk.isEgg? rescue false)
          n[2] += 1
        elsif pk.status > 0
          n[1] += 1
        else
          n[0] += 1
        end
      end
      keys = [:ura_balls_ok, :ura_balls_status, :ura_balls_fainted]
      (0...3).select { |k| n[k] > 0 }.map { |k| PokeAccess::I18n.t(keys[k], :n => n[k]) }.join(", ")
    end
  end
end

PokeAccess::Hooks.after_hook("NewCommandWindow", :text=, :optional => true) do |cw, _r, args|
  PokeAccess::EbsUi.prompt(cw, args[0])
end
PokeAccess::Hooks.after_hook("NextGenCommandWindow", :text=, :optional => true) do |cw, _r, args|
  PokeAccess::EbsUi.prompt(cw, args[0])
end

PokeAccess::FocusReader.define("NewChoiceSel", :items => :@commands, :slot => :ebs_choice, :optional => true) { |box| box }
PokeAccess::Hooks.before_hook("NewChoiceSel", :dispose, :optional => true) do |sel, _a|
  PokeAccess::Cursor.reset(sel, :ebs_choice)
end
