# BerryDex (the "TDW Berry Core and Dex" plugin). Two screens:
#
#   * Window_Berrydex, a Window_DrawableCommand whose entries are [berry_id, name, indexNumber] triples.
#     The generic reader only knows flat command lists, so it skipped this one and the dex was silent.
#   * BerrydexInfo_Scene, whose drawPage(page) paints one section for @berry as sprites and positioned
#     text. The berry, the section and (on the first page) the description are what can be spoken; the
#     deeper per-page data -- growth times, mutation trees -- stays visual.
#
# The two copies share Window_Berrydex byte for byte, which is what makes one extractor right for both.
# They part ways on the DETAIL screen: one ships four pages behind pbShowBattlePage?/pbShowMutationsPage?,
# the other only Info and Plant and has neither predicate. So the section list is built from the pages the
# scene can actually show -- asking respond_to? rather than rescuing a missing method into "true", which
# would have invented two sections the second game does not have.
module PokeAccess
  module BerryDex
    # The section names this copy of the plugin can show, in page order.
    def self.sections(scene)
      names = [PokeAccess::I18n.t(:bdx_page_info), PokeAccess::I18n.t(:bdx_page_plant)]
      names.push(PokeAccess::I18n.t(:bdx_page_battle)) if shows?(scene, :pbShowBattlePage?)
      names.push(PokeAccess::I18n.t(:bdx_page_mut)) if shows?(scene, :pbShowMutationsPage?)
      names
    end

    # Whether an optional page is both offered by this copy and enabled for the focused berry.
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

    # The detail screen on a page change: the berry, which section, and its description on the first page.
    def self.page(scene, page)
      berry = PokeAccess.ivar(scene, :@berry)
      return if berry.nil?
      return unless PokeAccess::Cursor.changed?(scene, :bdx_page, [berry, page])
      data = (GameData::Item.get(berry) rescue nil)
      name = (data.name rescue berry.to_s)
      section = sections(scene)[page.to_i - 1] || page
      parts = [name, PokeAccess::I18n.t(:bdx_section, :name => section)]
      if page == 1
        desc = (data.description rescue nil)
        parts.push(desc) if desc && !desc.to_s.empty?
      end
      PokeAccess.speak_clean(parts.join(". "), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Berrydex") { |win, i| PokeAccess::BerryDex.entry_text(win, i) }

PokeAccess::Hooks.after_hook("BerrydexInfo_Scene", :drawPage, :optional => true) do |scene, _r, args|
  PokeAccess::BerryDex.page(scene, (args[0] rescue PokeAccess.ivar(scene, :@page)))
end
