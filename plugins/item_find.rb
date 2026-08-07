module PokeAccess
  # Item-received popup (Boonzeet's "Item Find" plugin, PokemonItemFind_Scene): shows the name, icon and
  # description of an item the first time it is found -- a notification, not a menu, so nothing reads it.
  #
  # Read off the two windows the popup fills, not off the item it is given. The copies compose those lines
  # differently for a machine: one appends the move to the name and swaps in the move's description, one
  # appends it after a colon and keeps the item's, and two have no machine branch at all -- so the item id
  # alone does not say what is on screen. All four fill @sprites["titlewindow"] and @sprites["descwindow"]
  # and then block in a loop that calls Input.update every frame, which is where this reads them; by the
  # time pbShow returns, its own pbEndScene has disposed the sprite hash.
  module ItemFind
    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; PokeAccess::Cursor.reset(nil, :item_find); end

    # The name and description the popup paints, once per popup.
    def self.poll
      s = @scene
      return unless s
      name = (PokeAccess.sprite(s, "titlewindow").text rescue nil)
      desc = (PokeAccess.sprite(s, "descwindow").text rescue nil)
      parts = [name, desc].reject { |x| x.nil? || x.to_s.strip.empty? }
      return if parts.empty?
      PokeAccess::Cursor.announce(nil, :item_find, parts, false) { parts.join(". ") }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PokemonItemFind_Scene", :pbShow, :optional => true) do |scene, nxt, _a|
  PokeAccess::ItemFind.watch(scene)
  begin; nxt.call; ensure; PokeAccess::ItemFind.unwatch; end
end

PokeAccess::Keys.on_frame { PokeAccess::ItemFind.poll }
