# Vitro's copy of Clara's EV Redistributor (EVReorganizeScene, 0326_EV Redistributor, map 125), edited from Awakening's: it paints the
# stat names itself, tints the shadow of the one the nature raises and of the one it lowers by the nature's own numbering, on the
# right stat, and only outside a shadow's locked heart stages; so it has its own reader. drawScreen runs every frame.
module PokeAccess
  module VitroEv
    @scene = nil

    # A stat's value as the row paints it, in PBStats' order.
    def self.stat_value(pk, stat)
      [pk.totalhp, pk.attack, pk.defense, pk.speed, pk.spatk, pk.spdef][stat].to_i
    end

    # A stat's spoken name, or its number where the data has none.
    def self.stat_label(stat)
      name = PokeAccess::Data.stat_name(stat)
      name.nil? || name.to_s.empty? ? stat.to_s : name.to_s
    end

    # The key of what the tint on a stat's name tells: the nature numbers Attack to Sp. Def from 0, and HP has none.
    def self.tint(pk, stat)
      return nil if stat == 0 || (pk.isShadow? && pk.heartStage <= 3)
      up = pk.nature / 5
      down = pk.nature % 5
      return nil if up == down
      return :vitro_ev_nat_up if stat - 1 == up
      stat - 1 == down ? :vitro_ev_nat_down : nil
    end

    # A stat's row as painted: its name, value, EV and IV, the tint and the mark on the two highest base stats.
    def self.stat_row(scene, pk, stat, cur)
      ivs = PokeAccess.ivar(scene, :@ivs)
      parts = [PokeAccess::I18n.t(:awk_ev_row, :name => stat_label(stat), :value => stat_value(pk, stat), :ev => cur[stat].to_i,
                                               :iv => ivs[stat].to_i)]
      key = tint(pk, stat)
      parts.push(PokeAccess::I18n.t(key)) if key
      parts.push(PokeAccess::I18n.t(:awk_ev_recommended)) if scene.getTopTwoStats.include?(stat)
      parts.join(", ")
    end

    # The EVs left and the cost, with the warning of its red, as painted beside the rows.
    def self.pool(scene, cur)
      total = cur.inject(0) { |sum, ev| sum + ev.to_i }
      left = PokeAccess.ivar_i(scene, :@max_evs) - total
      cost = scene.calculateCost
      money = PokeAccess::I18n.t(:awk_ev_cost, :n => cost)
      money = "#{money}, #{PokeAccess::I18n.t(:awk_ev_short)}" if cost > $Trainer.money
      PokeAccess.sentences([PokeAccess::I18n.t(:awk_ev_totals, :n => total, :max => PokeAccess.ivar_i(scene, :@max_evs)),
                            PokeAccess::I18n.t(:awk_ev_left, :n => left), money])
    end

    # What the panel's status icon shows: fainted over a status, a status over active Pokerus.
    def self.status_icon(pk)
      return PokeAccess::I18n.t(:pk_fainted) if pk.hp == 0
      return PokeAccess::Party.status_word(pk.status) if pk.status > 0
      PokeAccess::Party.pokerus?(pk) ? PokeAccess::I18n.t(:pk_pokerus) : nil
    end

    # The panel beside the rows, as drawPokeData paints it.
    def self.head(pk)
      item = pk.hasItem? ? PBItems.getName(pk.item) : _INTL("Ninguno")
      shiny = PokeAccess::Party.shiny?(pk) ? PokeAccess::I18n.t(:pk_shiny) : nil
      cured = PokeAccess::Summary.pokerus_cured?(pk) ? PokeAccess::I18n.t(:pk_pokerus_cured) : nil
      shadow = (pk.isShadow? rescue false) ? PokeAccess::I18n.t(:perseida_mark_shadow) : nil
      PokeAccess.sentences([_INTL("DATOS"), PokeAccess.clean(pk.name.to_s), _INTL("Nv. {1}", pk.level.to_s), status_icon(pk), cured,
                            shiny, shadow, "#{_INTL('Objeto')}: #{item}"])
    end

    # The focused row, or the Confirm button past the six, when it or its EV changed: a change on the same row says the new
    # count, what is left and the cost; the info key keeps it all.
    def self.evs(scene)
      row = PokeAccess.ivar(scene, :@selected_stat)
      cur = PokeAccess.ivar(scene, :@current_evs)
      pk = PokeAccess.ivar(scene, :@pokemon)
      return unless row.is_a?(Integer) && cur.is_a?(Array) && pk
      return confirm(scene, row, cur, pk) if row >= ::EVReorganizeScene::STAT_ORDER.length
      stat = ::EVReorganizeScene::STAT_ORDER[row]
      prev = PokeAccess::Cursor.current(scene, :vitro_ev)
      PokeAccess::Cursor.announce(scene, :vitro_ev, [row, cur[stat]], true, false) do
        whole = stat_row(scene, pk, stat, cur)
        rest = pool(scene, cur)
        PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, rest, head(pk)]), whole)
        if prev.is_a?(Array) && prev[0] == row
          change = PokeAccess::I18n.t(:awk_ev_change, :ev => cur[stat].to_i, :name => stat_label(stat),
                                                      :value => stat_value(pk, stat))
          PokeAccess.sentences([change, rest])
        else
          whole
        end
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    def self.confirm(scene, row, cur, pk)
      PokeAccess::Cursor.announce(scene, :vitro_ev, [row], true, false) do
        text = PokeAccess.sentences([_INTL("Confirmar"), pool(scene, cur)])
        PokeAccess::Info.set_info(:text, PokeAccess.sentences([text, head(pk)]), text)
        text
      end
    end

    # Runs the screen's loop held, for a return from its questions, which count from this loop: a fade holds the whole screen.
    def self.running(scene)
      @scene = scene
      PokeAccess::MenuReturn.reset_nesting
      yield
    ensure
      @scene = nil
    end

    # Back from a question: the row is said again.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :vitro_ev) if @scene
    end
  end
end

PokeAccess::Game.define("vitro") do
  before("EVReorganizeScene", :pbStartScene, :optional => true) do |scene, _a|
    PokeAccess.speak(PokeAccess::VitroEv.head(PokeAccess.ivar(scene, :@pokemon)), false)
  end
  after("EVReorganizeScene", :drawScreen, :optional => true) { |scene, _r, _a| PokeAccess::VitroEv.evs(scene) }
  around("EVReorganizeScene", :pbScene, :optional => true) { |scene, nxt, _a| PokeAccess::VitroEv.running(scene) { nxt.call } }
  clear_info_on("EVReorganizeScene", :pbEndScene)
end

PokeAccess::MenuReturn.on_return { PokeAccess::VitroEv.returned }
