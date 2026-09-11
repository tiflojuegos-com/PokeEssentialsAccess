# Screens this game ships as a vanilla copy under a different NAME, so the reader is core's and only the
# binding is the game's. MoveRemember_Scene is the move relearner, with the same @sprites["commands"]
# window and the same pbDrawMoveList that core/menus/v21 reads.
PokeAccess::Game.define("soulstones2") do
  # hook_container: this only remembers the window; the opening read is done by hooks pbStartScene drives.
  after("MoveRemember_Scene", :pbStartScene, :hook_container => true, :optional => true) do |scene, _r, _a|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
  end

  after("MoveRemember_Scene", :pbDrawMoveList, :optional => true) do |scene, _r, _a|
    PokeAccess::MoveList.detail(scene)
  end

  # Its questions ("Teach Thunderbolt?") go to its own message window through pbConfirm, the way the
  # vanilla relearner's do; core's message net lists the vanilla names, so the renamed one joins it here.
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    before("MoveRemember_Scene", meth, :optional => true) do |_scene, args|
      PokeAccess.say_screen_message(args)
    end
  end
end
