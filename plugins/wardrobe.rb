module PokeAccess
  # DarrylBD99's Wardrobe: pick an outfit from a list and the player sprite changes.
  #
  # Window_Wardrobe is a Window_DrawableCommand the generic reader still cannot voice, for two reasons: its
  # option list is in @outfits, which is not one of the names that reader knows, and the screen never calls
  # the window's update -- its loop assigns index directly. Hence a per-class extractor plus a poll.
  #
  # Entries are plain strings. @outfit_selected is the one worn, which the screen marks with a check: it is
  # the only thing separating "the outfit I am on" from "the outfit I am wearing".
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

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; announce(@scene) if @scene; end

    # The focused row, read off the list window the scene keeps.
    #
    # Polled rather than hung off pbSwitchOutfit, which runs on UP and DOWN only: it gives no opening read,
    # and CONFIRM moves the worn mark without going through it. The worn slot is in the dedup key for that.
    def self.announce(scene)
      win = PokeAccess.sprite(scene, "outfitlist")
      return unless win
      i = (win.index rescue nil)
      return unless i.is_a?(Integer)
      t = text(win, i)
      return if t.nil? || t.to_s.empty?
      worn = PokeAccess.ivar(win, :@outfit_selected)
      PokeAccess::Cursor.announce(scene, :wardrobe_row, [i, worn, t], true) { t }
    rescue StandardError
      nil
    end
  end
end

# Claimed on the WINDOW's own constructor so the generic command reader never touches it: this fork's
# loop assigns index directly and never pumps the window's update, but a variant that did would voice the
# poller's row twice. The flag lives on the instance, and the scene builds a fresh window each time it
# opens, so nothing has to release it.
PokeAccess::Hooks.after_hook("Window_Wardrobe", :initialize, :optional => true) do |win, _r, _a|
  PokeAccess.dedicate(win)
end

PokeAccess::Hooks.around_hook("WardrobeScene", :pbMain, :optional => true) do |scene, nxt, _a|
  PokeAccess::Wardrobe.watch(scene)
  begin; nxt.call; ensure; PokeAccess::Wardrobe.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::Wardrobe.poll }
