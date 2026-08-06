module PokeAccess
  # DarrylBD99's Wardrobe: pick an outfit from a list and the player sprite changes.
  #
  # Window_Wardrobe IS a Window_DrawableCommand, but the generic reader could never voice a move here. Two
  # separate reasons, and both had to be fixed. It looks for the option list under the handful of names it
  # knows (@commands, @items, @list...) and this one keeps it in @outfits -- the Window_Quest / @quests case,
  # answered the same way, with a per-class extractor so the generic net keeps working everywhere else. And
  # the generic reader hangs off the window's update, which this screen never calls: its loop only ticks
  # Graphics and Input and then assigns index directly, and the assignment repaints the cursor without going
  # through update. So the move itself is hooked, on the one method the loop calls on every step.
  #
  # The entries are plain strings. @outfit_selected is the one currently worn, which the screen shows as a
  # check mark beside the row -- the only thing on screen distinguishing "the outfit I am on" from "the
  # outfit I am wearing", and invisible to a reader that only says the name.
  module Wardrobe
    def self.text(win, i)
      outfits = win.instance_variable_get(:@outfits)
      return nil unless outfits.is_a?(Array) && i >= 0 && i < outfits.length
      name = PokeAccess.clean(outfits[i].to_s).to_s.strip
      return nil if name.empty?
      worn = (win.instance_variable_get(:@outfit_selected) rescue nil)
      (worn == i) ? "#{name}, #{PokeAccess::I18n.t(:wardrobe_worn)}" : name
    rescue StandardError
      nil
    end

    # The focused row, read off the list window the scene keeps. Both the opening read and every move come
    # through here, because the scene calls pbSwitchOutfit once while setting up and once per step.
    def self.announce(scene)
      win = PokeAccess.sprite(scene, "outfitlist")
      return unless win
      i = (win.index rescue nil)
      return unless i.is_a?(Integer)
      t = text(win, i)
      return if t.nil? || t.to_s.empty?
      PokeAccess::Cursor.announce(scene, :wardrobe_row, [i, t], true) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_Wardrobe") { |win, i| PokeAccess::Wardrobe.text(win, i) }

PokeAccess::Hooks.after_hook("WardrobeScene", :pbSwitchOutfit, :optional => true) do |scene, _r, _a|
  PokeAccess::Wardrobe.announce(scene)
end
