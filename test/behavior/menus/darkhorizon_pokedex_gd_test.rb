# Dark Horizon's Pokedex (games/darkhorizon/pokedex.rb): a list row says caught by the Shadow Pokemon the dex counts,
# as the BW list paints its ball, and the entry's page 4, which the game draws with no page id, is the MUI Data Page.
class DarkhorizonPokedexGdTest < PokeAccessTest
  INFO = PokeAccess::PokedexInfoV21
  MENUS = PokeAccess::Menus.singleton_class
  PDX = INFO.singleton_class

  # The player as Dark Horizon keeps it: the species seen, the ones caught as Shadow Pokemon, and owned? apart.
  class Player
    def initialize(seen, shadow, owned)
      @seen = seen
      @shadow = shadow
      @owned = owned
    end

    def seen?(species); @seen.include?(species); end
    def owned?(species); @owned.include?(species); end
    def owned_shadow_pokemon?(species); @shadow.include?(species); end
  end

  # A player of another game, with no Shadow Pokemon count to ask.
  PlainPlayer = Struct.new(:seen, :owned) do
    def seen?(species); seen.include?(species); end
    def owned?(species); owned.include?(species); end
  end

  # Evaluates the profile file once, as boot does, and answers the two methods it puts on the shared readers; core's
  # are put back, with the lists of profiles and overrides, so the other tests of the process keep them.
  def self.load_profile
    row = MENUS.instance_method(:dex_list_row)
    page = PDX.instance_method(:page_id)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    path = File.join(Harness::ROOT, "games", "darkhorizon", "pokedex.rb")
    begin
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      [MENUS.instance_method(:dex_list_row), PDX.instance_method(:page_id)]
    ensure
      MENUS.send(:define_method, :dex_list_row, row)
      PDX.send(:define_method, :page_id, page)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  DH_ROW, DH_PAGE_ID = load_profile

  test "a row says caught where the list paints the ball, for a Shadow Pokemon caught, not for one owned? names" do
    player = Player.new([:BULBASAUR, :MAREEP, :ZUBAT], [:MAREEP], [:BULBASAUR])
    rows = [entry(:BULBASAUR, "Bulbasaur", 1), entry(:MAREEP, "Mareep", 179), entry(:ZUBAT, "Zubat", 41)]
    want = ["1, Bulbasaur, #{t(:dex_seen)}", "179, Mareep, #{t(:dex_caught)}", "41, Zubat, #{t(:dex_seen)}"]
    assert_equal want, (0...rows.length).map { |i| focused_row(rows, i, player) }
  end

  test "a row never seen says its number only, and a shift lowers the number by one, as drawItem paints it" do
    player = Player.new([:MAREEP], [:MAREEP], [])
    rows = [entry(:HOOTHOOT, "Hoothoot", 163), entry(:MAREEP, "Mareep", 180, true)]
    said = [0, 1].map { |i| focused_row(rows, i, player) }
    assert_equal ["163, #{t(:dex_unknown)}", "179, Mareep, #{t(:dex_caught)}"], said
  end

  test "a player with no Shadow Pokemon count to ask keeps core's reading, owned? included" do
    rows = [entry(:BULBASAUR, "Bulbasaur", 1)]
    assert_equal "1, Bulbasaur, #{t(:dex_caught)}", focused_row(rows, 0, PlainPlayer.new([:BULBASAUR], [:BULBASAUR]))
  end

  test "page 4 with no page id is the Data Page, and every other page keeps core's name" do
    plain = Object.new
    named = Object.new
    named.instance_variable_set(:@page_id, :page_info)
    got = with_profile { [[plain, 4], [named, 4], [plain, 3], [plain, 1]].map { |s, n| INFO.page_id(s, n) } }
    assert_equal [:page_data, :page_info, :page_forms, :page_info], got
  end

  private

  # A list row as the dex list keeps it in v21: species, name, number and the shift flag.
  def entry(species, name, number, shift = false)
    { :species => species, :name => name, :number => number, :shift => shift }
  end

  # What the list says with its cursor on row i, for player.
  def focused_row(rows, i, player)
    win = Window_Pokedex.new(rows)
    win.index = i
    with_profile { with_player(player) { PokeAccess::Menus.focused_text(win) } }
  end

  # Runs the block with the profile's two methods in place of core's, put back after.
  def with_profile
    row = MENUS.instance_method(:dex_list_row)
    page = PDX.instance_method(:page_id)
    MENUS.send(:define_method, :dex_list_row, DH_ROW)
    PDX.send(:define_method, :page_id, DH_PAGE_ID)
    yield
  ensure
    MENUS.send(:define_method, :dex_list_row, row)
    PDX.send(:define_method, :page_id, page)
  end

  # Runs the block with player as the game's player, put back after.
  def with_player(player)
    had = $player
    $player = player
    yield
  ensure
    $player = had
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
