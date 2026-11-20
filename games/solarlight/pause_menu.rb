# Solar's pause menu, Luka's Neo PauseMenu for v17.x (0226_ModularMenu.rb), the release before the Modular Menu that
# plugins/modular_menu.rb reads: PokemonPauseMenu_Scene as a column of sprite panels over @entries, each named by
# MenuHandlers.getName, with the Safari or Bug Contest box painted on opening.
module PokeAccess
  module SolarPause
    @scene = nil

    # The focused entry's name as its panel paints it; the trainer card's panel, the player's name, also names the card.
    def self.entry_name(scene)
      entries = PokeAccess.ivar(scene, :@entries) || []
      i = PokeAccess.ivar(scene, :@index)
      key = i.is_a?(Integer) ? entries[i] : nil
      return nil unless key && defined?(::MenuHandlers) && ::MenuHandlers.respond_to?(:getName)
      PokeAccess::Menus.button_label(PokeAccess.clean(::MenuHandlers.getName(key).to_s))
    end

    # Speaks the focused entry with its place when it moved; the first read of an opening is queued.
    def self.read(scene)
      @scene = scene
      entries = PokeAccess.ivar(scene, :@entries) || []
      i = PokeAccess.ivar(scene, :@index)
      return unless i.is_a?(Integer) && i >= 0 && i < entries.length
      PokeAccess::Cursor.announce(scene, :solar_pause, [i, entries[i]], true, false) do
        name = entry_name(scene)
        name && !name.empty? ? PokeAccess::Verbosity.list_entry(name, i + 1, entries.length) : nil
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The menu's opening, again after a cancelled save: the Safari or Bug Contest box it paints, queued, and a fresh
    # cursor so the focused entry is said behind it.
    def self.opening(scene, rows)
      @scene = scene
      PokeAccess::Cursor.reset(scene, :solar_pause)
      lines = PokeAccess::PaintCapture.lines(rows)
      PokeAccess.speak(lines.join(", "), false) unless lines.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Back from an entry's screen: the focused entry again, as nothing repaints it.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :solar_pause) if @scene
    end

    # The menu closes: no entry is said again until it reopens.
    def self.closed; @scene = nil; end
  end
end

PokeAccess::Game.define("solarlight") do
  around("PokemonPauseMenu_Scene", :pbStartScene) do |scene, nxt, _a|
    ret = nil
    rows = PokeAccess::PaintCapture.sample { ret = PokeAccess::Hooks.guarded(:pbStartScene) { nxt.call } }
    PokeAccess::SolarPause.opening(scene, rows)
    ret
  end
  after("PokemonPauseMenu_Scene", :update) { |scene, _r, _a| PokeAccess::SolarPause.read(scene) }
  before("PokemonPauseMenu_Scene", :pbEndScene) { |_scene, _a| PokeAccess::SolarPause.closed }
end
PokeAccess::MenuReturn.on_return { PokeAccess::SolarPause.returned }
