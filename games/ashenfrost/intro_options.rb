# Ashen Frost's new-game options (PokemonIntroOption_Scene, 009_IntroOptions.rb, opened by the event on map 76: difficulty,
# level cap and the rest): core reads its option window as any other, and its title and each option's help are bound here,
# as core binds them for the stock Options screen.
PokeAccess::Game.define("ashenfrost") do
  before("PokemonIntroOption_Scene", :pbStartScene) { |_scene, _args| PokeAccess::Info.set_info(nil, nil) }
  before("PokemonIntroOption_Scene", :pbUpdate) { |scene, _args| PokeAccess::ScreenTitle.say(scene, "title") }
  after("PokemonIntroOption_Scene", :pbChangeSelection) { |scene, _ret, _args| PokeAccess::OptionHelp.read(scene) }
  clear_info_on("PokemonIntroOption_Scene", :pbEndScene)
end
