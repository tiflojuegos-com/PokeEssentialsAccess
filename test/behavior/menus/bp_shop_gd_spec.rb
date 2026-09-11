# The Battle Point shop (BattlePointShop_Scene, five of the surveyed games): a list of item ids beside three
# standing windows. Two of them are read -- how many of the focused item are in the bag, and how many points
# are left -- and the description box is not: the row files the focused item, so the info key reads it there
# the way it does in the mart.
#
# The stand-in is the game's own pbRefresh, key for key. The bag box is HIDDEN on the Cancel row while
# keeping the last item's count written in it, which is why a reader that watched only the text announced a
# count for a box nobody could see.
#
# Both scenes live in the engine stubs, where core can find them at load: a class that appears only in a
# spec file is declared to a reader that has already gone looking and bound nothing.
Suite.define("bp shop: the two number windows are read, the description is left to the info key") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  begin
    scene = BattlePointShop_Scene.new
    iw.enter(scene)

    scene.focus(:PROTEIN, 2, 120)
    SpeakCapture.clear
    iw.tick
    line = SpeakCapture.lines.join(" | ")
    match "how many are already in the bag", line, /In Bag/
    match "and the points there are to spend", line, /Battle Points/
    truthy "but not the description, which belongs to the info key", !line.include?("Raises the Attack")

    SpeakCapture.clear
    iw.tick
    silent "and standing on it says nothing more"

    # The Cancel row: the bag box is hidden there with a stale count still written in it.
    scene.focus(nil, 2, 120)
    SpeakCapture.clear
    iw.tick
    silent "on Cancel the hidden bag box says nothing, and the points have not changed"
  ensure
    iw.enter(prev_live)
  end
end

Suite.define("mart: the bag count and the money are read, entered by its own buy scene") do
  iw = PokeAccess::InfoWindow
  prev_live = iw.live
  begin
    truthy "the mart takes a lifecycle at all, which is the half that shipped broken",
           !iw.unentered.include?("PokemonMart_Scene")

    scene = PokemonMart_Scene.new
    scene.focus(:POTION, 3, 12500)
    SpeakCapture.clear
    scene.pbStartBuyScene([], nil)
    iw.tick
    line = SpeakCapture.lines.join(" | ")
    match "how many of the focused item are already in the bag", line, /In Bag/
    match "and what there is to spend", line, /12500/
    truthy "and not the description", !line.include?("Restores 20 HP")

    scene.focus(:POTION, 2, 12300)
    SpeakCapture.clear
    iw.tick
    line = SpeakCapture.lines.join(" | ")
    match "a purchase changes both, and both are said again", line, /12300/
    match "the bag count included", line, /In Bag/

    scene.pbEndBuyScene
    scene.focus(:POTION, 9, 99999)
    SpeakCapture.clear
    iw.tick
    silent "and once the shop is closed the watch is not held by anyone"
  ensure
    iw.enter(prev_live)
  end
end
