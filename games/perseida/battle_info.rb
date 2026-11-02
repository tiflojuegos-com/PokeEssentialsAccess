# Perseida's battle information (M in its menus; pbShowBattleInfo, 0269_NewBattle_Besier, Bezier's, no kin of BES's
# BattleInfoScene): a grid of the battlers and, with C, the sheet of one, switched with left and right. Each panel's update
# only runs while it is the one shown, so that is where it is read. The sheet's rows of weather and effects are those it
# paints, which stop when the panel fills; a foe shows its bar alone, and no ability or item.
module PokeAccess
  module PerseidaBattleInfo
    SLOT = :perseida_binfo

    # The screen opened: its first line goes queued, whatever was said last time.
    def self.opened
      PokeAccess::Cursor.reset(self, SLOT)
    end

    # The screen closed over a menu whose cursor did not move: says that menu's focused option again.
    def self.closed(battle)
      scene = battle.scene
      fight = PokeAccess.sprite(scene, "fightwindow")
      if fight && fight.visible
        PokeAccess::Cursor.reset(fight, :fight_move)
        PokeAccess::Battle.read_fight_move(fight, false)
      else
        menu = PokeAccess.sprite(scene, "commandwindow")
        PokeAccess::Info.set_info(:battle_foe, nil)
        PokeAccess::Battle.read_command(menu, menu.index, false) if menu
      end
    end

    # Says a panel's line once per change.
    def self.announce(key, &line)
      PokeAccess::Cursor.announce(self, SLOT, key, true, false, &line)
    end

    # A Pokemon's name with the sex sign the screen draws beside it.
    def self.named(pk)
      sign = PokeAccess::Party.sign((pk.gender rescue nil))
      "#{PokeAccess.clean(pk.name.to_s)}#{sign ? " #{sign}" : ""}"
    end

    # The grid's focused battler.
    def self.grid(ui)
      selected = PokeAccess.ivar(ui, :@selected)
      indexes = PokeAccess.ivar(ui, :@indexes)
      announce([:grid, selected]) { grid_line(PokeAccess.ivar(ui, :@battle), indexes[selected], selected, indexes.length) }
    end

    # A battler in the grid: who it is and on which side, with its place; kept for the info key.
    def self.grid_line(battle, index, pos, total)
      side = PokeAccess::I18n.t(index.odd? ? :bt_target_foe : :bt_target_self)
      line = PokeAccess::Verbosity.list_entry("#{named(battle.battlers[index].pokemon)}, #{side}", pos + 1, total)
      PokeAccess::Info.set_info(:text, line)
      line
    end

    # The sheet's focused battler.
    def self.sheet(ui)
      selected = PokeAccess.ivar(ui, :@selected)
      announce([:sheet, selected]) { sheet_line(ui, PokeAccess.ivar(ui, :@battlers)[selected], ui.isMyPartner?(selected)) }
    end

    # A row the sheet paints as it repaints: [its text, its line], with the turns or layers beside the text.
    def self.note_row(ui, args)
      text = PokeAccess.clean(args[2].to_s)
      return if text.empty?
      value = args[3]
      max = args[5].to_i
      line = text
      line = max > 0 ? "#{text} #{value}/#{max}" : "#{text} #{value}" if value.is_a?(Numeric) && value > 0
      (PokeAccess.ivar(ui, :@access_rows) || []).push([text, line])
    end

    # The Pokemon a battler's sheet shows the name of: under Illusion, the disguise.
    def self.shown_of(b)
      (b.effects[PBEffects::Illusion] rescue nil) || b.pokemon
    end

    # The sheet of one battler, as its leveled parts, said and published whole to the info key: who it is, its HP and
    # status, what changed in its stages and the effects on it; then its types, ability, item, last move and the weather;
    # then whose it is and the turn.
    def self.sheet_line(ui, b, own)
      battle = PokeAccess.ivar(ui, :@battle)
      weather_text = PokeAccess.clean(ui.getWeatherText.to_s)
      weather, effects = (PokeAccess.ivar(ui, :@access_rows) || []).partition { |text, _line| text == weather_text }
      parts = [[PokeAccess::I18n.t(:sum_whose, :name => named(shown_of(b)), :level => b.level), :brief],
               [PokeAccess::Battle.hp_phrase(b.hp, b.totalhp, !own), :brief],
               [status_of(b), :brief],
               [PokeAccess::Battle.stat_changes(b).to_s.sub(/\A[.,]\s*/, ""), :brief]]
      unless effects.empty?
        parts.push([PokeAccess::I18n.t(:ss2_effects, :list => effects.map { |row| row[1] }.join(", ")), :brief])
      end
      parts.push([types_of(b), :medium])
      parts.concat(held(b)) if own
      parts.push([last_move(b), :medium])
      parts.push([PokeAccess::I18n.t(:bt_weather, :w => weather[0][1]), :medium]) unless weather.empty?
      parts.push([owner(battle, own), :full])
      parts.push([PokeAccess::I18n.t(:dbk_turn, :n => battle.turncount + 1), :full])
      PokeAccess::Verbosity.info_line(:perseida_battler, parts, ". ")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The status the sheet's icon stands for, as battle announcements word it; fainted is said by the HP.
    def self.status_of(b)
      key = PokeAccess::Config.status_names[b.status]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The type icons the sheet paints: the battler's own, the second only when it differs.
    def self.types_of(b)
      list = [b.type1, b.type2].compact.uniq.map { |t| PokeAccess::Data.type_name(t) }.compact
      list.empty? ? nil : PokeAccess::I18n.t(:bt_type, :t => list.join(" "))
    end

    # The ability and item rows of the player's own.
    def self.held(b)
      item = b.item == 0 ? PokeAccess::I18n.t(:sum_none) : PokeAccess::Data.item_name(b.item)
      [[PokeAccess::I18n.t(:dbk_ability, :a => PokeAccess::Data.ability_name(b.ability)), :medium],
       [PokeAccess::I18n.t(:dbk_item, :i => item), :medium]]
    end

    # The last move, painted only while the battler still knows it.
    def self.last_move(b)
      used = b.lastMoveUsed
      move = b.moves.find { |m| m.id == used }
      move ? PokeAccess::I18n.t(:dbk_lastmove, :m => PokeAccess.clean(move.name.to_s)) : nil
    end

    # The trainer whose name the sheet paints: the player, or a lone rival trainer.
    def self.owner(battle, own)
      return $Trainer.name if own
      (battle.opponent.name rescue nil)
    end
  end
