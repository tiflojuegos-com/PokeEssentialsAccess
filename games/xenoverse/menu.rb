module PokeAccess
  # NewMenu is a blocking sprite menu, separate from the unused WheelMenu.
  # Read its actual selected item's translated display label and preserve input.
  module XenoverseMenu
    def self.open(scene)
      @scene = scene
      PokeAccess::Cursor.reset(scene, :xenoverse_menu)
    end

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

    def self.returned(item)
      return unless @scene
      items = PokeAccess.ivar(@scene, :@items)
      index = PokeAccess.ivar(@scene, :@index)
      return unless items.is_a?(Array) && index.is_a?(Integer) && index >= 0 && items[index].equal?(item)
      PokeAccess::Cursor.reset(@scene, :xenoverse_menu)
      poll(@scene)
    end

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
