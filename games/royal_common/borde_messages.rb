# Royal's bordered messages: its PC shows them through its own pbDisplayBorde, unknown to the message net, and its
# bordered confirm has the (helpwindow, msg, ...) shape of the UIHelper prompts core reads.
PokeAccess::UIHelperWrap.wrap(["pbConfirmBorde"])

PokeAccess::Game.define("royal_common") do
  before("PokemonStorageScene", :pbDisplayBorde, :optional => true) do |_scene, args|
    PokeAccess.say_screen_message(args)
  end
end
