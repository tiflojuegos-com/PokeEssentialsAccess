module PokeAccess
  # Dark Horizon's Colosseum Points move tutors (pbBattlePointMoveShop, BattlePointShop_Moves_Scene): a copy of the
  # Battle Point shop whose list, the stock Window_BattlePointShop, sells [move, price] pairs through
  # BattlePointShopAdapter_Moves. Its row is the move and its price, the move's type from medium (the machine icon
  # beside the list is of that type); the info key says the move whole.
  module DHMoveShop
    # The row of a move-shop window, or nil for any other shop's, which the core's row reads.
    def self.row(win, i)
      ad = PokeAccess.ivar(win, :@adapter)
      return nil unless ad && ad.class.name == "BattlePointShopAdapter_Moves"
      stock = PokeAccess.ivar(win, :@stock)
      return nil unless stock.is_a?(Array) && i < stock.length && stock[i].is_a?(Array)
      entry = stock[i]
      mv = (GameData::Move.get(entry[0]) rescue nil)
      type = mv ? PokeAccess::Data.type_name(mv.type) : nil
      parts = [[ad.getDisplayName(entry), :brief], [ad.getDisplayPrice(entry), :brief], [type, :medium]]
      PokeAccess::Info.set_info(:move, mv, PokeAccess::Verbosity.full_line(parts)) if mv
      PokeAccess::Verbosity.line(:shop_item, parts)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  override(PokeAccess::Shops, :row) do |_mod, original, args|
    PokeAccess::DHMoveShop.row(args[0], args[1]) || original.call
  end

  # What the player has to spend, "CP: 5 CP", as the stock shop's window is read.
  info_window("BattlePointShop_Moves_Scene", "battlepointwindow", :dh_cp_moves_points)

  # The shop's own prompts ("You don't have enough CP.", the price question, "All done!") on its help window.
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |meth|
    before("BattlePointShop_Moves_Scene", meth) { |_scene, args| PokeAccess.say_screen_message(args) }
  end
end
