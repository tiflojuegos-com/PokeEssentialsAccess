# Essentials BES's in-battle info screen (BattleInfoScene, opened from the command menu by pbShowBattleInfo and run by
# its own loop in main): a grid of the battlers over the balls of both teams, and, with C, one battler's sheet, switched
# with the arrows. The sheet repaints every frame, so it is read from the battler as the cursor or the mode changes; the
# balls are said once as the screen opens, and the effects the sheet scrolls through five at a time are said whole.
module PokeAccess
  module BesBattleInfo
    # A BattleInfoConfig switch of the game, true where the game leaves it out.
    def self.setting(name)
      v = PokeAccess.const_at("BattleInfoConfig::#{name}")
      v.nil? ? true : (v ? true : false)
    end

    # Whether the sheet shows the battler's HP: always for the player's own, for a foe when the game allows.
    def self.shows_hp?(own)
      own || setting("MOSTRAR_PS_RIVAL")
    end

    # Whether the sheet shows the battler's ability or item, by the game's switch for that row.
    def self.shows?(own, name)
      own || setting("MOSTRAR_PS_RIVAL") || setting(name)
    end

    # The battler under the cursor and whether it is the player's, or nil before the screen has any.
    def self.focus(scene)
      all = PokeAccess.ivar(scene, :@all_battlers)
      pos = PokeAccess.ivar(scene, :@position)
      return nil unless all.is_a?(Array) && pos.is_a?(Integer) && all[pos]
      own = PokeAccess.ivar(scene, :@player_battlers)
      [all[pos], pos, all.length, own.is_a?(Array) && pos < own.length]
    end

    # The key and the line of the screen as it stands: the cursor's battler in the grid, or its sheet; the line is built
    # only when the key changes. For SceneWatcher.reader.
    def self.reading(scene)
      b, pos, total, own = focus(scene)
      return nil unless b
      details = PokeAccess.ivar(scene, :@show_details) ? true : false
      [[details, pos], lambda { details ? sheet(scene, b, own) : grid(scene, b, pos, total, own) }]
    end

    # The screen closed: says the focused option of the menu under it, whose cursor did not move, and the info key goes
    # back to the foe over the commands.
    def self.closed(scene)
      fight = PokeAccess.sprite(scene, "fightwindow")
      if fight && fight.visible
        PokeAccess::Cursor.reset(fight, :fight_move)
        return PokeAccess::Battle.read_fight_move(fight, false)
      end
      menu = PokeAccess.sprite(scene, "commandwindow")
      PokeAccess::Info.set_info(:battle_foe, nil)
      PokeAccess::Battle.read_command(menu, menu.index, false)
    end

    # The name the screen paints for a battler.
    def self.name_of(b)
      PokeAccess.clean((b.name rescue "").to_s)
    end

    # A battler in the grid: its name and side with its place, and, the first time, the balls of both teams, which the info key
    # always keeps.
    def self.grid(scene, b, pos, total, own)
      side = PokeAccess::I18n.t(own ? :bt_target_self : :bt_target_foe)
      line = PokeAccess::Verbosity.list_entry("#{name_of(b)}, #{side}", pos + 1, total)
      whole = PokeAccess.sentences([line, lineups(PokeAccess.ivar(scene, :@battle))])
      PokeAccess::Info.set_info(:text, whole, line)
      return line if PokeAccess.ivar(scene, :@access_lineups)
      scene.instance_variable_set(:@access_lineups, true)
      whole
    end

    # The balls the grid draws under both sides: each team's Pokemon healthy, with a status condition and fainted; a
    # side with no trainer draws none.
    def self.lineups(battle)
      return nil unless battle
      sides = [[0, :bt_side_yours], [1, :bt_side_foe]]
      sides = sides[0, 1] unless (battle.opponent rescue nil)
      lines = sides.map { |idx, key| lineup((battle.pbParty(idx) rescue nil), key) }.compact
      lines.empty? ? nil : lines.join(". ")
    end

    # One team as its balls show it, nil where it has none.
    def self.lineup(party, key)
      counts = [0, 0, 0]
      (party || [])[0, 6].each do |pk|
        next if pk.nil? || (pk.isEgg? rescue false)
        counts[pk.hp == 0 ? 2 : (pk.status > 0 ? 1 : 0)] += 1
      end
      words = [:dbk_lineup_ok, :dbk_lineup_status, :dbk_lineup_fainted]
      list = (0..2).select { |i| counts[i] > 0 }.map { |i| PokeAccess::I18n.t(words[i], :n => counts[i]) }
      list.empty? ? nil : PokeAccess::I18n.t(:dbk_lineup, :name => PokeAccess::I18n.t(key), :list => list.join(", "))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The battler's critical-hit stage as the sheet's last row counts it, none at 0.
    def self.crit(scene, b)
      n = scene.get_critical_stage(b).to_i
      n > 0 ? "#{PokeAccess::I18n.t(:dbk_crit)} +#{n}" : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The battle effects the sheet lists for the battler: its own, its side's and the field's.
    def self.effects(scene)
      list = scene.get_all_battle_effects
      list.is_a?(Array) ? list.map { |t| PokeAccess.clean(t.to_s) }.reject { |t| t.empty? } : []
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The battler's status condition, as battle announcements word it, or nil.
    def self.status_of(b)
      key = PokeAccess::Config.status_names[b.status] rescue nil
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The types the sheet paints: those of the Pokemon it displays (the disguise's under Illusion), else the battler's
    # own; not the ones a move may have changed in battle.
    def self.painted_types(scene, b)
      shown = scene.get_display_pokemon(b)
      one, two = shown.respond_to?(:type1) ? [shown.type1, shown.type2] : [b.type1, b.type2]
      [one, two].compact.uniq.map { |t| PokeAccess::Data.type_name(t) }.compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
      PokeAccess::Battle.shown_types(b)
    end

    # Whose ability and item the sheet's rows name: the battler's own; a copy of the screen that paints another's
    # overrides this.
    def self.held_by(_scene, b)
      b
    end

    # The ability and item rows, each only where the sheet shows it; an empty hand is the battler's, whoever's item the
    # row otherwise names.
    def self.held_parts(scene, b, own)
      who = held_by(scene, b)
      parts = []
      if shows?(own, "MOSTRAR_HABILIDAD_RIVAL")
        ab = PokeAccess::Data.ability_name(who.ability)
        parts.push([PokeAccess::I18n.t(:dbk_ability, :a => ab), :medium]) if ab && !ab.to_s.empty?
      end
      if shows?(own, "MOSTRAR_OBJETO_RIVAL")
        it = b.item == 0 ? PokeAccess::I18n.t(:sum_none) : PokeAccess::Data.item_name(who.item)
        parts.push([PokeAccess::I18n.t(:dbk_item, :i => it), :medium]) if it && !it.to_s.empty?
      end
      parts
    end

    # The sheet of one battler, as its leveled parts, said and published whole to the info key: who it is, its HP and
    # status, what changed in its stages and the effects on it; then its types, ability, item and last move; then the
    # turn and the weather.
    def self.sheet(scene, b, own)
      battle = PokeAccess.ivar(scene, :@battle)
      parts = [[PokeAccess::I18n.t(:sum_whose, :name => name_of(b), :level => b.level), :brief]]
      if shows_hp?(own)
        parts.push([PokeAccess::Battle.hp_phrase(b.hp, b.totalhp, false), :brief])
        parts.push([status_of(b), :brief])
      end
      parts.push([PokeAccess::Battle.stat_changes(b).to_s.sub(/\A[.,]\s*/, ""), :brief])
      parts.push([crit(scene, b), :brief])
      list = effects(scene)
      parts.push([PokeAccess::I18n.t(:ss2_effects, :list => list.join(", ")), :brief]) unless list.empty?
      types = painted_types(scene, b)
      parts.push([PokeAccess::I18n.t(:bt_type, :t => types.join(" ")), :medium]) unless types.empty?
      parts.concat(held_parts(scene, b, own))
      last = b.lastMoveUsed
      parts.push([PokeAccess::I18n.t(:dbk_lastmove, :m => PokeAccess::Data.move_name(last)), :medium]) if last.to_i > 0
      weather = (battle.active_weather rescue nil)
      parts.push([PokeAccess::I18n.t(:bt_weather, :w => weather), :medium]) if weather && !weather.to_s.empty?
      parts.push([PokeAccess::I18n.t(:dbk_turn, :n => battle.turncount + 1), :full]) if (battle.turncount rescue nil)
      PokeAccess::Verbosity.info_line(:bes_battler, parts, ". ")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::SceneWatcher.reader("BattleInfoScene", :main, :bes_battle_info, :optional => true) do |scene|
  PokeAccess::BesBattleInfo.reading(scene)
end

PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbShowBattleInfo, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess::BesBattleInfo.closed(scene)
end

PokeAccess::Verbosity.define_reading(:bes_battler, :vb_bes_battler, :vbh_bes_battler, :game)
