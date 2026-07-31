# Two more Awakening screens that keep everything in their own bitmaps.
#
# Log is the dialogue history (key G on the map). It scrolls through $PokemonGlobal.log with @pos pointing at
# the entry at the bottom of the page; each entry is itself an array of lines, which is why it is joined
# before speaking.
#
# EVReorganizeScene redistributes a Pokemon's EVs: @selected_stat picks the stat and @current_evs / @ivs hold
# the numbers being edited, against @original_evs so the player can tell what changed. Reading them on every
# redraw covers both moving between stats and nudging a value.
module PokeAccess
  module AwakeningExtras
    # Voices the focused history entry once per scroll.
    def self.log(scene)
      pos = PokeAccess.ivar(scene, :@pos)
      list = ($PokemonGlobal.log rescue nil)
      return unless pos.is_a?(Integer) && list.is_a?(Array) && pos >= 0 && pos < list.length
      entry = list[pos]
      text = entry.is_a?(Array) ? entry.join(" ") : entry.to_s
      text = PokeAccess.clean(text).to_s.strip
      return if text.empty?
      PokeAccess::Cursor.announce(scene, :awk_log, pos, true) { text }
    rescue StandardError
      nil
    end

    # Voices the focused stat of the EV editor with its current value, its IV and how many points are spent.
    def self.evs(scene)
      idx = PokeAccess.ivar(scene, :@selected_stat)
      cur = PokeAccess.ivar(scene, :@current_evs)
      return unless idx.is_a?(Integer) && cur.is_a?(Array) && idx >= 0 && idx < cur.length
      ivs = PokeAccess.ivar(scene, :@ivs)
      # Six stats here, so the name comes from the engine's own stat table rather than a hand-written list
      # (which would silently mislabel everything if the order were off by one).
      name = (PokeAccess::Data.stat_name(idx) rescue nil)
      name = idx.to_s if name.nil? || name.to_s.empty?
      PokeAccess::Cursor.announce(scene, :awk_evs, [idx, cur[idx]], true) do
        iv = (ivs.is_a?(Array) ? ivs[idx] : nil)
        if iv
          PokeAccess::I18n.t(:awk_ev_iv, :name => name, :ev => cur[idx].to_i, :iv => iv.to_i)
        else
          PokeAccess::I18n.t(:awk_ev, :name => name, :ev => cur[idx].to_i)
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("Log", :update) { |s, _r, _a| PokeAccess::AwakeningExtras.log(s) }
  after("EVReorganizeScene", :drawScreen) { |s, _r, _a| PokeAccess::AwakeningExtras.evs(s) }
end
