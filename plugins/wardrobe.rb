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

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; announce(@scene) if @scene; end

    # The focused row, read off the list window the scene keeps.
    #
    # Polled from the loop rather than hung off pbSwitchOutfit. That method runs on UP and DOWN and nowhere
    # else: the constructor never calls it, so there was no opening read, and CONFIRM moves the "worn" mark
    # without going through it -- which is the one piece of state this reader exists to expose. The worn slot
    # is in the dedup key for exactly that reason.
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

PokeAccess::Menus.def_extractor("Window_Wardrobe") { |win, i| PokeAccess::Wardrobe.text(win, i) }

PokeAccess::Hooks.around_hook("WardrobeScene", :pbMain, :optional => true) do |scene, nxt, _a|
  PokeAccess::Wardrobe.watch(scene)
  begin; nxt.call; ensure; PokeAccess::Wardrobe.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::Wardrobe.poll }
