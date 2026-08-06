# Three more Fates screens with no Essentials window behind them.
#
# EquipScreen (0309) equips cursed-energy talismans: @selected_index walks @talismans, each a hash with
# :name, :description and :lore. The description is what the player needs to choose; the lore is flavour and
# is left out so the line stays short while browsing.
#
# BallSelectorInterface (0305) is the in-battle quick ball picker (key R): a row of ball icons with a count
# under each, kept in the parallel arrays @ball_list (item ids) and @ball_counts.
#
# Glosario_Personajes (0303) is the character glossary reached from the diary. Its entries are the keys of
# @nombres_secciones, laid out two per row across pages, with @index the focus inside the current page and
# @pagina_actual / @total_paginas the paging -- so the reader gives the entry plus which page it is on.
module PokeAccess
  module AwakeningFates
    # Voices the focused talisman: its name and what it does.
    def self.talisman(scene)
      idx = PokeAccess.ivar(scene, :@selected_index)
      list = PokeAccess.ivar(scene, :@talismans)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      t = list[idx]
      return unless t.is_a?(Hash)
      PokeAccess::Cursor.announce(scene, :awk_talisman, idx, true) do
        name = PokeAccess.clean(t[:name].to_s).to_s.strip
        desc = PokeAccess.clean(t[:description].to_s).to_s.strip
        parts = [PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => list.length)]
        parts.push(desc) unless desc.empty?
        parts.join(". ")
      end
    rescue StandardError
      nil
    end

    # Voices the focused ball and how many are left.
    def self.ball(scene)
      idx = PokeAccess.ivar(scene, :@index)
      list = PokeAccess.ivar(scene, :@ball_list)
      return unless idx.is_a?(Integer) && list.is_a?(Array) && idx >= 0 && idx < list.length
      counts = PokeAccess.ivar(scene, :@ball_counts)
      PokeAccess::Cursor.announce(scene, :awk_ball, idx, true) do
        name = (PokeAccess::Data.item_name(list[idx]) || list[idx].to_s)
        n = (counts.is_a?(Array) ? counts[idx] : nil)
        n ? PokeAccess::I18n.t(:awk_ball, :name => name, :n => n.to_i) : name.to_s
      end
    rescue StandardError
      nil
    end

    # Voices the focused glossary entry and the page it sits on.
    def self.glossary(scene)
      idx = PokeAccess.ivar(scene, :@index)
      names = PokeAccess.ivar(scene, :@nombres_secciones)
      return unless idx.is_a?(Integer) && names.is_a?(Array)
      per = (Glosario_Personajes::OPCIONES_POR_PAGINA rescue 8)
      page = PokeAccess.ivar(scene, :@pagina_actual).to_i
      real = (page * per) + idx
      return unless real >= 0 && real < names.length
      PokeAccess::Cursor.announce(scene, :awk_glos, real, true) do
        name = PokeAccess.clean(names[real].to_s).to_s.strip
        total = PokeAccess.ivar(scene, :@total_paginas).to_i
        if total > 1
          PokeAccess::I18n.t(:awk_glos_page, :name => name, :page => page + 1, :pages => total)
        else
          name
        end
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("awakening") do
  after("EquipScreen", :update_description) { |s, _r, _a| PokeAccess::AwakeningFates.talisman(s) }
  after("BallSelectorInterface", :update_display) { |s, _r, _a| PokeAccess::AwakeningFates.ball(s) }
  after("Glosario_Personajes", :mover_cursor) { |s, _r, _a| PokeAccess::AwakeningFates.glossary(s) }
end
