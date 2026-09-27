# Royal's wall and floor shop (SecretBaseMartParedSuelo_Scene, a copy of the decoration shop only its fork of the
# secret bases has): its prompts and results go to its own help window, outside pbMessageDisplay, and are said as they
# are shown, a yes/no's question before its choices; its money window is watched from the opening to the close.
PokeAccess::Game.define("royal") do
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |meth|
    before("SecretBaseMartParedSuelo_Scene", meth, :optional => true) { |_s, args| PokeAccess.say_screen_message(args) }
  end
  info_window("SecretBaseMartParedSuelo_Scene", "moneywindow", :mart_money,
              :open => [:pbStartBuyScene, :pbStartSellScene], :close => [:pbEndBuyScene, :pbEndSellScene])
end
