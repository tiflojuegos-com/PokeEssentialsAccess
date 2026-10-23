# Grueling Gold's egg move tutor (EggRelearner_Scene, "Teach Egg Moves" in the party menu): a copy of the stock Move
# Relearner under another name, read as core reads that one: the focused move's detail on each redraw of the list,
# and the prompts its screen writes on its help window.
PokeAccess::Game.define("gruelinggold") do
  after("EggRelearner_Scene", :pbStartScene, :hook_container => true) do |scene, _r, _a|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
  end
  after("EggRelearner_Scene", :pbDrawMoveList) { |scene, _r, _a| PokeAccess::MoveList.detail(scene) }
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    before("EggRelearner_Scene", meth, :optional => true) { |_scene, args| PokeAccess.say_screen_message(args) }
  end
end
