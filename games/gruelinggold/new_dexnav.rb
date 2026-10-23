# Grueling Gold's copy of the New DexNav plugin (NewDexNav, from the pause menu), edited for the game (its pause menu
# shows the game's level cap): the area and how many species it has, then its encounters as icons, seven to a row, the
# one under the arrow named in a window beside them (navMon, renamed on each arrow, @navChoice its place); and the
# panel a search leaves on the map with the species, its ability and its egg move.
module PokeAccess
  module NewDexNavPlugin
    # The area as its window paints it, "Route 30. Total encounters for area: 7", without the rule under it.
    def self.area(scene)
      raw = (PokeAccess.sprite(scene, "locwindow").text rescue nil).to_s
      PokeAccess.sentences(raw.split(/<\/a[lcr]>/i).map { |s| PokeAccess.clean(s).gsub(/-{3,}/, "").strip })
    end

    # Runs the DexNav's loop with its species followed each frame, the area said first, queued.
    def self.browsing(scene)
      @scene = scene
      t = area(scene)
      PokeAccess.speak(t, false) unless t.empty?
      yield
    ensure
      @scene = nil
    end

    # The species under the arrow as its window names it, seen or caught as the Pokedex reading marks it, with its
    # place among the area's encounters.
    def self.cell(scene)
      win = PokeAccess.sprite(scene, "navMon")
      return nil if win.nil? || (win.disposed? rescue true)
      list = PokeAccess.ivar(scene, :@encarray) || []
      idx = PokeAccess.ivar_i(scene, :@navChoice)
      PokeAccess::Verbosity.list_entry(label(PokeAccess.clean(win.text), list[idx]), idx + 1, list.length)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A species' name with its Pokedex mark while the Pokedex reading says marks (medium and up).
    def self.label(name, species)
      return name if species.nil? || !PokeAccess::Verbosity.keep?(:dex_entry, :medium)
      return "#{name}, #{PokeAccess::I18n.t(:dex_caught)}" if PokeAccess::Util.dex_owned?(species)
      PokeAccess::Util.dex_seen?(species) ? "#{name}, #{PokeAccess::I18n.t(:dex_seen)}" : name
    end

    # A frame while the DexNav is open: the species under the arrow when it changed, the first one queued.
    def self.poll
      s = @scene
      return if s.nil?
      PokeAccess::Cursor.announce(s, :new_dexnav, PokeAccess.ivar_i(s, :@navChoice), true, false) { cell(s) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # The panel a search leaves on the map, its lines as painted, queued; the dash it paints for no egg move is left
    # out.
    def self.panel(sprites)
      win = sprites.is_a?(Hash) ? sprites["search"] : nil
      return if win.nil?
      lines = win.text.to_s.split("\n").map { |l| PokeAccess.clean(l) }.reject { |l| l =~ /\A-+\z/ }
      t = PokeAccess.sentences(lines)
      PokeAccess.speak(t, false) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end
  end
end

PokeAccess::Hooks.around_hook("NewDexNav", :main) do |scene, nxt, _a|
  PokeAccess::NewDexNavPlugin.browsing(scene) { nxt.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::NewDexNavPlugin.poll }

PokeAccess::Hooks.after_hook("NewDexNav", :main2, :hook_container => true) do |scene, _r, _a|
  PokeAccess::NewDexNavPlugin.panel(PokeAccess.ivar(scene, :@sprites))
end
PokeAccess::Hooks.wrap_singleton("NewDexNav", "quick_search", "new_dexnav_quick", :after) do |_args, _r|
  PokeAccess::NewDexNavPlugin.panel(PokeAccess.ivar(::NewDexNav, :@sprites))
end
