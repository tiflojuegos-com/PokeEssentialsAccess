# Perseida's battle as its own scripts draw it: the fight menu's power buttons and the power its buttons paint
# (0262_Signos_Poderes_UI), the keys and the cursor of its menus (0268_NewBattle_WSED_Commands), whose title it leaves
# blank, and the strip its battlers slide in (0250_EliteBattle_AbilityMessages), a function of the top level that paints
# the ability or, for a birth sign at work, the sign.
module PokeAccess
  module PerseidaBattle
    # The keys that choose each slot of both menus at once: the X, Y, Z and F of its Input, with their names.
    MENU_KEYS = [[:x, "A"], [:y, "S"], [:z, "D"], [:text_log, "F"]]
    # The index pbCommandMenuEx leaves after throwing from the ball list: no button, and C there is the old Call command.
    NO_BUTTON = 4
    # The frame rates Alt switches between in the menus, the second with the turbo icon up.
    TURBO_OFF = 80
    TURBO_ON = 120

    # Says a change of one of the fight menu's power buttons (0 hidden, 1 shown, 2 registered): that it is available as it
    # comes up, with its key, and that it is on as it is registered. The menu sets each one to 0 as it opens, right after
    # reading the move, so the keys of the menu go there.
    def self.button(disp, slot, word, v)
      last = PokeAccess.ivar(disp, slot)
      disp.instance_variable_set(slot, v)
      fight_hint(disp) if v == 0
      name = PokeAccess::I18n.t(word)
      if PokeAccess::Battle.mega_reveal?(last, v)
        hint = PokeAccess::I18n.t(:perseida_power_key, :key => PokeAccess::KeyHints.key(:a, "Z"))
        PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:bt_special_ready, :name => name), hint), false)
      else
        key = PokeAccess::Battle.mega_key(last, v, :bt_special_on, :bt_special_off)
        PokeAccess.speak(PokeAccess::I18n.t(key, :name => name), true) if key
      end
    end

    # The fight menu's keys, once per battle: the menu lives as long as the battle.
    def self.fight_hint(disp)
      return unless PokeAccess::Verbosity.hints? && !PokeAccess.ivar(disp, :@access_hinted)
      disp.instance_variable_set(:@access_hinted, true)
      keys = MENU_KEYS.map { |sym, letter| PokeAccess::KeyHints.key(sym, letter) }.join(", ")
      PokeAccess.speak(PokeAccess::I18n.t(:perseida_fight_keys, :list => keys, :info => info_key), false)
    end

    # The key of the battle's information.
    def self.info_key
      PokeAccess::KeyHints.key(:clara_map, "M")
    end

    # A fight line's parts with the power its button paints, none below 10; said at the level the moves say theirs.
    def self.with_power(parts, move)
      power = (move.basedamage rescue 0).to_i
      return parts if power < 10
      parts[0, 3] + [[PokeAccess::I18n.t(:mv_power, :p => power), :full]] + parts[3, parts.length]
    end

    # The battler whose orders the menu asks for, in a double battle: the box that bobs says it and the title no longer.
    def self.chooser(scene, index)
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle && PokeAccess::Battle.doubles?(battle)
      b = battle.battlers[index]
      name = PokeAccess.clean((b.name rescue "").to_s)
      PokeAccess.speak(name, false) unless name.empty?
    end

    # Runs a read of the command menu's cursor (the block). As the menu opens it may be on no button, which is said,
    # and the first opening of the battle adds the keys.
    def self.command(disp, index, interrupt)
      return yield if interrupt
      if index == NO_BUTTON
        PokeAccess.speak(PokeAccess::I18n.t(:perseida_cmd_none), false, :menu)
      else
        yield
      end
      command_hint(disp)
    end

    # The command menu's keys with the labels it holds (the Safari Zone's differ), once per battle: the menu lives as long
    # as the battle.
    def self.command_hint(disp)
      return unless PokeAccess::Verbosity.hints? && !PokeAccess.ivar(disp, :@access_hinted)
      disp.instance_variable_set(:@access_hinted, true)
      labels = PokeAccess.ivar(PokeAccess::Battle.command_window(disp), :@commands) || []
      keys = (0...[labels.length, MENU_KEYS.length].min).map do |i|
        "#{PokeAccess::KeyHints.key(MENU_KEYS[i][0], MENU_KEYS[i][1])} #{PokeAccess.clean(labels[i].to_s)}"
      end
      line = PokeAccess::I18n.t(:perseida_bt_keys, :list => keys.join(", "), :info => info_key)
      if ball_shortcut?(PokeAccess::Battle.battle)
        line = "#{line} #{PokeAccess::I18n.t(:perseida_bt_ball, :key => PokeAccess::KeyHints.key(:clara_bag, "B"))}"
      end
      PokeAccess.speak(line, false)
    end

    # Whether the menu paints and honours the ball list's key: a single battle with a wild Pokemon that can be caught.
    def self.ball_shortcut?(battle)
      return false if battle.nil? || battle.opponent || battle.doublebattle || $game_switches[NO_CAPTURES_SWITCH]
      hasBalls? ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Runs a strip (the block), keeping the text it paints for hold_strip: the sign in place of the ability, or the
    # ability itself.
    def self.strip(args)
      @strip_rows = []
      yield
    ensure
      rows = @strip_rows || []
      @strip_rows = nil
      PokeAccess::BattleScene.hold_strip(args[0], args[2] ? rows[0] : nil)
    end

    # A string pbDrawOutlineText paints, kept while a strip runs.
    def self.strip_text(text)
      @strip_rows.push(text) if @strip_rows
    end

    # Says Alt's turbo switching in the menus, as its icon comes and goes; other changes of rate are the game's own, as
    # the battle starts and ends.
    def self.poll_turbo
      return @rate = nil unless PokeAccess::Battle.in_battle?
      now = Graphics.frame_rate
      was = @rate
      @rate = now
      if was == TURBO_OFF && now == TURBO_ON
        PokeAccess.speak(PokeAccess::I18n.t(:turbo_on), true)
      elsif was == TURBO_ON && now == TURBO_OFF
        PokeAccess.speak(PokeAccess::I18n.t(:turbo_off), true)
      end
    end
  end
