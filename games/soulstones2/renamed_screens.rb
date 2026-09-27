# Vanilla screens Soulstones 2 ships under other names, bound to core's readers: MoveRemember_Scene (the move
# relearner) and Original_PokemonParty_Scene (the Guardian's trial team picker, with its own help and messages).
PokeAccess::Game.define("soulstones2") do
  # hook_container: this only remembers the window; the opening read is done by hooks pbStartScene drives.
  after("MoveRemember_Scene", :pbStartScene, :hook_container => true, :optional => true) do |scene, _r, _a|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
  end

  after("MoveRemember_Scene", :pbDrawMoveList, :optional => true) do |scene, _r, _a|
    PokeAccess::MoveList.detail(scene)
  end

  # Both scenes' messages (pbConfirm and the rest), which core's message net binds only under vanilla names.
  PokeAccess::SCREEN_MSG_METHODS.each do |meth|
    ["MoveRemember_Scene", "Original_PokemonParty_Scene"].each do |cname|
      before(cname, meth, :optional => true) do |_scene, args|
        PokeAccess.say_screen_message(args)
      end
    end
  end

  around("Original_PokemonParty_Scene", :pbSetHelpText, :optional => true) do |scene, nxt, args|
    r = nxt.call
    PokeAccess.say_party_help(scene, args[0])
    r
  end

  # Opened the way core opens the vanilla scene: the first member read again, and queued behind the rule
  # the screen sets as its help line.
  around("Original_PokemonParty_Scene", :pbStartScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::UIV21.reset(:party)
    PokeAccess::UIV21.opening_party { nxt.call }
  end
end
