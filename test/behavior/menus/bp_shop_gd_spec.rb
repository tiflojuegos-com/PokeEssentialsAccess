# The Battle Point shop: the bag count and points left are read, the description is left to the info key, and on
# Cancel the hidden bag box's stale count is not. Both scenes are engine stubs, so core binds to them at load.
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

# The row price in the window's currency: Soulstones 2's Achievement Points shop keeps @useBP on the window and passes
# it to the adapter as a third argument that defaults to BP.
class BPShopRowWindow
  def initialize(stock, adapter, use_bp = nil)
    @stock = stock; @adapter = adapter
    @useBP = use_bp unless use_bp.nil?
  end
end

class BPShopTwoCurrencyAdapter
  def getDisplayName(item); item.to_s; end
  def getDisplayPrice(_item, _selling = false, use_bp = true); use_bp ? "4 BP" : "3 AP"; end
end

class BPShopVanillaAdapter
  def getDisplayName(item); item.to_s; end
  def getDisplayPrice(_item, _selling = false); "12 BP"; end
end

Suite.define("bp shop rows: the price is read in the currency the window is selling for") do
  ap = BPShopRowWindow.new([:MASTERBALL], BPShopTwoCurrencyAdapter.new, false)
  eq "an Achievement Points shop reads the AP price", PokeAccess::Shops.row(ap, 0), "MASTERBALL, 3 AP"
  bp = BPShopRowWindow.new([:MASTERBALL], BPShopTwoCurrencyAdapter.new, true)
  eq "the same window in Battle Points reads the BP price", PokeAccess::Shops.row(bp, 0), "MASTERBALL, 4 BP"
  plain = BPShopRowWindow.new([:PROTEIN], BPShopVanillaAdapter.new)
  eq "a shop with one currency and a two-argument adapter still reads its price", PokeAccess::Shops.row(plain, 0),
     "PROTEIN, 12 BP"
end
