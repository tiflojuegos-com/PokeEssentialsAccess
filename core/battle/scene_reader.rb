module PokeAccess
  # Engine-agnostic reader for the modern Battle::Scene menus. The command, fight and target menus are
  # Battle::Scene::MenuBase subclasses holding the selection in @index with graphic labels, so the focused
  # option is read by introspection. The classes are shared across Essentials v19-v22 vanilla and the Sky
  # fork, so the spoken content lives here once while the v21 and v22 files own only the hooks that TRIGGER
  # it. On gen-6 there is no Battle::Scene, so nothing here is ever reached.
  module BattleScene
    # Positional command labels per menu mode, for the v19-v21 CommandMenu, which exposes neither @texts nor
    # #command and so is read by index. Modes 0-2 are regular battles (Fight/Bag/Pokemon with
    # Run/Cancel/Call as the fourth button), mode 3 is the Safari Zone (Ball/Bait/Rock/Run) and mode 4 the
    # Bug-Catching Contest (Fight/Ball/Pokemon/Run); the last two relabel the first buttons too. Values are
    # i18n keys, verified against the Battle::Scene MODES table in Essentials master.
    CMD_MODES = { 0 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_run],
                  1 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :pc_cancel],
                  2 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_call],
                  3 => [:bt_cmd_ball, :bt_cmd_bait, :bt_cmd_rock, :bt_cmd_run],
                  4 => [:bt_cmd_fight, :bt_cmd_ball, :bt_cmd_pokemon, :bt_cmd_run],
                  # 5-8 are the Deluxe Battle Kit's, appended to the engine's MODES table by its Command
                  # Menu Refactor. Without them a cheer battle or a Wonder Launcher battle falls back to
                  # mode 0 and the reader says "Mochila" and "Huir" over buttons that read "Lanzar" and
                  # "Animar". The kit swaps exactly two slots, the bag one for Launch and the run one for
                  # Cheer, keeping Fight and Pokemon where they are.
                  5 => [:bt_cmd_fight, :bt_cmd_bag, :bt_cmd_pokemon, :bt_cmd_cheer],
                  6 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_run],
                  7 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :pc_cancel],
                  8 => [:bt_cmd_fight, :bt_cmd_launch, :bt_cmd_pokemon, :bt_cmd_call] }
    # v22's command menu is symbol-based and reorderable, so the focused option is read from the symbol
    # (menu.command) rather than by position.
    CMD_SYMS = { :fight => :bt_cmd_fight, :fight2 => :bt_cmd_fight, :bag => :bt_cmd_bag,
                 :pokemon => :bt_cmd_pokemon, :run => :bt_cmd_run, :call => :bt_cmd_call,
                 :cancel => :pc_cancel, :shift => :bt_shift,
                 :throw_ball => :bt_cmd_ball, :throw_ball_contest => :bt_cmd_ball,
                 :throw_bait => :bt_cmd_bait, :throw_rock => :bt_cmd_rock }

    # Reads the focused option of a battle menu, dispatching on its kind; a no-op for kinds not
    # special-cased. What it hands the info key is the MOVE and not the line it just spoke, so that key adds
    # the category and the description through Info.move_info instead of echoing the cursor.
    # param interrupt whether this read may cut current speech (true for navigation; false on open, so it
    #   does not cut the hp/turn lines just spoken)
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
        else
          PokeAccess::Info.set_info(:text, t)
        end
        PokeAccess.speak(t, interrupt)
      end
    rescue StandardError => e
      PokeAccess.log_once("battlescene_read", e)
    end

    # The focused command name (Luchar/Mochila/Pokemon...). Prefer the menu's own button texts (@texts),
    # which the engine and battle plugins fill via setTexts -- this reads the real labels shown, including
    # extra buttons a kit like DBK adds (Dynamax/Tera/Z-Move). Falls back to the v22 command symbol
    # (menu.command), then to the v19-v21 positional labels chosen by the menu mode (so Safari and the Bug
    # Contest read Ball/Bait/Rock and Fight/Ball/Pokemon rather than the regular-battle defaults).
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

    # The focused target's name in the target menu. @texts is indexed by battler index, and an EMPTY slot is
    # the engine saying that position cannot be selected, not that it forgot the name. A spread move is the
    # case: the menu opens with the cursor on the user's own index and lights every valid target at once, so
    # filling the blank would announce the attacker as the target of its own Earthquake. The mode says which.
    def self.target_label(menu)
      texts = PokeAccess.ivar(menu, :@texts)
      idx = (menu.index rescue 0)
      t = (texts && texts[idx] && !texts[idx].to_s.empty?) ? PokeAccess.clean(texts[idx]) : nil
      return t if t
      return PokeAccess::I18n.t(:bt_target_spread) if PokeAccess.ivar(menu, :@mode) == 1
      idx ? PokeAccess::I18n.t(:bt_target_n, :n => idx + 1) : nil
    end

    # Describes a battle move: name, type, power, accuracy and pp, from the modern move object. param
    # battler the battler using it (for the in-battle type), may be nil
    def self.move_text(move, battler)
      return nil unless move
      nm = (move.name rescue nil); nm = PokeAccess::I18n.t(:info_move) if nm.nil? || nm.to_s.empty?
      tsym = (battler ? move.display_type(battler) : move.type) rescue (move.type rescue nil)
      ty = (GameData::Type.get(tsym).name rescue nil)
      pp = (move.pp rescue nil); tot = (move.total_pp rescue nil)
      PokeAccess::MoveInfo.line(nm.to_s, ty, (move.power rescue 0), (move.accuracy rescue 0), :pp => pp, :total_pp => tot)
    rescue StandardError
      (move.name rescue PokeAccess::I18n.t(:info_move))
    end

    # The ability-trigger cue: which battler's ability activated. With the ability splash on (the default)
    # this is shown only as a graphic, so a blind player would miss it; off, the effect message already
    # names the ability and the scene splash method is not called, so no double-read.
    def self.ability_text(battler)
      return nil unless battler
      nm = (battler.pbThis rescue nil); ab = (battler.abilityName rescue nil)
      return nil if ab.nil? || ab.to_s.empty?
      PokeAccess::I18n.t(:bt_ability, :name => nm, :ability => ab)
    rescue StandardError
      nil
    end

    # Spoken hp delta for a battler: the player's own pokemon read exact hp, the foe as a percentage
    # (parity with what the bars reveal). param lost true for damage, false for healing
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
