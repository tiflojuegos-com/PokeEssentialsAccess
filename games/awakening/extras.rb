# EVReorganizeScene, which redistributes a Pokemon's EVs, read on every redraw; and the summary's Info page.
module PokeAccess
  module AwakeningExtras
    # The focused row (@selected_stat, a stat through the scene's STAT_ORDER, or Confirm past the six) as painted;
    # a change of EV on the same row says the new count, what is left and the cost.
    def self.evs(scene)
      row = PokeAccess.ivar(scene, :@selected_stat)
      cur = PokeAccess.ivar(scene, :@current_evs)
      return unless row.is_a?(Integer) && cur.is_a?(Array) && row >= 0
      return confirm(scene, row, cur) if row >= cur.length
      order = PokeAccess.const_at("EVReorganizeScene::STAT_ORDER")
      stat = (order.is_a?(Array) ? order[row] : nil) || row
      return unless stat >= 0 && stat < cur.length
      prev = PokeAccess::Cursor.current(scene, :awk_evs)
      PokeAccess::Cursor.announce(scene, :awk_evs, [row, cur[stat]], true) do
        if prev.is_a?(Array) && prev.length == 2 && prev[0] == row
          [ev_change(scene, stat, cur), pool(scene, cur)].join(". ")
        else
          stat_row(scene, stat, cur)
        end
      end
    rescue StandardError
      nil
    end

    # A stat's row as painted: its name, value, EV and IV, the tint the nature gives its name and the mark on the
    # two highest base stats.
    def self.stat_row(scene, stat, cur)
      ivs = PokeAccess.ivar(scene, :@ivs)
      iv = (ivs.is_a?(Array) ? ivs[stat] : nil)
      vars = { :name => stat_label(stat), :value => stat_value(scene, stat), :ev => cur[stat].to_i }
      row = iv ? PokeAccess::I18n.t(:awk_ev_row, vars.merge(:iv => iv.to_i)) : PokeAccess::I18n.t(:awk_ev_row_noiv, vars)
      parts = [row]
      tint = nature_tint(scene, stat)
      parts.push(PokeAccess::I18n.t(tint)) if tint
      parts.push(PokeAccess::I18n.t(:awk_ev_recommended)) if (scene.getTopTwoStats rescue []).include?(stat)
      parts.join(", ")
    end

    # The row after an EV change: the new count and the stat's recalculated value.
    def self.ev_change(scene, stat, cur)
      PokeAccess::I18n.t(:awk_ev_change, :ev => cur[stat].to_i, :name => stat_label(stat),
                         :value => stat_value(scene, stat))
    end

    # The EVs left to place and the cost of the changes, with the warning the red cost gives when it is more money
    # than the player has.
    def self.pool(scene, cur)
      total = cur.inject(0) { |s, e| s + e.to_i }
      left = PokeAccess.ivar(scene, :@max_evs).to_i - total
      [PokeAccess::I18n.t(:awk_ev_left, :n => left), cost(scene)].join(". ")
    end

    # The painted cost, and the warning when it is more than the money held.
    def self.cost(scene)
      c = (scene.calculateCost rescue 0).to_i
      t = PokeAccess::I18n.t(:awk_ev_cost, :n => c)
      c > ($Trainer.money rescue 0).to_i ? "#{t}, #{PokeAccess::I18n.t(:awk_ev_short)}" : t
    end

    # A stat's spoken name, or its number where the data has none.
    def self.stat_label(stat)
      name = (PokeAccess::Data.stat_name(stat) rescue nil)
      (name.nil? || name.to_s.empty?) ? stat.to_s : name.to_s
    end

    # A stat's current value, as the screen recalculates it on every EV change (PBStats order: HP, Attack,
    # Defense, Speed, Special Attack, Special Defense).
    def self.stat_value(scene, stat)
      pk = PokeAccess.ivar(scene, :@pokemon)
      vals = [(pk.totalhp rescue nil), (pk.attack rescue nil), (pk.defense rescue nil), (pk.speed rescue nil),
              (pk.spatk rescue nil), (pk.spdef rescue nil)]
      vals[stat].to_i
    end

    # The key of the colour the screen tints a stat's name, said as a colour: drawScreen paints red on the index the
    # nature raises and blue on the one it lowers, in its own numbering, which can land on another stat; nil for none.
    def self.nature_tint(scene, stat)
      pk = PokeAccess.ivar(scene, :@pokemon)
      nature = (pk.nature rescue nil)
      return nil unless nature.is_a?(Integer)
      return nil if (pk.isShadow? rescue false) && (pk.heartStage rescue 0).to_i > 3
      up = nature / 5
      down = nature % 5
      return nil if up == down
      return :awk_ev_nat_up if stat == up
      stat == down ? :awk_ev_nat_down : nil
    end

    # The Confirm button, the row past the six stats (no entry in @current_evs): the totals, what is left and the
    # cost, as painted beside it.
    def self.confirm(scene, row, cur)
      PokeAccess::Cursor.announce(scene, :awk_evs, [row], true) do
        total = cur.inject(0) { |s, e| s + e.to_i }
        max = PokeAccess.ivar(scene, :@max_evs).to_i
        [PokeAccess::I18n.t(:pc_confirm), PokeAccess::I18n.t(:awk_ev_totals, :n => total, :max => max),
         pool(scene, cur)].join(". ")
      end
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("EVReorganizeScene", :drawScreen) { |s, _r, _a| PokeAccess::AwakeningExtras.evs(s) }
end

# The summary's extra Info page (drawInfo: ability and held item), captured on entry and spoken by the frame
# poll inside its blocking loop.
PokeAccess::Game.define("awakening") do
  before("PokemonSummary_Scene", :drawInfo, :optional => true) do |_s, _a|
    PokeAccess::PaintCapture.arm(:awk_suminfo)
  end
  poll_each_frame { PokeAccess::PaintCapture.flush_pending(:awk_suminfo, false) }
end
