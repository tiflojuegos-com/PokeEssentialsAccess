# Ashen Frost's move remembering (MoveRemember_Scene, 013_Move_Remember.rb, DemICE's copy of the relearner, opened from the
# summary's moves): a hand-drawn list read as core reads the stock relearner, its prompts as core reads those of a screen.
PokeAccess::Game.define("ashenfrost") do
  after("MoveRemember_Scene", :pbStartScene, :hook_container => true) do |scene, _ret, _args|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
  end
  after("MoveRemember_Scene", :pbDrawMoveList) { |scene, _ret, _args| PokeAccess::MoveList.detail(scene) }
  [:pbDisplay, :pbConfirm].each do |meth|
    before("MoveRemember_Scene", meth) { |_scene, args| PokeAccess.say_screen_message(args) }
  end
  clear_info_on("MoveRemember_Scene", :pbEndScene)

  # Both lists paint this title, in the game's own words.
  override("PokeAccess::MoveList", :title) { |_mod, _original, _args| _INTL("Teach which move?") }
end
