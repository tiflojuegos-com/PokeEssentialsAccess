# EVReorganizeScene redistributes a Pokemon's EVs: @selected_stat picks the stat and @current_evs / @ivs
# hold the numbers being edited, against @original_evs so the player can tell what changed. Reading them
# on every redraw covers both moving between stats and nudging a value.
#
# The dialogue history that used to live here is a third-party plugin shared with other fangames, so it
# moved to plugins/text_log and is declared in this profile's manifest.
module PokeAccess
  module AwakeningExtras
    # @selected_stat is the ROW the cursor is on (0..6, cycled % 7), NOT a stat index: the scene lists the
    # stats in its own display order and resolves the row through STAT_ORDER = [0, 1, 2, 4, 5, 3] before
    # touching @current_evs, @ivs or the stat name. The first three rows happen to map to themselves, so the
    # top of the screen read correctly and hid the rest: rows 4, 5 and 6 were announced with the name AND the
    # numbers of a different stat, and arrows moved a value the player had not been told they were on. The
    # order is read from the scene's own constant rather than copied here, so a fangame patch that reorders
    # the rows cannot leave this quietly mislabelling again.
    # The stat name comes from the engine's own table rather than a hand-written list: six stats in a fixed
    # order is exactly the shape that mislabels everything, silently, if the list is off by one.
    def self.evs(scene)
      row = PokeAccess.ivar(scene, :@selected_stat)
      cur = PokeAccess.ivar(scene, :@current_evs)
      return unless row.is_a?(Integer) && cur.is_a?(Array) && row >= 0
      return confirm(scene, row) if row >= cur.length
      order = PokeAccess.const_at("EVReorganizeScene::STAT_ORDER")
      stat = (order.is_a?(Array) ? order[row] : nil) || row
      return unless stat >= 0 && stat < cur.length
      ivs = PokeAccess.ivar(scene, :@ivs)
      name = (PokeAccess::Data.stat_name(stat) rescue nil)
      name = stat.to_s if name.nil? || name.to_s.empty?
      PokeAccess::Cursor.announce(scene, :awk_evs, [row, cur[stat]], true) do
        iv = (ivs.is_a?(Array) ? ivs[stat] : nil)
        if iv
          PokeAccess::I18n.t(:awk_ev_iv, :name => name, :ev => cur[stat].to_i, :iv => iv.to_i)
        else
          PokeAccess::I18n.t(:awk_ev, :name => name, :ev => cur[stat].to_i)
        end
      end
    rescue StandardError
      nil
    end

    # The row past the six stats is the Confirm button. It has no entry in @current_evs, so the bounds check
    # dropped it and the one row a player must land on to save their changes was the one row that said
    # nothing. Mirrors the label the scene paints there.
    def self.confirm(scene, row)
      PokeAccess::Cursor.announce(scene, :awk_evs, [row], true) { "Confirmar" }
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("EVReorganizeScene", :drawScreen) { |s, _r, _a| PokeAccess::AwakeningExtras.evs(s) }
end
