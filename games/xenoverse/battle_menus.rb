module PokeAccess
  # The battle menus of 0177_EliteBattle_UI, which replace the gen-6 display classes: the command row (its labels drawn
  # with pbDrawOutlineText on each refresh) and the fight menu with its Mega button. Core's Battle formats moves, HP,
  # targets and messages.
  module XenoverseBattleMenus
    # Runs a command or fight menu (kind), clearing the info key when the outermost one returns.
    def self.with_menu(scene, kind)
      previous = @menu
      window = PokeAccess.ivar(scene, kind == :command ? :@commandWindow : :@fightWindow)
      @menu = { :window => window, :kind => kind, :opening => true }
      PokeAccess::Cursor.reset(window, :fight_move) if window && kind == :fight
      yield
    ensure
      @menu = previous
      unless previous
        PokeAccess::Info.clear_text
        PokeAccess::Info.set_info(:battle_foe, nil)
      end
    end

    # True while the window is the one the running menu of that kind reads.
    def self.active?(window, kind)
      @menu && @menu[:kind] == kind && @menu[:window].equal?(window)
    end

    # Runs the window's refresh, keeping the labels it outlines (or, with none, the ones it paints) for its rows.
    def self.paint_commands(window)
      previous = @outline_labels
      @outline_labels = []
      result = nil
      pairs = PokeAccess::PaintCapture.sample { result = yield }
      labels = @outline_labels.empty? ? pairs.map { |pair| PokeAccess.clean(pair[0].to_s) } : @outline_labels
      window.instance_variable_set(:@access_xeno_commands, labels)
      PokeAccess::Cursor.reset(window, :xenoverse_battle_command)
      PokeAccess::Info.set_info(:battle_foe, nil) if active?(window, :command)
      result
    ensure
      @outline_labels = previous
    end

    # Keeps a label pbDrawOutlineText draws while a command window refreshes.
    def self.outline(args)
      return unless @outline_labels
      @outline_labels.push(PokeAccess.clean(args[5].to_s))
    end

    # Says the command under the cursor.
    def self.command_update(window)
      return unless active?(window, :command)
      index = PokeAccess.ivar(window, :@index)
      labels = PokeAccess.ivar(window, :@access_xeno_commands)
      return unless index.is_a?(Integer) && index >= 0 && labels.is_a?(Array) && index < labels.length
      text = labels[index]
      PokeAccess::Cursor.announce(window, :xenoverse_battle_command, [index, text], true, false) { text }
    end

    # Says the move under the cursor through core, or Back at the fifth place; the Mega button once on opening.
    def self.fight_update(window)
      return unless active?(window, :fight)
      index = PokeAccess.ivar(window, :@index)
      battler = PokeAccess.ivar(window, :@battler)
      return unless index.is_a?(Integer) && index >= 0 && battler
      if index == 4
        PokeAccess::Cursor.announce(window, :fight_move, :back, true, false) do
          text = PokeAccess::I18n.t(:bb_back)
          PokeAccess::Info.set_info(:text, text, text)
          text
        end
        return
      end
      move = (battler.moves[index] rescue nil)
      return unless index < 4 && move && PokeAccess::MoveInfo.real_id?(PokeAccess::MoveInfo.id_of(move))
      opening = @menu[:opening]
      @menu[:opening] = false
      PokeAccess::Battle.read_fight_move(window, !opening)
      PokeAccess.speak(PokeAccess::Battle.ready_text(:mega), false) if opening && mega_up?(window)
    end

    # True if the fight menu shows the Mega button and the battler can Mega Evolve.
    def self.mega_up?(window)
      return false unless PokeAccess.ivar(window, :@showMega)
      battler = PokeAccess.ivar(window, :@battler)
      battle = PokeAccess.ivar(battler, :@battle)
      return false unless battler && battle && battle.respond_to?(:pbCanMegaEvolve?)
      battle.pbCanMegaEvolve?(battler.index) ? true : false
    rescue StandardError => error
      PokeAccess.swallowed(error)
      false
    end

    # Says the Mega button's new state, from @usedMega or the button's frame.
    def self.mega_toggled(window)
      return unless active?(window, :fight) && mega_up?(window)
      on = PokeAccess.ivar(window, :@usedMega)
      unless on == true || on == false
        button = PokeAccess.ivar(window, :@megaButton)
        return unless button && !(button.disposed? rescue false)
        row = button.src_rect.y
        return unless row == 0 || row == 48
        on = row == 48
      end
      PokeAccess.speak(PokeAccess::I18n.t(on ? :bt_mega_on : :bt_mega_off), true)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("PokeBattle_Scene", :pbCommandMenuEx) do |scene, original, _args|
    PokeAccess::XenoverseBattleMenus.with_menu(scene, :command) { original.call }
  end
  around("PokeBattle_Scene", :pbFightMenu) do |scene, original, _args|
    PokeAccess::XenoverseBattleMenus.with_menu(scene, :fight) { original.call }
  end
  kernel(:pbDrawOutlineText, :before) { |args, _result| PokeAccess::XenoverseBattleMenus.outline(args) }
  around("NewCommandWindow", :refreshCommands) do |window, original, _args|
    PokeAccess::XenoverseBattleMenus.paint_commands(window) { original.call }
  end
  around("NextGenCommandWindow", :refreshCommands) do |window, original, _args|
    PokeAccess::XenoverseBattleMenus.paint_commands(window) { original.call }
  end
  after("NewCommandWindow", :update) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.command_update(window) }
  after("NextGenCommandWindow", :update) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.command_update(window) }
  after("NewFightWindow", :update) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.fight_update(window) }
  after("NextGenFightWindow", :update) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.fight_update(window) }
  after("NewFightWindow", :megaButtonTrigger) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.mega_toggled(window) }
  after("NextGenFightWindow", :megaButtonTrigger) { |window, _result, _args| PokeAccess::XenoverseBattleMenus.mega_toggled(window) }
end
