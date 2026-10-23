module PokeAccess
  # The Elite Battle System's battle menus, which replace the display classes the gen-6 core reads: the command
  # buttons (NewCommandWindow), the move buttons with the Mega Evolution button (NewFightWindow), and a wild Pokemon's
  # Nuclear entrance. The prompt with its party balls and the question boxes are plugins/ebs_ui.rb's.
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The Mega Evolution button toggled inside the menu; hide puts the button away first, so its reset stays silent.
    def self.mega_set(cw, on)
      return unless PokeAccess.ivar(cw, :@showMega)
      PokeAccess.speak(PokeAccess::I18n.t(on ? :bt_mega_on : :bt_mega_off), true)
    end

    # A common animation the scene plays: the Nuclear one, shown as a wild Nuclear Pokemon comes out, is said after
    # the next message line (the appearance), with that Pokemon's name.
    def self.animation(name, battler)
      return unless name.to_s == "Nuclear"
      line = PokeAccess::I18n.t(:ura_nuclear_entry, :name => (battler.name rescue ""))
      PokeAccess.after_next_line([PokeAccess.take_tail, line].compact.join(". "))
    end
  end
end

PokeAccess::Game.define("uranium") do
  around("NewCommandWindow", :refreshCommands) { |cw, nxt, _a| PokeAccess::UraniumBattle.paint_commands(cw) { nxt.call } }
  focus_reader("NewCommandWindow", :items => :@access_ura_cmds, :slot => :ura_cmd) { |label| label }
  after("NewFightWindow", :battler=) { |cw, _r, _a| PokeAccess::UraniumBattle.fight_opened(cw) }
  after("NewFightWindow", :update) { |cw, _r, _a| PokeAccess::UraniumBattle.fight_update(cw) }
  after("NewFightWindow", :megaButtonSet) { |cw, _r, args| PokeAccess::UraniumBattle.mega_set(cw, args[0]) }
  before("PokeBattle_Scene", :pbCommonAnimation) do |_s, args|
    PokeAccess::UraniumBattle.animation(args[0], args[1])
  end
end
