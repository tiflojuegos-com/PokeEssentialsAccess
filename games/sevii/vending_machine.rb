# Sevii's vending machine (the B2W2 mart script's VendingMachineScene): its help window's messages and questions as
# shown, its money window from opening to close, and the count in the bag after the quantity's first amount.
PokeAccess::Game.define("sevii") do
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |meth|
    before("VendingMachineScene", meth) { |_s, args| PokeAccess.say_screen_message(args) }
  end
  info_window("VendingMachineScene", "moneywindow", :mart_money, PokeAccess::Shops::MART_LIFECYCLE)
  around("VendingMachineScene", :pbChooseNumber) do |scene, nxt, _a|
    PokeAccess::Shops.prompt_open(scene)
    begin
      nxt.call
    ensure
      PokeAccess::Shops.prompt_close
    end
  end
end
