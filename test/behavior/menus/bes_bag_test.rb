# Essentials BES's bag (plugins/bes_bag.rb): beside a machine the screen paints a card with its move's type, category,
# power, accuracy and PP and a ball per team member, lit for those that can learn it. Those are marks of the machine's
# row from the bag reading's medium level, and the whole row's for Ctrl+T; a bag that paints no card, and any other
# item, get none.

# A team member as the card's balls ask the game: whether its species learns a move, asked of the game's data files.
BesBagMember = Struct.new(:name, :species, :form, :egg, :learns) do
  def isEgg?; egg; end

  def isCompatibleWithMove?(move)
    BesBagTest.asked.push([name, move])
    learns.include?(move)
  end
end

class BesBagTest < PokeAccessTest
  T = PokeAccess::I18n
  SURF = 58
  MACHINES = { :TM01 => SURF }.freeze
  PIKACHU = BesBagMember.new("Pikachu", 25, 0, false, [SURF])
  ONIX = BesBagMember.new("Onix", 95, 0, false, [])

  def self.asked; @asked ||= []; end

  # The bag: a machine and a potion in the pocket, the machine named with its move as the mart adapter does.
  class Bag
    attr_reader :pockets
    def initialize; @pockets = { 1 => [[:TM01, 1], [:POTION, 3]] }; end
  end

  class Adapter
    def getDisplayName(item); item == :TM01 ? "MT01 Surf" : item.to_s; end
    def getDescription(_item); ""; end
  end

  class ItemList
    attr_accessor :index
    def initialize; @bag = Bag.new; @adapter = Adapter.new; @index = 0; end
    def pocket; 1; end
    def itemCount; @bag.pockets[1].length + 1; end
  end

  # The scene that paints the card, held under the game's name while a test runs.
  class CardScene
    def drawTMInfo(_item); end
  end

  def setup
    super
    @was_scene = Object.const_defined?(:PokemonBag_Scene) ? Object.send(:remove_const, :PokemonBag_Scene) : nil
    Object.const_set(:PokemonBag_Scene, CardScene)
    @was_machine = PokeAccess::Info.method(:machine_move)
    PokeAccess::Info.define_singleton_method(:machine_move) { |id| MACHINES[id] }
    @was_trainer = $Trainer
    team(PIKACHU, ONIX)
    BesBagTest.asked.clear
  end

  def teardown
    $Trainer = @was_trainer
    PokeAccess::Info.define_singleton_method(:machine_move, @was_machine)
    Object.send(:remove_const, :PokemonBag_Scene) if Object.const_defined?(:PokemonBag_Scene)
    Object.const_set(:PokemonBag_Scene, @was_scene) if @was_scene
    super
  end

  test "the plugin puts its decorator among the bag's, once" do
    decorators = PokeAccess::Menus.bag_decorators
    assert_equal 1, decorators.select { |d| d.equal?(PokeAccess::BesBag) }.length
  end

  test "a machine's row says its move's card and who can learn it, ahead of its place" do
    want = ["MT01 Surf: 1", T.t(:mv_type, :t => "Tipo2"), T.t(:cat_special), T.t(:mv_power, :p => "98"),
            T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 15, :tot => 15), T.t(:tut_can_list, :names => "Pikachu"),
            list_place(1, 3)]
    assert_equal want.join(", "), row(0)
  end

  test "any other item's row is the bag's own" do
    assert_equal "POTION: 3, #{list_place(2, 3)}", row(1)
    assert_equal [], PokeAccess::BesBag.marks(Bag.new, :POTION)
  end

  test "the marks are left out at brief verbosity and kept for Ctrl+T" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "MT01 Surf: 1", row(0)
    assert_includes PokeAccess::Info.row_text, T.t(:tut_can_list, :names => "Pikachu")
    assert_includes PokeAccess::Info.row_text, T.t(:mv_pp, :pp => 15, :tot => 15)
  end

  test "a move with no power and no accuracy says so in words" do
    with_figures(:move_power => 0, :move_accuracy => 0) do
      line = row(0)
      assert_includes line, T.t(:mv_power, :p => T.t(:mv_power_none))
      assert_includes line, T.t(:mv_acc, :a => T.t(:mv_acc_perfect))
    end
  end

  test "a figure the data lacks is left out" do
    with_figures(:move_power => nil, :move_category => nil, :move_total_pp => nil) do
      line = row(0)
      assert_includes line, T.t(:mv_type, :t => "Tipo2")
      assert_includes line, T.t(:mv_acc, :a => 100)
      refute_match(/Potencia|PP|especial/, line.sub("MT01 Surf", ""))
    end
  end

  test "a type the data names with nothing is left out, and a move with a single PP is said" do
    with_figures(:move_type_name => "", :move_total_pp => 1) do
      line = row(0)
      refute_includes line, T.t(:mv_type, :t => "")
      assert_includes line, T.t(:mv_pp, :pp => 1, :tot => 1)
    end
  end

  test "a member renamed in place is said by its new name" do
    nick = BesBagMember.new("Pikachu", 25, 0, false, [SURF])
    team(nick)
    assert_includes row(0), T.t(:tut_can_list, :names => "Pikachu")
    nick.name = "Rayito"
    assert_includes row(0), T.t(:tut_can_list, :names => "Rayito")
  end

  test "a team that nobody on can learn the move says that nobody can" do
    team(ONIX)
    assert_includes row(0), T.t(:tut_nobody)
  end

  test "an egg is no learner, and a member's nickname is what is said" do
    egg = BesBagMember.new("Huevo", 25, 0, true, [SURF])
    nick = BesBagMember.new("Rayito", 25, 0, false, [SURF])
    team(egg, nick, ONIX)
    assert_includes row(0), T.t(:tut_can_list, :names => "Rayito")
  end

  test "the game is asked once for each member while the team and the machine stay, not every frame" do
    5.times { PokeAccess::Menus.bag_witness(ItemList.new, 0) }
    row(0)
    assert_equal [["Pikachu", SURF], ["Onix", SURF]], BesBagTest.asked
  end

  test "another team is asked again, and the witness changes with it" do
    list = ItemList.new
    before = PokeAccess::Menus.bag_witness(list, 0)
    team(ONIX)
    after = PokeAccess::Menus.bag_witness(list, 0)
    refute_equal before[2], after[2]
    assert_equal [["Pikachu", SURF], ["Onix", SURF], ["Onix", SURF]], BesBagTest.asked
  end

  test "the witness of an item that is no machine has no marks" do
    assert_equal [], PokeAccess::Menus.bag_witness(ItemList.new, 1)[2]
  end

  test "a bag scene that paints no card gets no marks" do
    Object.send(:remove_const, :PokemonBag_Scene)
    Object.const_set(:PokemonBag_Scene, Class.new)
    assert_equal [], PokeAccess::BesBag.marks(Bag.new, :TM01)
    assert_equal "MT01 Surf: 1, #{list_place(1, 3)}", row(0)
  end

  test "a game without the bag scene gets no marks either" do
    Object.send(:remove_const, :PokemonBag_Scene)
    assert_equal [], PokeAccess::BesBag.marks(Bag.new, :TM01)
  end

  test "a team that cannot be read gets the card alone" do
    $Trainer = nil
    line = row(0)
    assert_includes line, T.t(:mv_pp, :pp => 15, :tot => 15)
    refute_includes line, T.t(:tut_nobody)
  end

  test "the decorator leaves the item's name as the game gives it" do
    assert_nil PokeAccess::BesBag.name(Adapter.new, :TM01)
  end

  private

  def team(*members)
    $Trainer = Struct.new(:party).new(members)
  end

  def row(index)
    PokeAccess::Menus.bag_row(ItemList.new, index)
  end

  def with_figures(figures)
    data = PokeAccess::Data
    was = figures.keys.map { |name| [name, data.method(name)] }
    figures.each { |name, value| data.define_singleton_method(name) { |_id| value } }
    PokeAccess::BesBag.reset
    yield
  ensure
    was.each { |name, method| data.define_singleton_method(name, method) }
    PokeAccess::BesBag.reset
  end
end
