# Pokemon Z's ball key (games/pokemon_z/ball_key.rb): a wild battle's menu opening ends on the key's hint, said again
# when the ball changes; the fifth command says the ball the battle throws, not the one the panel's icon shows.
class ZBallKeyTest < PokeAccessTest
  # The balls the key can throw, by their ids in Z's item table.
  BALLS = { :POKEBALLCASERA => 822, :SUPERBALLCASERA => 823, :ULTRABALLCASERA => 824,
            :ULTRABALL => 265, :GREATBALL => 266, :POKEBALL => 267 }

  # The command the key moves the cursor to.
  KEY_COMMAND = 4

  # A bag holding the given items.
  class Bag
    def initialize(held); @held = held; end
    def pbHasItem?(sym); @held.include?(sym); end
  end

  # A bag that fails when asked for an item.
  class BrokenBag
    def pbHasItem?(_sym); raise "broken bag"; end
  end

  # A data provider that knows items only by its table, sym => [id, name], nil for an item it lacks.
  class ItemTable
    def initialize(rows); @rows = rows; end
    def item_id(sym); @rows[sym]; end
  end

  test "a wild battle's menu opens on its command, then the hint with the ball the key throws, queued" do
    with_bag(:POKEBALL) { read(menu, 0, false) }
    assert_equal [["Luchar", false], [hint(:POKEBALL), false]], SpeakCapture.log
  end

  test "the key's command says the ball the battle throws, the homemade ones before the Ultra, Great and Poke Ball" do
    { [:POKEBALL, :GREATBALL] => :GREATBALL,
      [:GREATBALL, :ULTRABALL] => :ULTRABALL,
      [:ULTRABALL, :POKEBALLCASERA] => :POKEBALLCASERA,
      [:POKEBALLCASERA, :SUPERBALLCASERA] => :SUPERBALLCASERA,
      [:POKEBALL, :SUPERBALLCASERA, :ULTRABALLCASERA] => :ULTRABALLCASERA }.each do |held, thrown|
      SpeakCapture.clear
      with_bag(*held) { read(menu, KEY_COMMAND, true) }
      assert_equal [[throw_line(thrown), true]], SpeakCapture.log, "holding #{held.inspect}"
    end
  end

  test "a menu that opens on the key's command says that ball, queued, with no hint" do
    with_bag(:POKEBALL) { read(menu, KEY_COMMAND, false) }
    assert_equal [[throw_line(:POKEBALL), false]], SpeakCapture.log
  end

  test "moving through the menu says the command alone" do
    with_bag(:POKEBALL) { read(menu, 1, true) }
    assert_equal [["Mochila", true]], SpeakCapture.log
  end

  test "the menu opening again with the same ball says the command alone" do
    m = menu
    with_bag(:POKEBALL) do
      read(m, 0, false)
      SpeakCapture.clear
      read(m, 0, false)
    end
    assert_equal [["Luchar", false]], SpeakCapture.log
  end

  test "the hint comes back when the ball the key throws changes" do
    m = menu
    with_bag(:ULTRABALL, :POKEBALLCASERA) { read(m, 0, false) }
    SpeakCapture.clear
    with_bag(:ULTRABALL) { read(m, 0, false) }
    assert_equal [["Luchar", false], [hint(:ULTRABALL), false]], SpeakCapture.log
  end

  test "each battle's menu says the hint at its first opening" do
    with_bag(:POKEBALL) do
      read(menu, 0, false)
      SpeakCapture.clear
      read(menu, 0, false)
    end
    assert_equal [["Luchar", false], [hint(:POKEBALL), false]], SpeakCapture.log
  end

  test "with no ball to throw, the menu has no hint and the key's command says nothing" do
    { "an empty bag" => Bag.new([]), "no bag" => nil, "a bag that fails when asked" => BrokenBag.new }.each do |what, bag|
      SpeakCapture.clear
      in_bag(bag) do
        m = menu
        read(m, 0, false)
        read(m, KEY_COMMAND, true)
      end
      assert_equal [["Luchar", false]], SpeakCapture.log, what
    end
  end

  test "a ball the game names blank or not at all is passed over for the next in the order" do
    table = ItemTable.new(:ULTRABALLCASERA => [824, " "], :SUPERBALLCASERA => nil, :POKEBALLCASERA => [822, "Casera"])
    Harness.with_provider(table) do
      with_bag(:ULTRABALLCASERA, :SUPERBALLCASERA, :POKEBALLCASERA) { read(menu, KEY_COMMAND, true) }
    end
    assert_equal [[PokeAccess::I18n.t(:zball_throw, :ball => "Casera"), true]], SpeakCapture.log
  end

  test "a trainer battle's menu, without the key's panel, says its four commands only" do
    with_bag(:POKEBALL) do
      m = menu(false)
      read(m, 0, false)
      read(m, KEY_COMMAND, true)
    end
    assert_equal [["Luchar", false]], SpeakCapture.log
  end

  test "the hint is a key hint, said from the medium verbosity up" do
    said = with_bag(:POKEBALL) do
      vb_levels do
        SpeakCapture.clear
        read(menu, 0, false)
        SpeakCapture.lines
      end
    end
    assert_equal [["Luchar"], ["Luchar", hint(:POKEBALL)], ["Luchar", hint(:POKEBALL)]], said
  end

  test "the hint names the key the player moved the button to" do
    PokeAccess::Config.rebinds = { :y => 0x44 }
    with_bag(:POKEBALL) { read(menu, 0, false) }
    assert_equal [["Luchar", false], [hint(:POKEBALL, "D"), false]], SpeakCapture.log
  end

  private

  # Reads a command of the battle's command menu, as the core's hooks on it do.
  def read(disp, index, interrupt)
    PokeAccess::Battle.read_command(disp, index, interrupt)
  end

  # A command menu with its four labels, drawing the key's panel as in a wild battle, or not as in a trainer's.
  def menu(wild = true)
    win = Object.new
    win.instance_variable_set(:@commands, ["Luchar", "Mochila", "Pokémon", "Huir"])
    disp = Object.new
    disp.instance_variable_set(:@window, win)
    disp.instance_variable_set(:@atajoBall, Object.new) if wild
    disp
  end

  # Runs the block with a bag holding the given items (see in_bag).
  def with_bag(*held, &blk)
    in_bag(Bag.new(held), &blk)
  end

  # Runs the block with $PokemonBag set to bag and Z's balls in the item table, both put back afterwards; answers the
  # block's value.
  def in_bag(bag)
    was = $PokemonBag
    made = BALLS.keys.reject { |sym| PBItems.const_defined?(sym) }
    made.each { |sym| PBItems.const_set(sym, BALLS[sym]) }
    $PokemonBag = bag
    yield
  ensure
    $PokemonBag = was
    (made || []).each { |sym| PBItems.send(:remove_const, sym) }
  end

  # A ball's name as the item table gives it.
  def ball(sym)
    PBItems.getName(BALLS[sym])
  end

  # The hint the menu's opening ends on, for a ball and the key that throws it.
  def hint(sym, key = "S")
    PokeAccess::I18n.t(:zball_hint, :key => key, :ball => ball(sym))
  end

  # What the key's command says for a ball.
  def throw_line(sym)
    PokeAccess::I18n.t(:zball_throw, :ball => ball(sym))
  end
end
