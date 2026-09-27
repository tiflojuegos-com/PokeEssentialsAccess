module PokeAccess
  # Spoken content for the modern Battle::Scene menus (command, fight, target), shared by v19-v22; the v21 and v22
  # files own the hooks that call it.
  module BattleScene
    # Menu mode => the i18n keys of its four command labels, by position, for the v19-v21 CommandMenu (no @texts or
    # #command): 0-2 regular battles, 3 the Safari Zone, 4 the Bug Contest, 5-8 the Deluxe Battle Kit's.
    CMD_MODES = { 0 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_run],
                  1 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :pc_cancel],
                  2 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_call],
                  3 => [:bt_cmd_ball, :bt_cmd_bait, :bt_cmd_rock, :bt_cmd_run],
                  4 => [:bt_cmd_fight, :bt_cmd_ball, :bt_cmd_pokemon, :bt_cmd_run],
                  5 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_cheer],
                  6 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_run],
                  7 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :pc_cancel],
                  8 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_call] }
    # v22 command symbol (menu.command) => i18n key; that menu is reorderable, so it is read by symbol.
    CMD_SYMS = { :fight => :bt_cmd_fight, :fight2 => :bt_cmd_fight, :bag => :bt_cmd_bag,
                 :pokemon => :bt_cmd_pokemon, :run => :bt_cmd_run, :call => :bt_cmd_call,
                 :cancel => :pc_cancel, :shift => :bt_shift,
                 :throw_ball => :bt_cmd_ball, :throw_ball_contest => :bt_cmd_ball,
                 :throw_bait => :bt_cmd_bait, :throw_rock => :bt_cmd_rock }

    # Reads the focused option of a command, fight or target menu, and hands the info key the foe, move or text.
    # param interrupt false on open, so the read does not cut the hp and turn lines
    def self.read_menu(menu, interrupt = true)
      t = nil; foe = false; move = nil
      if defined?(::Battle::Scene::CommandMenu) && menu.is_a?(::Battle::Scene::CommandMenu)
        t = command_label(menu); foe = true
      elsif defined?(::Battle::Scene::FightMenu) && menu.is_a?(::Battle::Scene::FightMenu)
        move = fight_move(menu)
        t = move_text(move, (menu.battler rescue nil)) if move
      elsif defined?(::Battle::Scene::TargetMenu) && menu.is_a?(::Battle::Scene::TargetMenu)
        t = target_label(menu)
      end
      if t && !t.to_s.empty?
        if foe
          PokeAccess::Info.set_info(:battle_foe, nil)
        elsif move
          PokeAccess::Info.set_info(:move, move)
          @fight_line = [(menu.battler.index rescue nil), (menu.index rescue nil), t.split(". ")]
        else
          PokeAccess::Info.set_info(:text, t)
        end
        PokeAccess.speak(t, interrupt, :menu)
      end
    rescue StandardError => e
      PokeAccess.log_once("battlescene_read", e)
    end

    # The focused command's label: the menu's own @texts (as setTexts filled them, plugin buttons included), else the
    # v22 command symbol, else the v19-v21 label for the menu mode.
    def self.command_label(menu)
      idx = (menu.index rescue 0)
      texts = PokeAccess.ivar(menu, :@texts)
      return PokeAccess.clean(texts[idx]) if texts.is_a?(Array) && idx && texts[idx] && !texts[idx].to_s.empty?
      sym = (menu.command rescue nil)
      return PokeAccess::I18n.t(CMD_SYMS[sym] || sym.to_s) if sym.is_a?(Symbol)
      mode = (menu.mode rescue 0)
      labels = CMD_MODES[mode] || CMD_MODES[0]
      PokeAccess::I18n.t((idx && labels[idx]) || :bt_cmd_run)
    end

    # The move object under the fight cursor.
    def self.fight_move(menu)
      b = (menu.battler rescue nil)
      return nil unless b
      idx = (menu.index rescue 0)
      (b.moves[idx] rescue nil)
    end

    # The phrases of a move panel's line (parts) not yet heard for the move in slot idx of battler: the fight line
    # counts as heard, a repaint says only what changed, and the first line since panel_shut says everything.
    def self.unheard(battler, idx, parts)
      opening = @panel_shut != false
      @panel_shut = false
      key = [(battler.index rescue nil), idx]
      f = @fight_line
      line = (f && f[0, 2] == key) ? f : nil
      h = @heard
      if opening || h.nil? || h[1] != key || !h[0].equal?(line)
        h = @heard = [line, key, (opening || line.nil?) ? [] : line[2].dup]
      end
      fresh = parts.reject { |p| h[2].include?(p) }
      h[2].concat(fresh)
      fresh
    end

    # The move panel went away, hidden or repainted while off: its next line opens it again.
    def self.panel_shut; @panel_shut = true; end

    # The focused target's name from @texts (by battler index); an empty slot cannot be selected, so it reads as a
    # spread move in mode 1, else as a numbered position.
    def self.target_label(menu)
      texts = PokeAccess.ivar(menu, :@texts)
      idx = (menu.index rescue 0)
      t = (texts && texts[idx] && !texts[idx].to_s.empty?) ? PokeAccess.clean(texts[idx]) : nil
      return t if t
      return PokeAccess::I18n.t(:bt_target_spread) if PokeAccess.ivar(menu, :@mode) == 1
      idx ? PokeAccess::I18n.t(:bt_target_n, :n => idx + 1) : nil
    end

    # The category the fight menu shows for this user: target_category, else display_category, else its own. A fork
    # whose menu draws the icon from display_category alone overrides this in its profile.
    def self.fight_category(move, battler)
      c = battler ? PokeAccess::MoveInfo.target_category(move, battler) : nil
      c = (move.display_category(battler) rescue nil) if battler && !c.is_a?(Integer)
      c.is_a?(Integer) ? c : PokeAccess::MoveInfo.category_of(move)
    end

    # Describes a battle move at the battle_move level: name, type, category, power (power from v21, baseDamage
    # before; none if neither), accuracy and pp. battler (may be nil) gives the in-battle type.
    def self.move_text(move, battler)
      return nil unless move
      nm = (move.name rescue nil); nm = PokeAccess::I18n.t(:info_move) if nm.nil? || nm.to_s.empty?
      tsym = (battler ? move.display_type(battler) : move.type) rescue (move.type rescue nil)
      ty = (GameData::Type.get(tsym).name rescue nil)
      pp = (move.pp rescue nil); tot = (move.total_pp rescue nil)
      cat = PokeAccess::MoveInfo.category_word(fight_category(move, battler))
      PokeAccess::MoveInfo.leveled(:battle_move, nm.to_s, ty, PokeAccess.attr_of(move, :power, :baseDamage),
                                   (move.accuracy rescue 0), :cat => cat, :pp => pp, :total_pp => tot)
    rescue StandardError
      (move.name rescue PokeAccess::I18n.t(:info_move))
    end

    # The text a v18/v19 ability splash is about to show, or nil for the battler's own ability: a String passed in
    # (Fire Ash, Infinite Fusion), else the name the bar kept, else the fusion's second ability when asked for it.
    def self.splash_ability(scene, args)
      return args[1] if args[1].is_a?(String)
      return args[2] if args[2].is_a?(String)
      battler = args[0]
      second = args[1] == true
      side = (battler.index rescue 0).to_i % 2
      bar = PokeAccess.sprite(scene, second ? "ability2Bar_#{side}" : "abilityBar_#{side}")
      kept = bar ? PokeAccess.ivar(bar, :@ability_name) : nil
      return kept if kept.is_a?(String) && !kept.empty?
      second ? (battler.ability2Name rescue nil) : nil
    rescue StandardError
      nil
    end

    # The ability splash line: the battler and its ability, or shown when the splash shows a String instead.
    def self.ability_text(battler, shown = nil)
      return nil unless battler
      nm = (battler.pbThis rescue nil)
      ab = shown.is_a?(String) ? shown : (battler.abilityName rescue nil)
      return nil if ab.nil? || ab.to_s.empty?
      PokeAccess::I18n.t(:bt_ability, :name => nm, :ability => ab)
    rescue StandardError
      nil
    end

    # Spoken hp change for a battler (lost for damage): exact hp for the player's own, a percentage for a foe.
    def self.hp_change_text(battler, amt, lost)
      return nil unless battler && amt && amt.to_i > 0
      foe = (battler.opposes? rescue false)
      verb = PokeAccess::I18n.t(lost ? :bt_lose : :bt_gain)
      rest = PokeAccess::Battle.hp_phrase(battler.hp, battler.totalhp, foe)
      PokeAccess::I18n.t(:bt_hp_change, :name => battler.name, :verb => verb, :n => amt.to_i, :rest => rest)
    rescue StandardError
      nil
    end
  end
end
