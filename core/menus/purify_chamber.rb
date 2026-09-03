module PokeAccess
  # The Purify Chamber (Shadow-Pokemon / Orre-style games) shows its 9 sets as gauge bars with no text.
  # The set list is a Window_PurifyChamberSets (a Window_DrawableCommand), so the focused set is read as
  # the cursor moves. First pass: the set overview (count, shadow Pokemon, tempo, purifiable); per-position
  # detail comes later, after live testing.
  module PurifyChamber
    # The spoken description of chamber set i: count, the shadow Pokemon if any, tempo vs the maximum,
    # and whether it can be purified now.
    def self.set_text(chamber, i)
      return nil unless chamber
      parts = [PokeAccess::I18n.t(:pchm_set, :n => i.to_i + 1)]
      cnt = (chamber.setCount(i) rescue nil)
      cnt = (chamber[i].length rescue nil) if cnt.nil?
      if cnt && cnt.to_i <= 0
        parts.push(PokeAccess::I18n.t(:pchm_empty))
        return parts.join(", ")
      end
      parts.push(PokeAccess::I18n.t(:pchm_count, :n => cnt)) if cnt
      sh = (chamber.getShadow(i) rescue nil)
      nm = (sh.name rescue nil) if sh
      parts.push(PokeAccess::I18n.t(:pchm_shadow, :name => nm)) if nm && !nm.to_s.empty?
      tempo = (chamber[i].tempo rescue nil)
      maxt = (chamber.class.maximumTempo rescue nil)
      parts.push(PokeAccess::I18n.t(:pchm_tempo, :n => tempo, :max => maxt)) if tempo && maxt
      hg = heart_of(sh)
      parts.push(PokeAccess::I18n.t(:pchm_heart, :n => hg, :max => heart_max)) if hg
      parts.push(PokeAccess::I18n.t(:pchm_purifiable)) if (chamber.isPurifiable?(i) rescue false)
      parts.join(", ")
    rescue StandardError
      nil
    end

    # The heart gauge of a shadow Pokemon, engine-agnostic (heartgauge in gen-6, heart_gauge in v21+).
    def self.heart_of(pk)
      return nil unless pk
      PokeAccess.attr_of(pk, :heartgauge, :heart_gauge)
    rescue StandardError
      nil
    end

    # The full heart-gauge size, wherever this engine keeps the constant.
    def self.heart_max
      return PokeBattle_Pokemon::HEARTGAUGESIZE if defined?(PokeBattle_Pokemon::HEARTGAUGESIZE)
      return Pokemon::HEART_GAUGE_SIZE if defined?(Pokemon::HEART_GAUGE_SIZE)
      nil
    rescue StandardError
      nil
    end

    # The spoken line for the set view's ring cursor. Position 0 is the shadow Pokemon in the centre;
    # ring slot i (cursor - 1) holds setList[i / 2] on even slots and a gap on odd ones -- the same
    # arithmetic the view's own refresh uses to place its icon sprites.
    def self.ring_text(view)
      cur = (view.cursor rescue nil)
      return nil if cur.nil? || cur < 0
      chamber = view.instance_variable_get(:@chamber)
      set = (view.set rescue nil)
      return nil unless chamber && set
      if cur == 0
        sh = (chamber.getShadow(set) rescue nil)
        return nil unless sh
        parts = [PokeAccess::I18n.t(:pc_slot, :name => sh.name, :level => sh.level)]
        hg = heart_of(sh)
        parts.push(PokeAccess::I18n.t(:pchm_heart, :n => hg, :max => heart_max)) if hg
        flow = (chamber.chamberFlow(set) rescue nil)
        parts.push(PokeAccess::I18n.t(:pchm_flow, :n => flow)) if flow
        tempo = (chamber[set].tempo rescue nil)
        maxt = (chamber.class.maximumTempo rescue nil)
        parts.push(PokeAccess::I18n.t(:pchm_tempo, :n => tempo, :max => maxt)) if tempo && maxt
        return parts.join(", ")
      end
      points = [((chamber.setCount(set) rescue 0) * 2), 1].max
      slot = cur - 1
      occupant = nil
      if slot % 2 == 0 && slot < points
        list = (chamber.setList(set) rescue nil)
        occupant = (list[slot / 2] rescue nil) if list
      end
      if occupant
        PokeAccess::I18n.t(:pchm_pos, :n => cur, :tot => points, :name => occupant.name)
      else
        PokeAccess::I18n.t(:pchm_pos_empty, :n => cur, :tot => points)
      end
    rescue StandardError
      nil
    end
  end
end

# The ring detail (PurifyChamberSetView): a SpriteWrapper with its own cursor, out of reach of both
# generic window hooks -- the screen where Pokemon are actually PLACED. refresh runs once on open and
# once per cursor move, and the cursor is the dedup key.
PokeAccess::Hooks.after_hook("PurifyChamberSetView", :refresh, :optional => true) do |view, _r, _a|
  PokeAccess::Cursor.announce(view, :pchm_ring, (view.cursor rescue nil), true) do
    PokeAccess::PurifyChamber.ring_text(view)
  end
end

# The set sidebar (Window_PurifyChamberSets, a Window_DrawableCommand): the generic reader sees no text
# (sets are drawn as gauges), so read the focused set's overview as the cursor moves. No-op in games
# without a Purify Chamber.
PokeAccess::Menus.def_extractor("Window_PurifyChamberSets") do |win, i|
  t = PokeAccess::PurifyChamber.set_text(win.instance_variable_get(:@chamber), i)
  sw = win.instance_variable_get(:@switching)
  (sw == i && t) ? "#{t}, #{PokeAccess::I18n.t(:pchm_switching)}" : t
end
