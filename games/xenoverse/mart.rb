module PokeAccess
  # The shop (0230_NewMart): the stock window stays hidden and the buyer picks from a painted icon grid; drawItemInfo
  # gets the grid's index after each move. Read only while the buy chooser runs, in money or in Battle Points (@bpmode).
  module XenoverseMart
    # Runs the buy chooser, then reads the outer chooser's item again, or clears the info key.
    def self.choose(scene)
      previous = @choice
      active = PokeAccess.ivar(scene, :@buying) == true
      return yield unless active
      @choice = { :scene => scene, :index => nil }
      PokeAccess::Cursor.reset(scene, :xenoverse_mart)
      yield
    ensure
      if active
        @choice = previous
        if previous && !previous[:index].nil?
          read(previous[:scene], previous[:index])
        else
          PokeAccess::Info.set_info(nil, nil)
        end
      end
    end

    # The item's price as the shop shows it: money, or Battle Points.
    def self.price(adapter, item, points)
      return PokeAccess::Menus.mart_price(adapter, item).to_s unless points
      value = adapter.getBattlePrice(item)
      value.is_a?(Numeric) ? PokeAccess::I18n.t(:xenoverse_battle_points, :n => value) : ''
    end

    # What the player has to pay with, money or Battle Points, or nil.
    def self.balance(adapter, points)
      value = points ? ($Trainer.battle_points if $Trainer && $Trainer.respond_to?(:battle_points)) : adapter.getMoney
      return nil unless value.is_a?(Numeric) && value >= 0
      PokeAccess::I18n.t(points ? :xenoverse_battle_points : :tc_money, :n => value)
    end

    # Says the item at the grid's index: name and price, how many are in the bag, its place; the balance the first time.
    def self.read(scene, index)
      return unless @choice && @choice[:scene].equal?(scene)
      stock = PokeAccess.ivar(scene, :@stock)
      return unless stock.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < stock.length
      item = stock[index]
      adapter = PokeAccess.ivar(scene, :@adapter)
      return if item.nil? || item == 0 || adapter.nil?
      name = PokeAccess::Menus.mart_name(adapter, item)
      return if name.strip.empty?
      points = !!PokeAccess.ivar(scene, :@bpmode)
      cost = price(adapter, item, points)
      money = balance(adapter, points)
      quantity = adapter.getQuantity(item) if adapter.respond_to?(:getQuantity)
      quantity = nil unless quantity.is_a?(Numeric) && quantity >= 0
      label = cost.empty? ? name : PokeAccess::I18n.t(:mart_item, :name => name, :price => cost)
      parts = [[label, :brief]]
      parts.push([PokeAccess::I18n.t(:xenoverse_in_bag, :n => quantity), :medium]) unless quantity.nil?
      parts.push([PokeAccess::Verbosity.position(index + 1, stock.length), :brief])
      PokeAccess::Menus.mart_note_desc(adapter, item)
      PokeAccess::Info.set_info(:item, item, PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Info.add_to_row(money, :xenoverse_mart_balance) if money
      @choice[:index] = index
      first = PokeAccess::Cursor.current(scene, :xenoverse_mart).nil?
      PokeAccess::Cursor.announce(scene, :xenoverse_mart, [index, item, name, cost, quantity, money], true, false) do
        row = PokeAccess::Verbosity.line(:shop_item, parts)
        first && money && PokeAccess::Verbosity.keep?(:shop_item, :medium) ? PokeAccess.sentences([row, money]) : row
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("PokemonMartScene", :pbChooseBuyItem, :hook_container => true) do |scene, original, _args|
    PokeAccess::XenoverseMart.choose(scene) { original.call }
  end
  after("PokemonMartScene", :drawItemInfo, :hook_container => true) do |scene, _result, args|
    PokeAccess::XenoverseMart.read(scene, args[0])
  end
end
