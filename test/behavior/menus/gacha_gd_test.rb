# Magic Gachapon (plugins/magic_gachapon.rb), gamedata pass: on refresh, the banner, its featured rewards with stars
# (kept for the info key), the focused button and the counters when they change; the Info panel and each reveal's tier.
class GachaGdTest < PokeAccessTest
  Banner = Struct.new(:name, :rewards, :stars, :description)

  # The pulls made on each banner, by its name, as Royal's $PokemonGlobal keeps them.
  Pulls = Struct.new(:by_banner) do
    def get_tiradas_banner(name); by_banner[name].to_i; end
  end

  # The bag's counts of the two kinds of ticket.
  Tickets = Struct.new(:counts) do
    def quantity(item); counts[item].to_i; end
  end

  EGGS = Banner.new("- Banner Permanente Huevos -",
                    ["Graphics/Pokemon/Eggs/MUNCHLAX", "Graphics/Pokemon/Eggs/TINKATINK", "Graphics/Pokemon/Eggs/GIMMIGHOUL"],
                    [5, 5, 5], "Huevos.")
  ITEMS = Banner.new("- Banner Permanente Objetos -",
                     ["Graphics/Items/SUPERCAPSULE", "Graphics/Items/MASTERBALL", "Graphics/Items/MAXSOUP"], [5, 4, 3],
                     "Objetos.")
  BLANK = Banner.new("Banner", ["Graphics/GachaPj/nada"] * 3, [5, 5, 5], "")

  test "says the banner with its place, the rewards it features with their stars, the button and the counters" do
    in_royal { refresh(gacha) }
    line = [list_entry(EGGS, 1), featured_eggs, "Tirar x1", t(:gacha_pulls, :n => 2), t(:gacha_tickets, :n => 4),
            t(:gacha_ultra, :n => 1)].join(". ")
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "keeps the banner's featured rewards on the info key" do
    in_royal { refresh(gacha) }
    assert_equal featured_eggs, PokeAccess::Info.info_text
  end

  test "names an item banner's rewards by their items, and its own counters" do
    scene = gacha
    in_royal do
      refresh(scene)
      SpeakCapture.clear
      scene.instance_variable_set(:@banner_sel, 1)
      refresh(scene)
    end
    featured = t(:gacha_featured, :list => [["SUPERCAPSULE", 5], ["MASTERBALL", 4], ["MAXSOUP", 3]].map { |item, n|
      t(:gacha_prize, :name => GameData::Item.get(item.to_sym).name, :n => n) }.join("; "))
    line = [list_entry(ITEMS, 2), featured, "Tirar x1", t(:gacha_pulls, :n => 0), t(:gacha_tickets, :n => 4),
            t(:gacha_ultra, :n => 1)].join(". ")
    assert_equal [line], SpeakCapture.lines
  end

  test "says no featured line for a banner whose pictures name nothing, and clears the info key" do
    scene = gacha
    in_royal do
      refresh(scene)
      SpeakCapture.clear
      scene.instance_variable_set(:@banner_sel, 2)
      refresh(scene)
    end
    assert_equal [[list_entry(BLANK, 3), "Tirar x1", t(:gacha_pulls, :n => 0), t(:gacha_tickets, :n => 4),
                   t(:gacha_ultra, :n => 1)].join(". ")], SpeakCapture.lines
    assert_nil PokeAccess::Info.info_text
  end

  test "says no featured line for a banner with no rewards, or with rewards but no stars" do
    [Banner.new("Banner vacío", [], [], ""), Banner.new("Banner vacío", EGGS.rewards, nil, "")].each do |banner|
      SpeakCapture.clear
      in_royal { refresh(gacha(:@banners => [banner])) }
      assert_equal [[t(:list_entry, :name => "Banner vacío", :n => 1, :tot => 1), "Tirar x1", t(:gacha_pulls, :n => 0),
                     t(:gacha_tickets, :n => 4), t(:gacha_ultra, :n => 1)].join(". ")], SpeakCapture.lines,
                   "rewards #{banner.rewards.inspect}, stars #{banner.stars.inspect}"
    end
  end

  test "says the focused button alone as the cursor moves, in the build's words" do
    scene = gacha
    in_royal do
      refresh(scene)
      SpeakCapture.clear
      scene.instance_variable_set(:@sel, 3)
      with_intl("Ticket ULTRA" => "ULTRA Ticket") { refresh(scene) }
    end
    assert_equal [["ULTRA Ticket", true]], SpeakCapture.log
  end

  test "says the focused button again with the counters a pull changed, and not the banner" do
    scene = gacha
    pulls = { EGGS.name => 2 }
    in_royal(pulls) do
      refresh(scene)
      SpeakCapture.clear
      pulls[EGGS.name] = 3
      refresh(scene)
    end
    assert_equal [["Tirar x1", t(:gacha_pulls, :n => 3), t(:gacha_tickets, :n => 4), t(:gacha_ultra, :n => 1)].join(". ")],
                 SpeakCapture.lines
  end

  test "says nothing on a refresh that changes nothing" do
    scene = gacha
    in_royal do
      refresh(scene)
      SpeakCapture.clear
      refresh(scene)
    end
    assert_nothing_spoken
  end

  test "says the banner again as the three-button copy's cursor moves up onto it, with its coins" do
    scene = gacha(:@sel => 0, :@sprites => {})
    with_coins(12) do
      refresh(scene)
      scene.instance_variable_set(:@sel, 3)
      refresh(scene)
    end
    assert_equal [[list_entry(EGGS, 1), featured_eggs, "Información", t(:gacha_coins, :n => 12)].join(". "),
                  [list_entry(EGGS, 1), featured_eggs].join(". ")], SpeakCapture.lines
  end

  test "counts nothing the game cannot count, in either copy" do
    global = $PokemonGlobal
    bag = $bag
    $PokemonGlobal = Object.new
    $bag = nil
    counts = [gacha, gacha(:@sprites => {})].map { |scene| PokeAccess::MagicGachapon.counters(scene, [EGGS], 0) }
    assert_equal [[t(:gacha_pulls, :n => 0), t(:gacha_tickets, :n => 0), t(:gacha_ultra, :n => 0)],
                  [t(:gacha_coins, :n => 0)]], counts
  ensure
    $PokemonGlobal = global
    $bag = bag
  end

  test "names a reward from its picture: an egg, a species, an item, or nothing for another picture or a nameless one" do
    names = with_species_lookup do
      ["Graphics/Pokemon/Eggs/MUNCHLAX", "Graphics/Pokemon/Front/PIKACHU_1.png", "Graphics\\Items\\POTION.png",
       "Graphics/GachaPj/nada", "Graphics/Items/.png"].map { |path| PokeAccess::MagicGachapon.reward_name(path) }
    end
    assert_equal [t(:gacha_egg, :name => GameData::Species.get(:MUNCHLAX).name), GameData::Species.get(:PIKACHU_1).name,
                  GameData::Item.get(:POTION).name, nil, nil], names
  end

  test "says the banner's description as its Info panel opens" do
    PokeAccess::MagicGachapon.info(gacha(:@banner_sel => 1))
    assert_equal [["Objetos.", true]], SpeakCapture.log
  end

  test "says a reveal's tier, except for the reveal of an item reward just named" do
    gm = PokeAccess::MagicGachapon
    gm.reveal(4)
    gm.reward_said
    gm.reveal(5)
    gm.reveal(3)
    assert_equal [[t(:gacha_stars, :n => 4), true], [t(:gacha_stars, :n => 3), true]], SpeakCapture.log
  ensure
    gm.instance_variable_set(:@reward_said, false)
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The gacha scene of Royal's copy (five buttons) on the eggs' banner, its cursor on Tirar x1; ivars override it.
  def gacha(ivars = {})
    World.stub_scene({ :@sel => 1, :@banner_sel => 0, :@banners => [EGGS, ITEMS, BLANK],
                       :@sprites => { "button5" => Object.new } }.merge(ivars))
  end

  # A banner's name with its place among the three.
  def list_entry(banner, n)
    t(:list_entry, :name => banner.name, :n => n, :tot => 3)
  end

  # The eggs' banner's featured rewards, five stars each.
  def featured_eggs
    eggs = [:MUNCHLAX, :TINKATINK, :GIMMIGHOUL].map do |sp|
      t(:gacha_prize, :name => t(:gacha_egg, :name => GameData::Species.get(sp).name), :n => 5)
    end
    t(:gacha_featured, :list => eggs.join("; "))
  end

  # The scene's refresh as the reader hears it, the species lookup it names eggs with in place.
  def refresh(scene)
    with_species_lookup { PokeAccess::MagicGachapon.refresh(scene) }
  end

  # The block's value with Royal's counters: the pulls per banner name, four tickets and one ULTRA ticket in the bag.
  def in_royal(pulls = { EGGS.name => 2 })
    global = $PokemonGlobal
    bag = $bag
    $PokemonGlobal = Pulls.new(pulls)
    $bag = Tickets.new({ :TICKETGACHA => 4, :TICKETGACHAULTRA => 1 })
    yield
  ensure
    $PokemonGlobal = global
    $bag = bag
  end

  # The block's value with Awakening's coins counted by $PokemonGlobal.
  def with_coins(coins)
    global = $PokemonGlobal
    $PokemonGlobal = Struct.new(:gachaCoins).new(coins)
    yield
  ensure
    $PokemonGlobal = global
  end

  # The block's value with GameData::Species answering try_get as the engine does, which the stub lacks.
  def with_species_lookup
    species = GameData::Species
    had = species.respond_to?(:try_get)
    species.define_singleton_method(:try_get) { |id| GameData::Species.get(id) } unless had
    yield
  ensure
    species.singleton_class.send(:remove_method, :try_get) unless had
  end
end
