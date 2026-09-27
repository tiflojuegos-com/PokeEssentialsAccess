module PokeAccess
  # The Purify Chamber (Shadow Pokemon games), drawn as gauges with no text: the focused set's overview in the set
  # list and the focused slot of a set's ring.
  module PurifyChamber
    # Chamber set i at the PC reading's level: the set, its shadow Pokemon, purifiable and switching always, the
    # count and heart from medium, the tempo at full; the info key keeps it whole.
    # param switching whether this set is the one being moved
    def self.set_text(chamber, i, switching = false)
      return nil unless chamber
      parts = [[PokeAccess::I18n.t(:pchm_set, :n => i.to_i + 1), :brief]]
      cnt = (chamber.setCount(i) rescue nil)
      cnt = (chamber[i].length rescue nil) if cnt.nil?
      if cnt && cnt.to_i <= 0
        parts.push([PokeAccess::I18n.t(:pchm_empty), :brief])
      else
        parts.push([PokeAccess::I18n.t(:pchm_count, :n => cnt), :medium]) if cnt
        sh = (chamber.getShadow(i) rescue nil)
        nm = (sh.name rescue nil) if sh
        parts.push([PokeAccess::I18n.t(:pchm_shadow, :name => nm), :brief]) if nm && !nm.to_s.empty?
        tempo = (chamber[i].tempo rescue nil)
        maxt = (chamber.class.maximumTempo rescue nil)
        parts.push([PokeAccess::I18n.t(:pchm_tempo, :n => tempo, :max => maxt), :full]) if tempo && maxt
        hg = heart_of(sh)
        parts.push([PokeAccess::I18n.t(:pchm_heart, :n => hg, :max => heart_max), :medium]) if hg
        parts.push([PokeAccess::I18n.t(:pchm_purifiable), :brief]) if (chamber.isPurifiable?(i) rescue false)
      end
      parts.push([PokeAccess::I18n.t(:pchm_switching), :brief]) if switching
      PokeAccess::Verbosity.info_line(:pc_slot, parts)
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

    # The ring cursor at the PC reading's level: 0 is the centre's shadow Pokemon (heart from medium, flow and tempo
    # at full); slot cursor - 1 holds setList[slot / 2] on even slots and a gap on odd ones, as the view places its
    # icons (the position from medium). The info key keeps it whole.
    def self.ring_text(view)
      cur = (view.cursor rescue nil)
      return nil if cur.nil? || cur < 0
      chamber = view.instance_variable_get(:@chamber)
      set = (view.set rescue nil)
      return nil unless chamber && set
      if cur == 0
        sh = (chamber.getShadow(set) rescue nil)
        return nil unless sh
        parts = [[PokeAccess::I18n.t(:pc_slot, :name => sh.name, :level => sh.level), :brief]]
        hg = heart_of(sh)
        parts.push([PokeAccess::I18n.t(:pchm_heart, :n => hg, :max => heart_max), :medium]) if hg
        flow = (chamber.chamberFlow(set) rescue nil)
        parts.push([PokeAccess::I18n.t(:pchm_flow, :n => flow), :full]) if flow
        tempo = (chamber[set].tempo rescue nil)
        maxt = (chamber.class.maximumTempo rescue nil)
        parts.push([PokeAccess::I18n.t(:pchm_tempo, :n => tempo, :max => maxt), :full]) if tempo && maxt
        return PokeAccess::Verbosity.info_line(:pc_slot, parts)
      end
      points = [((chamber.setCount(set) rescue 0) * 2), 1].max
      slot = cur - 1
      occupant = nil
      if slot % 2 == 0 && slot < points
        list = (chamber.setList(set) rescue nil)
        occupant = (list[slot / 2] rescue nil) if list
      end
      whole = if occupant
                PokeAccess::I18n.t(:pchm_pos, :n => cur, :tot => points, :name => occupant.name)
              else
                PokeAccess::I18n.t(:pchm_pos_empty, :n => cur, :tot => points)
              end
      PokeAccess::Info.set_info(:text, whole)
      return whole if PokeAccess::Verbosity.keep?(:pc_slot, :medium)
      occupant ? occupant.name.to_s : PokeAccess::I18n.t(:pc_empty)
    rescue StandardError
      nil
    end
  end
end

# The ring (PurifyChamberSetView), a sprite with its own cursor, refreshed on open and on each move.
PokeAccess::Hooks.after_hook("PurifyChamberSetView", :refresh, :optional => true) do |view, _r, _a|
  PokeAccess::Cursor.announce(view, :pchm_ring, (view.cursor rescue nil), true) do
    PokeAccess::PurifyChamber.ring_text(view)
  end
end

# The set list (Window_PurifyChamberSets), drawn as gauges: the focused set's overview.
PokeAccess::Menus.def_extractor("Window_PurifyChamberSets") do |win, i|
  PokeAccess::PurifyChamber.set_text(win.instance_variable_get(:@chamber), i, win.instance_variable_get(:@switching) == i)
end
