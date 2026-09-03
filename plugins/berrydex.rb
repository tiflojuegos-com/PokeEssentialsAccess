# BerryDex (the "TDW Berry Core and Dex" plugin). Two screens:
#
#   * Window_Berrydex, a Window_DrawableCommand whose entries are [berry_id, name, indexNumber] triples,
#     which is not a shape the generic reader knows.
#   * BerrydexInfo_Scene, whose drawPage(page) paints one section for @berry as sprites and positioned
#     text. The berry, the section and the first page's description are what can be spoken; growth times
#     and mutation trees stay visual.
#
# The two copies of the window agree on everything the extractor touches, so one extractor serves both. The
# DETAIL screen differs: one has four pages behind pbShowBattlePage?/pbShowMutationsPage?, the other only
# Info and Plant and neither predicate. The section list is therefore built by respond_to?, not by rescuing
# a missing method into "true".
module PokeAccess
  module BerryDex
    # The section names this copy of the plugin can show, in page order.
    def self.sections(scene)
      names = [PokeAccess::I18n.t(:bdx_page_info), PokeAccess::I18n.t(:bdx_page_plant)]
      names.push(PokeAccess::I18n.t(:bdx_page_battle)) if shows?(scene, :pbShowBattlePage?)
      names.push(PokeAccess::I18n.t(:bdx_page_mut)) if shows?(scene, :pbShowMutationsPage?)
      names
    end

    # Whether an optional page exists in this copy. A property of the install, not of the berry: the game
    # answers from PluginManager plus a Settings flag, so the page list is the same for every entry.
    def self.shows?(scene, meth)
      return false unless scene.respond_to?(meth, true)
      (scene.send(meth) ? true : false) rescue false
    end

    # The focused berry in the LIST: its dex number and name, or that it is not registered yet.
    def self.entry_text(win, i)
      cmds = win.instance_variable_get(:@commands)
      return nil unless cmds.is_a?(Array) && cmds[i]
      id = cmds[i][0]
      num = cmds[i][2].to_i
      return PokeAccess::I18n.t(:bdx_entry, :num => num, :name => cmds[i][1]) if (pbBerryRegistered?(id) rescue false)
      PokeAccess::I18n.t(:bdx_unknown, :num => num)
    rescue StandardError
      nil
    end

    # The detail screen on a page change: the berry, which section, and every row the page painted --
    # captured, so size, firmness, the flavor labels and the berrydex's OWN description (a different text
    # from the bag item's) arrive in whatever language this build ships. Composing from GameData::Item is
    # the fallback for a page that painted nothing.
    def self.page(scene, page, rows)
      berry = PokeAccess.ivar(scene, :@berry)
      return if berry.nil?
      sub = PokeAccess.ivar(scene, :@subpage)
      return unless PokeAccess::Cursor.changed?(scene, :bdx_page, [berry, page, sub])
      name = ((GameData::Item.get(berry).name rescue nil) || berry.to_s)
      section = sections(scene)[page.to_i - 1] || page
      parts = [name, PokeAccess::I18n.t(:bdx_section, :name => section)]
      body = rows.is_a?(Array) ? rows.uniq.reject { |r| r.to_s.strip == name.to_s } : []
      if body.empty? && page == 1
        d = (GameData::BerryData.try_get(berry).description rescue nil)
        d = (GameData::Item.get(berry).description rescue nil) if d.nil? || d.to_s.empty?
        body = [d].compact
      end
      flav = flavor_line(berry)
      body.push(flav) if flav && page.to_i == 1
      parts.concat(body)
      PokeAccess.speak_clean(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # The dominant flavor(s), which the page shows only as a circled icon over a printed name. The berrydex
    # data is the source (an icon has no text to capture); the flavor words come from the game's own data
    # keys, spoken as-is.
    def self.flavor_line(berry)
      fl = (GameData::BerryData.try_get(berry).flavor rescue nil)
      return nil unless fl.is_a?(Hash) && !fl.empty?
      max = fl.values.map { |v| v.to_i }.max
      return nil if max.nil? || max <= 0
      fk = { :spicy => :bdx_fl_spicy, :dry => :bdx_fl_dry, :sweet => :bdx_fl_sweet,
             :bitter => :bdx_fl_bitter, :sour => :bdx_fl_sour }
      tops = fl.select { |_k, v| v.to_i == max }.map { |k, _v| fk[k] ? PokeAccess::I18n.t(fk[k]) : k.to_s }
      PokeAccess::I18n.t(:bdx_flavor, :f => tops.join(", "), :n => max)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Berrydex") { |win, i| PokeAccess::BerryDex.entry_text(win, i) }

PokeAccess::Hooks.around_hook("BerrydexInfo_Scene", :drawPage, :optional => true) do |scene, nxt, args|
  PokeAccess::PaintCapture.arm(:bdx_page)
  begin
    nxt.call
  ensure
    PokeAccess::BerryDex.page(scene, (args[0] rescue PokeAccess.ivar(scene, :@page)),
                              PokeAccess::PaintCapture.take(:bdx_page))
  end
end
