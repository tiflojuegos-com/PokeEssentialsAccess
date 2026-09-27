# Item Crafting UI: the window with the description of the item a recipe makes (itemtext), which every copy fills in
# pbRedrawItem. The stand-in keeps the order of Soulstones 2's copy: on opening, refreshNumbers and then
# pbRedrawItem; a change of recipe redraws the item, whose first step redraws the amounts while the window still
# holds the last item's description.
class CraftDescWindow
  attr_accessor :text, :visible
  def initialize; @text = ""; @visible = true; end
end

class ItemCraft_Scene
  attr_accessor :stock, :switching
  def initialize
    @sprites = {}
    adapter = Object.new
    def adapter.getName(i); "Item#{i}"; end
    def adapter.getQuantity(_i); 4; end
    @adapter = adapter
  end
  def pbStartScene; @sprites["itemtext"] = CraftDescWindow.new; :started; end
  def refreshNumbers(_index, _volume); :numbers; end
  def pbRedrawItem(index, volume)
    refreshNumbers(index, volume) if @switching
    @sprites["itemtext"].text = GameData::Item.get(@stock[index][0]).description
    @switching = false
    :item
  end
  def pbEndScene; :ended; end
end

# The reader registered before this class existed, so this repo's plugins/item_crafting.rb is evaluated again.
eval(File.read(File.join(Harness::ROOT, "plugins", "item_crafting.rb")),
     TOPLEVEL_BINDING, File.join(Harness::ROOT, "plugins", "item_crafting.rb"))

Suite.define("item crafting: the made item's description is said in full after the recipe, and the info key keeps it") do
  scene = ItemCraft_Scene.new
  scene.stock = [[:POTION, [:ORANBERRY, 2]], [:SUPERPOTION, [:ORANBERRY, 3]]]
  potion = GameData::Item.get(:POTION).description
  super_potion = GameData::Item.get(:SUPERPOTION).description
  begin
    scene.pbStartScene
    SpeakCapture.clear
    scene.refreshNumbers(0, 1)
    scene.pbRedrawItem(0, 1)
    PokeAccess::Keys.run_frame_pollers
    log = SpeakCapture.log
    eq "two lines on opening", log.length, 2
    truthy "the recipe first, interrupting", log[0][0].start_with?("ItemPOTION") && log[0][1]
    eq "then the description the window shows, queued", log[1], [potion, false]
    truthy "the info key says the item with that description", PokeAccess::Info.info_text.to_s.include?(potion)
    truthy "and Ctrl+T repeats the recipe with it", PokeAccess::Info.row_text.to_s.include?(potion)

    SpeakCapture.clear
    PokeAccess::Keys.run_frame_pollers
    silent "a frame with the same item says nothing"

    SpeakCapture.clear
    scene.switching = true
    scene.pbRedrawItem(1, 1)
    PokeAccess::Keys.run_frame_pollers
    log = SpeakCapture.log
    truthy "a change of recipe says the next recipe first", log.length == 2 && log[0][0].start_with?("ItemSUPERPOTION")
    eq "and then its own description, never the one the window held while the amounts were redrawn", log[1],
       [super_potion, false]

    SpeakCapture.clear
    scene.refreshNumbers(1, 2)
    eq "a change of amount says the amount alone", SpeakCapture.lines.length, 1
    truthy "and Ctrl+T keeps the description with the new amount", PokeAccess::Info.row_text.to_s.include?(super_potion)

    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    scene.switching = true
    scene.pbRedrawItem(0, 1)
    PokeAccess::Keys.run_frame_pollers
    eq "brief: the next recipe alone", SpeakCapture.lines.length, 1
    truthy "which Ctrl+T still completes with its description", PokeAccess::Info.row_text.to_s.include?(potion)
  ensure
    PokeAccess::Config.verbosity = :full
    scene.pbEndScene
  end
end
