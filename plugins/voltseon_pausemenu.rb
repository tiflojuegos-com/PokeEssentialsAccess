module PokeAccess
  # Voltseon's Pause Menu, a carousel of icons replacing the field menu: the focused entry of @entries is named on
  # refreshMenu, where the plugin settles on a selection, plus the panels painted around it.
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

    # Speaks the focused entry when it changes, deduped on the menu instance.
    def self.read(menu)
      nm = focused_name(menu)
      return if nm.nil?
      PokeAccess::Cursor.announce(menu, :voltseon_entry, nm, true, false) { PokeAccess::Menus.button_label(nm) }
    rescue StandardError
      nil
    end

    # Collects the panels the menu paints around the carousel in one refresh: the map's name and whichever of
    # its components are showing (the Safari's balls and steps, the date and time, the count of new quests...).
    def self.capture_panels
      PokeAccess::PaintCapture.arm(:voltseon_panels)
      yield
    ensure
      @panels = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:voltseon_panels))
    end

    # Says the panels of the menu just opened, once, queued behind the focused entry it reads first.
    def self.say_panels
      t = @panels
      @panels = nil
      PokeAccess.speak(t, false) if t && !t.empty?
    end

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end

    # On MenuReturn's signal while the menu's loop is held, clears the entry dedup so the next refresh says it again.
    def self.returned
      menu = PokeAccess.ivar(@scene, :@pauseMenu) if @scene
      PokeAccess::Cursor.reset(menu, :voltseon_entry) if menu
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("VoltseonsPauseMenu", :refreshMenu, :optional => true) do |menu, _r, _a|
  PokeAccess::VoltseonMenu.read(menu)
end

# Around: the panels are painted inside, and the capture has to bracket exactly that paint.
PokeAccess::Hooks.around_hook("VoltseonsPauseMenu_Scene", :pbRefresh, :optional => true) do |_s, nxt, _a|
  PokeAccess::VoltseonMenu.capture_panels { nxt.call }
end

# Opening refreshes the panels, then settles the carousel (which says the entry); the panels follow it.
PokeAccess::Hooks.around_hook("VoltseonsPauseMenu_Scene", :pbStartScene, :optional => true) do |_s, nxt, _a|
  r = nxt.call
  PokeAccess::VoltseonMenu.say_panels
  r
end

# The scene's update is the menu's loop, so it is held: that is what tells the return that the menu is up.
PokeAccess::Hooks.around_hook("VoltseonsPauseMenu_Scene", :update, :optional => true) do |scene, nxt, _a|
  PokeAccess::VoltseonMenu.watch(scene)
  PokeAccess::MenuReturn.reset_nesting
  begin; nxt.call; ensure; PokeAccess::VoltseonMenu.unwatch; end
end

PokeAccess::MenuReturn.on_return { PokeAccess::VoltseonMenu.returned }
