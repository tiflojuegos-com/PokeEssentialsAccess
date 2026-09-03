# IF2H's Pokeblock kit: the kit menu (PokeblockKit_Scene, a sprite button column with its own loop) and
# the blender's berry picker (MultiBerrySelection_Scene). The picker's list is a Window_DrawableCommand
# whose data lives in @bag/@filterlist -- none of the generic reader's list ivars -- so it needs its own
# extractor; every dialogue around it (throw-in question, blend/give-up confirms) already speaks through
# the UIHelper wrap.
module PokeAccess
  module HoennPokeblocks
    # The berry row as the list paints it: display name plus the REMAINING quantity (stock minus the
    # copies already thrown in), or the close row, both through the game's own strings. Also stashes the
    # focused berry's description and block colour for the info key -- the panel under the list shows
    # them, and the colour is what a blend is made of.
    def self.berry_row(win, i)
      if i == win.itemCount - 1
        set_focus_info(win)
        ((_INTL("CLOSE BAG") rescue "CLOSE BAG")).to_s
      else
        bag = win.instance_variable_get(:@bag)
        fl  = win.instance_variable_get(:@filterlist)
        pocket = bag.pockets[::PokeblockSettings::BERRY_POCKET_OF_BAG]
        entry = (fl && fl[i]) ? pocket[fl[i]] : nil
        return nil unless entry
        name = (win.instance_variable_get(:@adapter).getDisplayName(entry[0]) rescue nil)
        name = (::GameData::Item.get(entry[0]).name.to_s rescue entry[0].to_s) if name.nil?
        scene = win.instance_variable_get(:@scene)
        qty = entry[1].to_i
        qty -= (scene.selectedBerries.count(::GameData::Item.get(entry[0])) rescue 0)
        set_focus_info(win)
        "#{name}: #{qty}"
      end
    end

    def self.set_focus_info(win)
      it = (win.item rescue nil)
      return PokeAccess::Info.set_info(:text, nil) unless it
      d = (::GameData::Item.get(it).description.to_s rescue "")
      c = (::GameData::BerryData.get(it).block_color_name.to_s rescue "")
      t = [d, c].reject { |s| s.to_s.empty? }.join(" ")
      PokeAccess::Info.set_info(:text, t.empty? ? nil : PokeAccess.clean(t))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_MultiBerrySelection") { |win, i| PokeAccess::HoennPokeblocks.berry_row(win, i) }

# The four chosen berries exist on screen only as icons in circles, so the count is spoken as mod prose
# each time it changes. pbRefresh runs right after every throw-in (and on plain cursor moves, which the
# count key filters out).
PokeAccess::Game.define("infinitefusion_hoenn") do
  after("MultiBerrySelection_Scene", :pbRefresh) do |scene, _r, _a|
    n = (scene.selectedBerries.length rescue nil)
    if n && PokeAccess::Cursor.changed?(scene, :mbs_sel, n) && n > 0
      PokeAccess.speak(PokeAccess::I18n.t(:pbk_selected, :n => n, :tot => 4), false)
    end
  end
end

PokeAccess::SceneWatcher.reader("PokeblockKit_Scene", :pbScene, :pbk_kit) do |s|
  cmds = PokeAccess.ivar(s, :@commands)
  idx  = PokeAccess.ivar(s, :@index)
  (cmds.is_a?(Array) && idx.is_a?(Integer) && cmds[idx]) ? [idx, lambda { PokeAccess.clean(cmds[idx].to_s) }] : nil
end