end

PokeAccess::Verbosity.define_reading(:perseida_battler, :vb_bes_battler, :vbh_bes_battler, :game)

PokeAccess::Hooks.wrap_kernel("pbShowBattleInfo", "perseida_binfo_open", :before) { |_args, _r| PokeAccess::PerseidaBattleInfo.opened }
PokeAccess::Hooks.wrap_kernel("pbShowBattleInfo", "perseida_binfo_close", :after) do |args, _r|
  PokeAccess::PerseidaBattleInfo.closed(args[0])
end
PokeAccess::Hooks.frame_hook("BattleInfo_PokemonUI", :update) { |ui, _a| PokeAccess::PerseidaBattleInfo.grid(ui) }
PokeAccess::Hooks.frame_hook("BattleInfo_BattleUI", :update) { |ui, _a| PokeAccess::PerseidaBattleInfo.sheet(ui) }
PokeAccess::Hooks.before_hook("BattleInfo_BattleUI", :drawTexts) { |ui, _a| ui.instance_variable_set(:@access_rows, []) }
PokeAccess::Hooks.before_hook("BattleInfo_BattleUI", :drawFieldInfo) { |ui, a| PokeAccess::PerseidaBattleInfo.note_row(ui, a) }
PokeAccess::Hooks.clear_info_on("BattleInfo_BattleUI", :dispose)
