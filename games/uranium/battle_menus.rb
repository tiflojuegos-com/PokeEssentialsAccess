module PokeAccess
  # The Elite Battle System's battle menus, which replace the display classes the gen-6 core reads: the command
  # buttons (NewCommandWindow) with the prompt and the party balls over them, the move buttons with the Mega
  # Evolution button (NewFightWindow) and the left/right choice boxes of a battle question (NewChoiceSel); and the
  # Nuclear entrance of a wild Pokemon.
  module UraniumBattle
    # Runs a refreshCommands keeping the four labels it paints, in button order, and resets the command cursor.
    def self.paint_commands(cw)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      labels = pairs.map { |p| PokeAccess.clean(p[0].to_s) }
      cw.instance_variable_set(:@access_ura_cmds, labels) unless labels.empty?
      PokeAccess::Cursor.reset(cw, :ura_cmd)
      PokeAccess::Info.set_info(:battle_foe, nil)
      ret
    end

    # Says the focused command once per change; the first read after the menu opens is queued behind the turn's lines.
    def self.command(cw)
      idx = PokeAccess.ivar(cw, :@index)
      PokeAccess::Cursor.announce(cw, :ura_cmd, idx, true, false) { (PokeAccess.ivar(cw, :@access_ura_cmds) || [])[idx] }
    end

    # Marks the move buttons as set up for a battler, so the next update reads the focused move afresh, queued.
    def self.fight_opened(cw)
      PokeAccess::Cursor.reset(cw, :fight_move)
      cw.instance_variable_set(:@access_ura_open, true)
    end

    # Reads the focused move on change; on opening, queued and followed by the Mega Evolution button when it is up.
    def self.fight_update(cw)
      opening = PokeAccess.ivar(cw, :@access_ura_open)
      cw.instance_variable_set(:@access_ura_open, false) if opening
      PokeAccess::Battle.read_fight_move(cw, !opening)
      PokeAccess.speak(PokeAccess::Battle.ready_text(:mega), false) if opening && mega_up?(cw)
    end

    # True while the Mega Evolution button is shown for a battler that can mega evolve.
    def self.mega_up?(cw)
      b = PokeAccess.ivar(cw, :@battler)
      battle = PokeAccess.ivar(b, :@battle)
      (PokeAccess.ivar(cw, :@showMega) && battle && battle.pbCanMegaEvolve?(b.index)) ? true : false
    rescue StandardError
      false
    end

    # The Mega Evolution button toggled inside the menu; hide puts the button away first, so its reset stays silent.
    def self.mega_set(cw, on)
      return unless PokeAccess.ivar(cw, :@showMega)
      PokeAccess.speak(PokeAccess::I18n.t(on ? :bt_mega_on : :bt_mega_off), true)
    end

    # After the prompt is written over the buttons: in a double battle, which Pokemon the order is for, queued; and
    # for the info key, the foes as the core describes them and the party balls drawn beside the prompt.
    def self.prompt(cw, msg)
      battle = PokeAccess.ivar(cw, :@battle)
      return if battle.nil?
      PokeAccess.speak(PokeAccess.clean(msg.to_s), false) if (battle.doublebattle rescue false)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([PokeAccess::Battle.foe_info, balls(cw, battle)]))
    end

    # The party balls the prompt shows, as counts by the state each ball is drawn in: the six slots of the player's
    # side (a partner's Pokemon, stored after them, get none), and against a trainer the foe's six, the last three of
    # a double battle taken from where the foe's second party begins; none in the Safari Zone, which draws none.
    def self.balls(cw, battle)
      return nil if PokeAccess.ivar(cw, :@safaribattle)
      mine = (0...6).map { |i| battle.party1[i] }
      parts = [PokeAccess::I18n.t(:ura_balls_mine, :list => ball_counts(mine))]
      if battle.opponent
        second = battle.doublebattle ? battle.pbSecondPartyBegin(1) : 3
        foe = (0...6).map { |i| battle.party2[i < 3 ? i : (i % 3) + second] }
        parts.push(PokeAccess::I18n.t(:ura_balls_foe, :list => ball_counts(foe)))
      end
      PokeAccess.sentences(parts)
    rescue StandardError
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

    # A common animation the scene plays: the Nuclear one, shown as a wild Nuclear Pokemon comes out, is said after
    # the next message line (the appearance), with that Pokemon's name.
    def self.animation(name, battler)
      return unless name.to_s == "Nuclear"
      line = PokeAccess::I18n.t(:ura_nuclear_entry, :name => (battler.name rescue ""))
      PokeAccess.after_next_line([PokeAccess.take_tail, line].compact.join(". "))
    end

    # Says the focused box of a battle question (the question is the message core reads), the first one queued.
    def self.choice(sel)
      idx = PokeAccess.ivar(sel, :@index)
      PokeAccess::Cursor.announce(sel, :ura_choice, idx, true, false) { (PokeAccess.ivar(sel, :@commands) || [])[idx] }
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("NewCommandWindow", :refreshCommands) { |cw, nxt, _a| PokeAccess::UraniumBattle.paint_commands(cw) { nxt.call } }
  after("NewCommandWindow", :update) { |cw, _r, _a| PokeAccess::UraniumBattle.command(cw) }
  after("NewFightWindow", :battler=) { |cw, _r, _a| PokeAccess::UraniumBattle.fight_opened(cw) }
  after("NewFightWindow", :update) { |cw, _r, _a| PokeAccess::UraniumBattle.fight_update(cw) }
  after("NewFightWindow", :megaButtonSet) { |cw, _r, args| PokeAccess::UraniumBattle.mega_set(cw, args[0]) }
  after("NewCommandWindow", :text=) { |cw, _r, args| PokeAccess::UraniumBattle.prompt(cw, args[0]) }
  before("PokeBattle_Scene", :pbCommonAnimation) do |_s, args|
    PokeAccess::UraniumBattle.animation(args[0], args[1])
  end
  after("NewChoiceSel", :update) { |sel, _r, _a| PokeAccess::UraniumBattle.choice(sel) }
  before("NewChoiceSel", :dispose) { |sel, _a| PokeAccess::Cursor.reset(sel, :ura_choice) }
end
