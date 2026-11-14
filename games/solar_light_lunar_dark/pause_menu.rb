module PokeAccess
  # Solar's Neo PauseMenu paints its entries into sprites rather than a command
  # window. Read the real filtered entry list, including changes after submenus.
  module SolarPauseMenu
    @scene = nil

    def self.open(scene)
      @scene = scene
      PokeAccess::Cursor.reset(scene, :solar_pause_menu)
      poll(scene)
    end

    def self.close(scene)
      @scene = nil if @scene.equal?(scene)
    end

    def self.poll(scene)
      return unless @scene.equal?(scene)
      return if PokeAccess.ivar(scene, :@hidden) || PokeAccess.ivar(scene, :@close)
      entries = PokeAccess.ivar(scene, :@entries)
      index = PokeAccess.ivar(scene, :@index)
      return unless entries.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < entries.length
      return unless defined?(MenuHandlers) && MenuHandlers.respond_to?(:getName)
      name = MenuHandlers.getName(entries[index]).to_s.dup
      name.gsub!(/\\pn/i) { ($Trainer.name rescue "").to_s }
      return if name.strip.empty?
      key = [index, entries[index], entries.length, name]
      PokeAccess::Cursor.announce(scene, :solar_pause_menu, key, true, false) do
        PokeAccess::Verbosity.list_entry(name, index + 1, entries.length)
      end
    rescue StandardError => error
      PokeAccess.log_once("solar_pause_menu", error)
      nil
    end

    def self.returned
      return unless @scene
      PokeAccess::Cursor.reset(@scene, :solar_pause_menu)
      poll(@scene)
    end
  end
end

PokeAccess::Game.define("solar_light_lunar_dark") do
  after("PokemonPauseMenu_Scene", :pbShowMenu) { |scene, _r, _a| PokeAccess::SolarPauseMenu.open(scene) }
  after("PokemonPauseMenu_Scene", :index=, :optional => true) { |scene, _r, _a| PokeAccess::SolarPauseMenu.poll(scene) }
  before("PokemonPauseMenu_Scene", :pbHideMenu) { |scene, _a| PokeAccess::SolarPauseMenu.close(scene) }
  before("PokemonPauseMenu_Scene", :pbEndScene) { |scene, _a| PokeAccess::SolarPauseMenu.close(scene) }
end
PokeAccess::MenuReturn.on_return { PokeAccess::SolarPauseMenu.returned }
