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
