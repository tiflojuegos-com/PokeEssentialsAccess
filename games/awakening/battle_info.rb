# Awakening's in-battle stats screen (G; CheckStatsInBattle::Show, edited for BES): a picker of the battlers, then the
# sheet of one. draw_information repaints both every frame; one repaint is read when the focus or the sheet changes.
module PokeAccess
  module AwakeningBattleInfo
    # The stats whose stage icons the sheet paints, in the order of its rows; the eighth row, critical hits, comes
    # from the screen's own checkLevelCritical.
    STAGE_STATS = %w[ATTACK DEFENSE SPATK SPDEF SPEED ACCURACY EVASION]

    # Runs one repaint (the block) and, when the picker's focus or the sheet changed, speaks it.
    def self.redraw(scene)
      chose = PokeAccess.ivar(scene, :@chose) ? true : false
      pos = PokeAccess.ivar(scene, :@position)
      return yield unless PokeAccess::Cursor.changed?(scene, :awk_binfo, [chose, pos])
      pkmn = (PokeAccess.ivar(scene, :@pkmn)[pos] rescue nil)
      unless chose
        r = yield
        PokeAccess.speak(pick(pkmn, pos), true)
        return r
      end
      PokeAccess::PaintCapture.arm(:awk_binfo)
      begin
        yield
      ensure
        rows = PokeAccess::PaintCapture.take(:awk_binfo, :positions) || []
        PokeAccess.speak(sheet(scene, pkmn, pos, rows), true)
      end
    end

    # The picker's focused battler: its name, a foe's (odd places, the top row) said as the rival's.
    def self.pick(pkmn, pos)
      name = PokeAccess.clean((pkmn.name rescue "").to_s)
      return nil if name.empty?
      pos.to_i.odd? ? PokeAccess::I18n.t(:awk_binfo_foe, :name => name) : name
    end

    # The sheet: the painted name, level, hit points and turn with the status and type icons, the stat rows with
    # their stage icons, the ability, item and last move, and every active effect.
    def self.sheet(scene, pkmn, pos, rows)
      return nil if rows.empty? || pkmn.nil?
      rows = rows.map { |r| PokeAccess.clean(r.to_s) }
      k = 0
      hp = nil
      if shown?("MOSTRAR_PS_RIVAL", pos)
        hp = rows[k]
        k += 1
      end
      name, level, turn = rows[k], rows[k + 1], rows[k + 2]
      labels = rows[k + 3, 8] || []
      k += 11
      head = [name, level, hp, status_text(pkmn), types_text(pkmn), turn].compact.reject { |t| t.to_s.empty? }
      tail = []
      %w[MOSTRAR_HABILIDAD_RIVAL MOSTRAR_OBJETO_RIVAL].each do |c|
        next unless shown?(c, pos)
        tail.push(pair(rows[k], rows[k + 1]))
        k += 2
      end
      tail.push(pair(rows[k], rows[k + 1]))
      tail.push(effects_text(scene, pos, rows[k + 2]))
      [head.join(", "), stages_text(scene, pkmn, labels)].concat(tail).reject { |t| t.to_s.empty? }.join(". ")
    end

    # Whether the sheet paints a rival-optional row for this place: always on the player's side (even places), and on
    # the rival's when the game's switch for it is on.
    def self.shown?(const, pos)
      pos.to_i.even? || (PokeAccess.const_at("PokeBattle_SceneConstants::#{const}") ? true : false)
    end

    # A painted label and the value painted beside it, a dashes-only value said as none.
    def self.pair(label, value)
      v = value.to_s.strip
      v = PokeAccess::I18n.t(:awk_binfo_none) if v =~ /\A-+\z/
      "#{label.to_s.strip} #{v}".strip
    end

    # The stage icons of each stat row, as "label +n" or "label -n" for the rows that move; none moving is said so.
    def self.stages_text(scene, pkmn, labels)
      out = []
      STAGE_STATS.each_with_index do |st, i|
        id = PokeAccess.const_at("PBStats::#{st}")
        n = (id && (pkmn.stages[id] rescue 0)).to_i
        out.push("#{labels[i]} #{n > 0 ? '+' : ''}#{n}") if n != 0 && labels[i]
      end
      crit = (scene.checkLevelCritical(pkmn) rescue 0).to_i
      out.push("#{labels[7]} +#{crit}") if crit > 0 && labels[7]
      out.empty? ? PokeAccess::I18n.t(:awk_binfo_no_stages) : out.join(", ")
    end

    # The status icon beside the hit points, by its name, or nil when healthy.
    def self.status_text(pkmn)
      st = (pkmn.status rescue 0)
      return nil if st.nil? || st == 0
      key = (PokeAccess::Config.status_names[st] rescue nil)
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The type icons the sheet paints: the first type and a different second one, the disguise's under Illusion; a
    # type a move adds on top is not painted.
    def self.types_text(pkmn)
      src = (pkmn.effects[PBEffects::Illusion] rescue nil) || pkmn
      first = (src.type1 rescue nil)
      second = (src.type2 rescue nil)
      names = [first, (second == first ? nil : second)].compact.map { |t| PokeAccess::Data.type_name(t) }.compact
      names.empty? ? nil : names.join(" ")
    end

    # The painted effects heading and every effect it lists for this place: the field's, its side's and its own, as
    # store_active gathers them (the paint scrolls past nine lines; this is the whole list).
    def self.effects_text(scene, pos, heading)
      field = PokeAccess.ivar(scene, :@activef)
      sides = PokeAccess.ivar(scene, :@actives)
      own = PokeAccess.ivar(scene, :@activep)
      found = []
      found.concat(field.values) if field.is_a?(Hash)
      side = sides.is_a?(Array) ? sides[pos.to_i % 2] : nil
      found.concat(side.values) if side.is_a?(Hash)
      mine = own.is_a?(Array) ? own[pos.to_i] : nil
      found.concat(mine.values) if mine.is_a?(Hash)
      list = found.map { |e| PokeAccess.clean(e.to_s) }.reject { |e| e.empty? }
      body = list.empty? ? PokeAccess::I18n.t(:awk_binfo_none) : list.join(", ")
      "#{heading.to_s.strip} #{body}".strip
    end
  end
end

PokeAccess::Game.define("awakening") do
  around("CheckStatsInBattle::Show", :draw_information) do |s, nxt, _a|
    PokeAccess::AwakeningBattleInfo.redraw(s) { nxt.call }
  end
end
