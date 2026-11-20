module PokeAccess
  # The pause menu (0194_NewMenu_Scene, NewMenu; the WheelMenu of 0193 is never opened): a row of sprites, each item
  # with the translated label it shows (displayedName), chosen by @index.
  module XenoverseMenu
    # Starts reading a menu that opens.
    def self.open(scene)
      @scene = scene
      PokeAccess::Cursor.reset(scene, :xenoverse_menu)
    end

    # Says the selected item's label while the menu loops.
    def self.poll(scene)
      return unless @scene.equal?(scene) && PokeAccess.ivar(scene, :@looping)
      items = PokeAccess.ivar(scene, :@items)
      index = PokeAccess.ivar(scene, :@index)
      return unless items.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < items.length
      item = items[index]
      return unless item && item.respond_to?(:displayedName)
      label = item.displayedName
      return unless label.is_a?(String) && !label.empty?
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess::Cursor.announce(scene, :xenoverse_menu, [index, label], true, false) { label }
    end

    # Reads the selected item again when its screen returns to the menu.
    def self.returned(item)
      return unless @scene
      items = PokeAccess.ivar(@scene, :@items)
      index = PokeAccess.ivar(@scene, :@index)
      return unless items.is_a?(Array) && index.is_a?(Integer) && index >= 0 && items[index].equal?(item)
      PokeAccess::Cursor.reset(@scene, :xenoverse_menu)
      poll(@scene)
    end

    # Forgets the menu as it closes.
    def self.close(scene)
      @scene = nil if @scene.equal?(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("NewMenu", :open) do |scene, call_next, _args|
    PokeAccess::XenoverseMenu.open(scene)
    begin
      call_next.call
    ensure
      PokeAccess::XenoverseMenu.close(scene)
    end
  end
  before("NewMenu", :update) { |scene, _args| PokeAccess::XenoverseMenu.poll(scene) }
  after("NewMenu", :handleInput, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseMenu.poll(scene) }
  after("NewMenu_Item", :select, :hook_container => true) { |item, _result, _args| PokeAccess::XenoverseMenu.returned(item) }
  before("NewMenu", :close) { |scene, _args| PokeAccess::XenoverseMenu.close(scene) }
end
