module PokeAccess
  # NewMart keeps its stock window hidden and selects its painted icon grid
  # with a local index. Observe that grid only while the buy chooser runs.
  module XenoverseMart
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

    # Match NewMart's cash/BP display; never use its hidden legacy window.
    def self.price(adapter, item, points)
      return PokeAccess::Menus.mart_price(adapter, item).to_s unless points
      value = adapter.getBattlePrice(item)
      value.is_a?(Numeric) ? PokeAccess::I18n.t(:rl_sys_points, :n => value) : ''
    end

    def self.balance(adapter, points)
      value = points ? ($Trainer.battle_points if $Trainer && $Trainer.respond_to?(:battle_points)) : adapter.getMoney
      return nil unless value.is_a?(Numeric) && value >= 0
      PokeAccess::I18n.t(points ? :rl_sys_points : :tc_money, :n => value)
    end

    # drawItemInfo receives the exact local index after each grid selection.
    # Adapter names include machine moves and descriptions match the game.
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
      parts.push([PokeAccess::I18n.t(:ura_bmart_have, :list => quantity), :medium]) unless quantity.nil?
      parts.push([PokeAccess::Verbosity.position(index + 1, stock.length), :brief])
      PokeAccess::Menus.mart_note_desc(adapter, item)
      PokeAccess::Info.set_info(:item, item, PokeAccess::Verbosity.full_line(parts))
      PokeAccess::Info.add_to_row(money, :xenoverse_mart_balance) if money
      @choice[:index] = index
      first = PokeAccess::Cursor.current(scene, :xenoverse_mart).nil?
      key = [index, item, name, cost, quantity, money]
      PokeAccess::Cursor.announce(scene, :xenoverse_mart, key, true, false) do
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
