module PokeAccess
  # Voltseon's Pause Menu (VoltseonsPauseMenu): a carousel of icons that replaces the field menu entirely, so
  # the vanilla pause-menu reader never runs. Nothing on it is a command window: the entries are objects in
  # @entries, the focused one @currentSelection, and the only visual mark of focus is the middle icon drawn
  # larger, so the reader says the entry's own name whenever the selection moves. refreshMenu is where the
  # plugin settles on a selection, once per frame after the input loop, so a held key says only where it
  # stopped.
  module VoltseonMenu
    # The name of the focused entry, or nil when the menu has nothing usable.
    def self.focused_name(menu)
      entries = PokeAccess.ivar(menu, :@entries)
      idx = PokeAccess.ivar(menu, :@currentSelection)
      return nil unless entries.is_a?(Array) && idx.is_a?(Integer)
      e = entries[idx]
      nm = (e.name rescue nil)
      (nm.nil? || nm.to_s.empty?) ? nil : nm.to_s
    rescue StandardError
      nil
    end

    # Speaks the focused entry when it changes. Deduped on the menu instance, so the plugin's own repeated
    # refreshes are silent and reopening the menu reads where the cursor came to rest.
    def self.read(menu)
      nm = focused_name(menu)
      return if nm.nil?
      PokeAccess::Cursor.announce(menu, :voltseon_entry, nm, true, false) { PokeAccess::Menus.button_label(nm) }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("VoltseonsPauseMenu", :refreshMenu, :optional => true) do |menu, _r, _a|
  PokeAccess::VoltseonMenu.read(menu)
end
