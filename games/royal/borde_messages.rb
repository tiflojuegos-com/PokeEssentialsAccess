# Royal's PC shows its messages through its own bordered pbDisplayBorde, unknown to the message net.
PokeAccess::Game.define("royal") do
  before("PokemonStorageScene", :pbDisplayBorde, :optional => true) do |_scene, args|
    PokeAccess.say_screen_message(args)
  end
end
