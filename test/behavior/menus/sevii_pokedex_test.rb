# Sevii's Pokedex (games/sevii/pokedex.rb), over stand-ins shaped as Sevii's: its nest page names the places the
# encounter data puts the species in, each map by the point of its own position on the region's own grid, where the
# page draws Hoenn's squares past the 24th column a row down at the left edge; its list says the keys its background
# paints, after its first row.

# Sevii's Pokedex list as pbPokedex runs it: the list window activated, then per pass of its loop a frame (the mod's
# pulse, after Input.update) and the scene's update, which updates the list window.
class SeviiDexStandIn < PokemonPokedexScene
  ROWS = [[1, "Bulbasaur", 7, 69, 1, false], [4, "Charmander", 6, 85, 4, false]].freeze

  def initialize(passes)
    super()
    @passes = passes
    @sprites["pokedex"] = Window_Pokedex.new(ROWS)
    @sprites["pokedex"].active = false
  end

  def pbUpdate; @sprites["pokedex"].update; end

  def pbPokedex
    @sprites["pokedex"].active = true
    @passes.times { PokeAccess::Frame.run_pollers; pbUpdate }
    @sprites["pokedex"].active = false
    :closed
  end
end

class SeviiPokedexTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "pokedex.rb")
  G6 = PokeAccess::PokedexInfoG6
  PLAIN_SQUARES = PokeAccess::DexEntry.method(:lit_squares)
  BOUND = {}

  # The town maps: Kanto (region 0), and Hoenn (region 3), 30 squares wide, Route 124 east of the 24th column and
  # Rustboro City on the square a row below at the left edge, where the page draws Route 124's point; Sootopolis City
  # beside Route 126, and Shoal Cave Low Tide beside Shoal Cave.
  TOWNS = { 0 => ["Kanto", "mapRegion0.png", [[3, 2, "Route 1"], [10, 5, "Viridian Forest"], [4, 8, "Route 22"]]],
            3 => ["Hoenn", "mapRegion3.png", [[24, 6, "Route 124"], [0, 7, "Rustboro City"], [21, 6, "Route 126"],
                                              [22, 6, "Sootopolis City"],
                                              [26, 9, "Shoal Cave", nil, nil, nil, nil, 70],
                                              [27, 9, "Shoal Cave Low Tide"]]] }.freeze
  # The encounter tables by map, each [slots of [species, level]]: Sharpedo (319) on Route 124 (480) and Route 126
  # (481), Snorunt (361) in Shoal Cave (482), Rattata (19) on Kanto's maps 1, 2 and 3.
  ENCOUNTERS = { 480 => [nil, [[[319, 30]]]], 481 => [nil, [[[319, 30]]]], 482 => [nil, [[[361, 25]]]],
                 1 => [nil, [[[19, 3]]]], 2 => [nil, [[[19, 3]]]], 3 => [nil, [[[19, 3]]]] }.freeze
  # Each map's town-map position [region, x, y].
  POSITIONS = { 480 => [3, 24, 6], 481 => [3, 21, 6], 482 => [3, 26, 9], 1 => [0, 10, 5], 2 => [0, 3, 2],
                3 => [0, 4, 8] }.freeze
  # Route 124, Route 126 and Shoal Cave are two squares wide: Route 126 over Sootopolis City's square, Shoal Cave over
  # Low Tide's.
  SIZES = { 480 => [2, "11"], 481 => [2, "11"], 482 => [2, "11"] }.freeze

  test "names the places the species lives in on Hoenn, not those under the squares the page draws a row down" do
    with_sevii_squares { nest([[21, 6], [22, 6], [0, 7], [1, 7]]).pbStartScene(319, 3) }
    assert_equal ["#{bar(319)}. #{places('placeRoute 126, placeRoute 124')}"], SpeakCapture.lines
  end

  test "names each map by the point of its own position, not the places the rest of its size covers" do
    with_sevii_squares { nest([[21, 6], [22, 6]]).pbStartScene(319, 3) }
    refute_match(/Sootopolis/, SpeakCapture.lines.join(" "))
  end

  test "names the places of a region the page draws right as it draws them, in the order of its rows" do
    with_sevii_squares { nest([[3, 2], [10, 5], [4, 8]]).pbStartScene(19, 0) }
    assert_equal ["#{bar(19)}. #{places('placeRoute 1, placeViridian Forest, placeRoute 22')}"], SpeakCapture.lines
  end

  test "a map whose own point is behind a switch still off names no place until the switch is on" do
    with_sevii_squares { nest([]).pbStartScene(361, 3) }
    $game_switches[70] = true
    with_sevii_squares { nest([[2, 10], [3, 10]]).pbStartScene(361, 3) }
    assert_equal [bar(361), "#{bar(361)}. #{places('placeShoal Cave')}"], SpeakCapture.lines
  end

  test "with encounter data it cannot read, names the places under the points the page draws" do
    with_sevii_squares(nil) { nest([[0, 7]]).pbStartScene(319, 3) }
    assert_equal ["#{bar(319)}. #{places('placeRustboro City')}"], SpeakCapture.lines
  end

  test "the list says the keys its background paints, with those the game reads for them now, after its first row" do
    with_controls(:B => [0x58, 0x1B], :F5 => [0x46, 0x74], :L => [0x21], :R => [0x22]) do
      assert_equal :closed, open_list(3)
    end
    hint = keys_hint([0x58, 0x1B], [0x46, 0x74], [0x21], [0x22])
    assert_equal [[false, false], hint], [SpeakCapture.log.map { |l| l[1] }, SpeakCapture.lines[1]]
    assert_match(/\A1\b/, SpeakCapture.lines[0], "the first row, number 1, goes first")
  end

  test "the list's hint names the keys its background paints when the game keeps no controls of its own" do
    open_list(2)
    assert_equal keys_hint([0x58], [0x74], [0x21], [0x22]), SpeakCapture.lines[1]
  end

  test "the list's hint says a button moved with the mod's remap by its new key" do
    PokeAccess::Config.rebinds = { :b => 0x08 }
    open_list(2)
    assert_equal keys_hint([0x08], [0x74], [0x21], [0x22]), SpeakCapture.lines[1]
  end

  test "the list says its hint once per opening" do
    open_list(4)
    open_list(4)
    hint = keys_hint([0x58], [0x74], [0x21], [0x22])
    assert_equal [4, [hint, hint]], [SpeakCapture.lines.length, SpeakCapture.lines.values_at(1, 3)]
  end

  test "with key hints left out, the list says its first row alone" do
    PokeAccess::Config.verbosity = :brief
    open_list(3)
    assert_equal 1, SpeakCapture.lines.length
  end

  private

  # The mod's text for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The nest page with the town maps and the given squares lit, as the game draws them.
  def nest(lit)
    self.class.bind
    scene = PokemonNestMapScene.new
    scene.mapdata = TOWNS
    scene.lit = lit
    scene
  end

  # Opens Sevii's Pokedex list for a number of passes of its loop, answering what pbPokedex does.
  def open_list(passes)
    self.class.bind
    SeviiDexStandIn.new(passes).pbPokedex
  end

  # The places line for a list of names.
  def places(list)
    t(:pdx_places, :list => list)
  end

  # What the page says before its places for species sp: the page's name, then its bar as the stand-in paints it.
  def bar(sp)
    "#{t(:pdx_zone, :name => "Especie#{sp}")}. Kanto, Nido de #{sp}"
  end

  # The list's hint for the keys of each button, as virtual-key codes, named as the mod names keys.
  def keys_hint(quit, search, up, down)
    names = lambda do |codes|
      n = codes.map { |c| PokeAccess::ConfigMenu.keyname(c) }
      n.length > 1 ? t(:list_or, :rest => n[0..-2].join(", "), :last => n[-1]) : n[0]
    end
    t(:sv_dex_keys, :quit => names.call(quit), :search => names.call(search), :up => names.call(up),
                    :down => names.call(down))
  end

  # Runs the block with Sevii's nest squares in place, the game's data answering as given (nil: unreadable), and the
  # game's pbFindEncounter; the core's reading is put back after.
  def with_sevii_squares(encounters = ENCOUNTERS)
    self.class.bind
    saved = [:encounters, :position, :size].map { |m| [m, G6.method(m)] }
    G6.define_singleton_method(:encounters) { encounters || raise(IOError, "Data/encounters.dat") }
    G6.define_singleton_method(:position) { |map| POSITIONS[map] }
    G6.define_singleton_method(:size) { |map| SIZES[map] }
    PokeAccess::DexEntry.define_singleton_method(:lit_squares, BOUND[:squares])
    find = { :pbFindEncounter => lambda { |enc, species| enc.any? { |slots| slots.any? { |s| s[0] == species } } } }
    GameFunctions.with(find) { yield }
  ensure
    saved.each { |m, orig| G6.define_singleton_method(m, orig) } if saved
    PokeAccess::DexEntry.define_singleton_method(:lit_squares, PLAIN_SQUARES)
  end

  # Runs the block with the game's Input reading the given keys for each button (its buttonToKey, which FL's Set the
  # Controls feeds), F5 among its buttons; both are taken away after.
  def with_controls(table)
    made = !::Input.const_defined?(:F5, false)
    ::Input.const_set(:F5, 25) if made
    codes = {}
    table.each { |button, keys| codes[::Input.const_get(button)] = keys }
    ::Input.define_singleton_method(:buttonToKey) { |button| codes[button] || [] }
    yield
  ensure
    (class << ::Input; self; end).send(:remove_method, :buttonToKey)
    ::Input.send(:remove_const, :F5) if made
  end

  # Evaluates pokedex.rb once, its list hook bound to the stand-in set for the moment under the game's name; the nest
  # squares it overrides are kept for with_sevii_squares and the core's put back at once, the profile list as it was.
  def self.bind
    return if BOUND[:squares]
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    prior = Object.send(:remove_const, :PokemonPokedexScene)
    Object.const_set(:PokemonPokedexScene, SeviiDexStandIn)
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      BOUND[:squares] = PokeAccess::DexEntry.method(:lit_squares)
    ensure
      Object.send(:remove_const, :PokemonPokedexScene)
      Object.const_set(:PokemonPokedexScene, prior)
      PokeAccess::DexEntry.define_singleton_method(:lit_squares, PLAIN_SQUARES)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.instance_variable_set(:@profiles, profiles)
      PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    end
  end
end
