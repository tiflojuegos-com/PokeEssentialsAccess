# EVReorganizeScene redistributes a Pokemon's EVs: @selected_stat picks the stat and @current_evs / @ivs
# hold the numbers being edited, against @original_evs so the player can tell what changed. Reading them
# on every redraw covers both moving between stats and nudging a value.
#
# The dialogue history that used to live here is a third-party plugin shared with other fangames, so it
# moved to plugins/text_log and is declared in this profile's manifest.
module PokeAccess
  module AwakeningExtras
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
  after("EVReorganizeScene", :drawScreen) { |s, _r, _a| PokeAccess::AwakeningExtras.evs(s) }
end
