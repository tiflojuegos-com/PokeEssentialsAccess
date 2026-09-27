module PokeAccess
  # DarrylBD99's Wardrobe: the outfit list (@outfits, unknown to the generic reader, on a window whose update never
  # runs), polled. The check mark (the window's @outfit_selected) is the outfit chosen, worn only once the player
  # confirms on the way out; the one worn is the scene's @outfit_current, an index into its @outfit_all.
  module Wardrobe
    # A row: the outfit's name, "worn" for the one the player has on, else "chosen" for the one the check marks.
    # param scene the wardrobe scene, which knows the outfit worn; without it the check reads as worn
    def self.text(win, i, scene = nil)
      outfits = win.instance_variable_get(:@outfits)
      return nil unless outfits.is_a?(Array) && i >= 0 && i < outfits.length
      name = PokeAccess.clean(outfits[i].to_s)
      return nil if name.empty?
      checked = ((win.instance_variable_get(:@outfit_selected) rescue nil) == i)
      worn = scene ? worn?(scene, outfits[i]) : checked
      return "#{name}, #{PokeAccess::I18n.t(:wardrobe_worn)}" if worn
      checked ? "#{name}, #{PokeAccess::I18n.t(:wardrobe_chosen)}" : name
    rescue StandardError
      nil
    end

    # Whether the player has this outfit on: its place in the scene's @outfit_all is @outfit_current.
    def self.worn?(scene, outfit)
      all = PokeAccess.ivar(scene, :@outfit_all)
      current = PokeAccess.ivar(scene, :@outfit_current)
      all.is_a?(Array) && !current.nil? && all.index(outfit) == current
    rescue StandardError
      false
    end

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; announce(@scene) if @scene; end

    # The focused row of the scene's list, keyed on the worn slot too (confirm moves the check under a still cursor).
    def self.announce(scene)
      win = PokeAccess.sprite(scene, "outfitlist")
      return unless win
      i = (win.index rescue nil)
      return unless i.is_a?(Integer)
      t = text(win, i, scene)
      return if t.nil? || t.to_s.empty?
      worn = PokeAccess.ivar(win, :@outfit_selected)
      PokeAccess::Cursor.announce(scene, :wardrobe_row, [i, worn, t], true) { t }
    rescue StandardError
      nil
    end
  end
end

# Claims the list window at construction so the generic reader never repeats the poll's row.
PokeAccess::Hooks.after_hook("Window_Wardrobe", :initialize, :optional => true) do |win, _r, _a|
  PokeAccess.dedicate(win)
end

PokeAccess::Hooks.around_hook("WardrobeScene", :pbMain, :optional => true) do |scene, nxt, _a|
  PokeAccess::Wardrobe.watch(scene)
  begin; nxt.call; ensure; PokeAccess::Wardrobe.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::Wardrobe.poll }
