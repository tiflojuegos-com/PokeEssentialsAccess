# Slateport's market in Infinite Fusion Hoenn (games/infinitefusion_hoenn/market.rb), gamedata pass: each vendor is named by
# what its stall sells, never by its internal event name, and the spots and the events that run the market are not listed.
ifh_market = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "market.rb")
eval(Harness.source(ifh_market), TOPLEVEL_BINDING, ifh_market)

class IfhMarketGdTest < PokeAccessTest
  Market = PokeAccess::IF2Market
  Loc = PokeAccess::Locator
  Vendor = Struct.new(:id, :name, :character_name)

  def setup
    super
    $game_map.map_id = 902
  end

  test "names every vendor of the game's market by its stall" do
    { "vendor_warm.sl" => :if2_stall_warm, "vendor_hat.sl" => :if2_stall_hat, "vendor_glasses.sl" => :if2_stall_glasses,
      "vendor_headband.sl" => :if2_stall_headband, "vendor_cold.sl" => :if2_stall_cold, "vendor_mask.sl" => :if2_stall_mask,
      "vendor_energyGuru.sl" => :if2_stall_energy, "vendor_Happiness Check.sl" => :if2_stall_happiness,
      "vendor_tm.sl" => :if2_stall_tm, "vendor_incense.sl" => :if2_stall_incense,
      "vendor_pokeballs.sl" => :if2_stall_balls }.each do |name, key|
      assert_equal t(key), Loc.target_name(Vendor.new(5, name, "NPC_Hoenn_vendors")), name
    end
  end

  test "calls a vendor the table does not know a market stall, never by its internal name" do
    assert_equal t(:if2_stall), Loc.target_name(Vendor.new(5, "vendor_new.sl", "NPC_Hoenn_vendors"))
    assert_equal t(:if2_stall), Loc.target_name(Vendor.new(5, "vendor_new", "NPC_Hoenn_vendors"))
  end

  test "names the clerk of the clothes shop, whose event is called just vendor" do
    assert_equal t(:if2_clothes_shop), Loc.target_name(Vendor.new(3, "vendor", "NPC_clerk_m"))
  end

  test "leaves any other event to the core" do
    assert_nil Market.stall_name(Vendor.new(5, "vendors", "NPC"))
    assert_nil Market.stall_name(Vendor.new(5, "the vendor_hat.sl", "NPC"))
    assert_nil Market.stall_name(Vendor.new(5, nil, "NPC"))
  end

  test "hides what runs the market from the list, and no one else" do
    %w[market_spot market_initializer market_controller].each do |name|
      assert_equal true, Market.machinery?(Vendor.new(5, name, "NPC_shopkeeper_f")), name
      assert Loc.hidden?(Vendor.new(5, name, "NPC_shopkeeper_f")), name
    end
    ["vendor_hat.sl", "marketing", "the market_spot", "Market_spot"].each do |name|
      assert_equal false, Market.machinery?(Vendor.new(5, name, "NPC")), name
    end
    assert_equal false, Market.machinery?(Vendor.new(5, nil, "NPC"))
    refute Loc.hidden?(Vendor.new(5, "vendor_hat.sl", "NPC_Hoenn_vendors"))
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end
end
