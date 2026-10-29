# The rows of Infinite Fusion's outfit shops (games/infinitefusion_common/shop_actions.rb): an action row says the
# caption core reads, then the description the shop paints under the list, said from the full level of descriptions
# and always kept for the info key and Ctrl+T; on an outfit row the info key says the name the row paints and the
# description the shop paints for it; Hoenn's outfit on, marked with a star before its name, is said worn instead, and
# the dash a row paints for its price says what it stands for: an outfit already owned, or the hair shop's hairstyle on.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

class IfShopActionsGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "shop_actions.rb")

  # The game's Outfit (clothes, a hat, a hairstyle), the entry its outfit shops stock in place of an item id: an id, a
  # name and a description, either missing for some hats.
  OutfitEntry = Struct.new(:id, :name, :description)

  # An outfit shop's adapter: the caption and the description of its action rows, the hat menu's and the hair shop's,
  # and its outfits' names, prices and descriptions, the hat shop's own for an outfit that has none.
  class OutfitsAdapter
    CAPTIONS = { :REMOVE_HAT => "Remove hat", :SWAP_COLOR => "Swap Color" }
    DESCRIPTIONS = { :REMOVE_HAT => "Go without a hat and show off your fabulous hair!",
                     :SWAP_COLOR => "Swap to the next base hair color." }

    def getSpecialItemCaption(s); CAPTIONS[s]; end
    def getSpecialItemDescription(s); DESCRIPTIONS[s]; end
    def getDisplayName(item); item.name || item.id; end
    def getDisplayPrice(_item, _selling = nil); "$ 500"; end
    def getDescription(item); item.description || "A headgear that trainers can wear."; end
  end

  # Hoenn's clothes or hat shop: the outfit on painted with the mark getDisplayName puts before its name.
  class WornAdapter < OutfitsAdapter
    def initialize(worn); @worn = worn; end

    def getDisplayName(item)
      name = super
      item.id == @worn ? "* #{name}" : name
    end
  end

  # A shop with an outfit already owned, which paints a dash in place of its price.
  class OwnedAdapter < OutfitsAdapter
    def initialize(owned); @owned = owned; end
    def itemOwned(item); item.id == @owned; end
    def getDisplayPrice(item, _selling = nil); itemOwned(item) ? "-" : super; end
  end

  # The hair shop's adapter (HairMartAdapter): no hairstyle is ever owned, and the hairstyle on paints a dash in place
  # of its price.
  class HairAdapter < OutfitsAdapter
    def initialize(worn); @worn = worn; end
    def itemOwned(_item); false; end
    def getDisplayPrice(item, _selling = nil); item.id == @worn ? "-" : super; end
  end

  # The mart window's own adapter, the game's BuyAdapter: captions, names and prices passed on, no descriptions, and
  # the adapter it wraps.
  class BuyAdapter
    def initialize(adapter); @adapter = adapter; end
    def getSpecialItemCaption(s); @adapter.getSpecialItemCaption(s); end
    def getDisplayName(item); @adapter.getDisplayName(item); end
    def getDisplayPrice(item); @adapter.getDisplayPrice(item, false); end
    def getAdapter; @adapter; end
  end

  # Evaluates the profile file once, as boot does, its overrides over core's shop rows and the info key's items.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # Lends the game's Outfit and HairMartAdapter names to the stand-ins for the test alone, the latter over the one
  # another test file keeps, and forgets the outfit row read last.
  def setup
    super
    @outfit_made = !Object.const_defined?(:Outfit)
    Object.const_set(:Outfit, OutfitEntry) if @outfit_made
    @hair_was = Object.const_defined?(:HairMartAdapter) ? Object.send(:remove_const, :HairMartAdapter) : nil
    Object.const_set(:HairMartAdapter, HairAdapter)
    PokeAccess::IFShopActions.instance_variable_set(:@outfit, nil)
  end

  # Takes the names back from the stand-ins, the HairMartAdapter kept before put back, and forgets the outfit row read
  # last.
  def teardown
    Object.send(:remove_const, :Outfit) if @outfit_made
    Object.send(:remove_const, :HairMartAdapter)
    Object.const_set(:HairMartAdapter, @hair_was) if @hair_was
    PokeAccess::IFShopActions.instance_variable_set(:@outfit, nil)
    super
  end

  test "an action row says its caption, then the description the shop paints, at the full level of descriptions" do
    assert_equal "Remove hat. Go without a hat and show off your fabulous hair!", row(:REMOVE_HAT)
  end

  test "below the full level the row is its caption alone, and the info key and Ctrl+T still say both" do
    PokeAccess::Config.verbosity = :medium
    assert_equal "Swap Color", row(:SWAP_COLOR)
    assert_equal "Swap Color. Swap to the next base hair color.", PokeAccess::Info.info_text
    assert_equal "Swap Color. Swap to the next base hair color.", PokeAccess::Info.row_text
  end

  test "the info key on an outfit row says the name the row paints, then the description the shop paints for it" do
    cap = OutfitEntry.new("absolhat", "Absol Cap", "A hat that resembles the visage of Absol.")
    assert_equal "Absol Cap, $ 500", row(cap, [:REMOVE_HAT, cap])
    assert_equal "Absol Cap. A hat that resembles the visage of Absol.", PokeAccess::Info.info_text
    assert_equal "Absol Cap, $ 500", PokeAccess::Info.row_text
  end

  test "an outfit with no name and no description gives the info key the id and the description the shop paints" do
    hat = OutfitEntry.new("absolhat2", nil, nil)
    row(hat, [hat])
    assert_equal "absolhat2. A headgear that trainers can wear.", PokeAccess::Info.info_text
  end

  test "an outfit whose description is blank gives the info key its name alone" do
    cap = OutfitEntry.new("cap", "Plain Cap", "")
    row(cap, [cap])
    assert_equal "Plain Cap", PokeAccess::Info.info_text
  end

  test "the outfit on is said worn in place of the mark before its name, from the brief level up" do
    kimono = OutfitEntry.new("kimono", "Kimono", "A kimono from Fortree.")
    worn = "Kimono, $ 500, #{PokeAccess::I18n.t(:shop_worn)}"
    assert_equal [worn, worn, worn], vb_levels { row(kimono, [kimono], WornAdapter.new("kimono")) }
  end

  test "Ctrl+T says the outfit on worn and the info key its name and description, neither of them the mark" do
    kimono = OutfitEntry.new("kimono", "Kimono", "A kimono from Fortree.")
    row(kimono, [kimono], WornAdapter.new("kimono"))
    assert_equal "Kimono, $ 500, #{PokeAccess::I18n.t(:shop_worn)}", PokeAccess::Info.row_text
    assert_equal "Kimono. A kimono from Fortree.", PokeAccess::Info.info_text
  end

  test "an outfit that is not on keeps the row it paints" do
    cap = OutfitEntry.new("cap", "Plain Cap", "A cap.")
    assert_equal "Plain Cap, $ 500", row(cap, [cap], WornAdapter.new("kimono"))
    assert_equal "Plain Cap, $ 500", PokeAccess::Info.row_text
  end

  test "an outfit already owned says so in place of the dash it paints for its price, Ctrl+T too" do
    kimono = OutfitEntry.new("kimono", "Kimono", "A kimono from Fortree.")
    owned = "Kimono, #{PokeAccess::I18n.t(:if_outfit_owned)}"
    assert_equal owned, row(kimono, [kimono], OwnedAdapter.new("kimono"))
    assert_equal owned, PokeAccess::Info.row_text
  end

  test "an outfit not owned keeps the price it paints" do
    cap = OutfitEntry.new("cap", "Plain Cap", "A cap.")
    assert_equal "Plain Cap, $ 500", row(cap, [cap], OwnedAdapter.new("kimono"))
  end

  test "the hair shop's hairstyle on says so in place of the dash it paints for its price, from the brief level up" do
    ponytail = OutfitEntry.new("ponytail", "Ponytail", "A hairstyle for trainers.")
    current = "Ponytail, #{PokeAccess::I18n.t(:if_hair_current)}"
    assert_equal [current, current, current], vb_levels { row(ponytail, [ponytail], HairAdapter.new("ponytail")) }
    assert_equal current, PokeAccess::Info.row_text
  end

  test "another hairstyle in the hair shop keeps the price it paints" do
    bob = OutfitEntry.new("bob", "Bob Cut", "A hairstyle for trainers.")
    assert_equal "Bob Cut, $ 500", row(bob, [bob], HairAdapter.new("ponytail"))
  end

  private

  # The focused row of a mart window over a shop's stock, through the game's BuyAdapter, with the cursor on item.
  def row(item, stock = [:SWAP_COLOR, :REMOVE_HAT], adapter = OutfitsAdapter.new)
    win = Window_PokemonMart.new
    win.instance_variable_set(:@stock, stock)
    win.instance_variable_set(:@adapter, BuyAdapter.new(adapter))
    win.instance_variable_set(:@i, stock.index(item))
    def win.index; @i; end
    PokeAccess::Menus.focused_text(win)
  end
end