end

PokeAccess::Hooks.after_hook("FightMenuDisplay", :cometryButton=) do |disp, _r, args|
  PokeAccess::PerseidaBattle.button(disp, :@access_cometry, :perseida_cometry, args[0])
end
PokeAccess::Hooks.after_hook("FightMenuDisplay", :zodiacButton=) do |disp, _r, args|
  PokeAccess::PerseidaBattle.button(disp, :@access_zodiac, :perseida_star_power, args[0])
end

PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbCommandMenu) do |scene, args|
  PokeAccess::PerseidaBattle.chooser(scene, args[0])
end

PokeAccess::Hooks.wrap_kernel("showAbilityMessage", "perseida_strip", :around) do |args, call_next|
  PokeAccess::PerseidaBattle.strip(args) { call_next.call }
end
PokeAccess::Hooks.wrap_kernel("pbDrawOutlineText", "perseida_strip_text", :before) do |args, _r|
  PokeAccess::PerseidaBattle.strip_text(args[5])
end

PokeAccess::Frame.each_pulse { PokeAccess::PerseidaBattle.poll_turbo }

PokeAccess::Game.define("perseida") do
  override("PokeAccess::Battle", :fight_line) do |_mod, original, args|
    PokeAccess::PerseidaBattle.with_power(original.call, args[1])
  end
  override("PokeAccess::Battle", :read_command) do |_mod, original, args|
    PokeAccess::PerseidaBattle.command(args[0], args[1], args[2]) { original.call }
  end
end
