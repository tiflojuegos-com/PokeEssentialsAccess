module PokeAccess
  # Luka's Modular Menu (ModularMenu, the pause menu's PokemonPauseMenu_Scene redone as a column of icon panels): the
  # focused entry by the name its panel paints, with its place, as @index moves; the Safari or Bug Contest box it paints
  # on opening; and the focused entry again back from a screen an entry opened.
  module ModularPause
    @scene = nil

    # The focused entry's name as its panel paints it (the game's own name, the player's for the trainer card).
    def self.entry_name(scene)
      entries = PokeAccess.ivar(scene, :@entries) || []
      i = PokeAccess.ivar(scene, :@index)
      key = i.is_a?(Integer) ? entries[i] : nil
      return nil unless key
      PokeAccess.clean(::ModularMenu.name(key).to_s)
    end

    # Speaks the focused entry with its place when it moved; the first read of an opening is queued.
    def self.read(scene)
      @scene = scene
      entries = PokeAccess.ivar(scene, :@entries) || []
      i = PokeAccess.ivar(scene, :@index)
      return unless i.is_a?(Integer) && i >= 0 && i < entries.length
      PokeAccess::Cursor.announce(scene, :mmenu_focus, [i, entries[i]], true, false) do
        name = entry_name(scene)
        name ? PokeAccess::Verbosity.list_entry(name, i + 1, entries.length) : nil
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The menu's opening: the box it paints over the panels in the Safari Zone or the Bug Contest, queued, and a fresh
    # cursor so the focused entry is said behind it.
    def self.opening(scene, rows)
      @scene = scene
      PokeAccess::Cursor.reset(scene, :mmenu_focus)
      lines = PokeAccess::PaintCapture.lines(rows)
      PokeAccess.speak(lines.join(", "), false) unless lines.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Back from an entry's screen: the focused entry again, as nothing repaints it.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :mmenu_focus) if @scene
    end

    # The menu closes: no entry is said again until it reopens.
    def self.closed; @scene = nil; end
  end
end

# The opening's paint, sampled with pbStartScene under the reentrancy guard: the update it ends on reads nothing, so
# the box goes first and the menu loop's first update says the entry once.
PokeAccess::Hooks.around_hook("PokemonPauseMenu_Scene", :pbStartScene, :optional => true) do |scene, nxt, _a|
  ret = nil
  rows = PokeAccess::PaintCapture.sample { ret = PokeAccess::Hooks.guarded(:pbStartScene) { nxt.call } }
  PokeAccess::ModularPause.opening(scene, rows) if defined?(::ModularMenu)
  ret
end
PokeAccess::Hooks.after_hook("PokemonPauseMenu_Scene", :update, :optional => true) do |scene, _r, _a|
  PokeAccess::ModularPause.read(scene) if defined?(::ModularMenu)
end
PokeAccess::Hooks.before_hook("PokemonPauseMenu_Scene", :pbEndScene, :optional => true) do |_scene, _a|
  PokeAccess::ModularPause.closed
end
PokeAccess::MenuReturn.on_return { PokeAccess::ModularPause.returned }
