# Marks a menu row carries that its text does not write: whether a bag item is registered to the ready menu (the
# bag's icon) in each shape fangames give it, the icon's frame on an item the quick menu would take, and the party
# menu's field moves, told apart by colour alone.

# The party menu's command list under the name its reader binds, as Essentials defines it.
Window_CommandPokemonColor = Class.new(Window_DrawableCommand) unless defined?(Window_CommandPokemonColor)

# Anil's party commands: a row given as [name, colour key] keeps the key in @colorKey (1 paints it blue, a field
# move), a plain row has none.
class BagRegisteredColorWindow < Window_CommandPokemonColor
  def initialize(commands)
    @colorKey = []
    commands.each_with_index do |c, i|
      next unless c.is_a?(Array)
      @colorKey[i] = c[1]
      commands[i] = c[0]
    end
    super(commands)
  end
end

class MenusBagRegisteredTest < PokeAccessTest
  # The important items of the games these tests stand for; the rest show their count.
  IMPORTANT = [:BICYCLE, :OLDROD, :BIKEVOUCHER]

  test "reads the registered flag from every shape a fangame gives it" do
    shapes.each do |what, (bag, answers)|
      answers.each do |id, want|
        assert_equal want, PokeAccess::Menus.bag_registered?(bag, id), "#{what}: #{id}"
      end
    end
  end

  test "finds nothing registered without a bag" do
    assert_equal false, PokeAccess::Menus.bag_registered?(nil, :BICYCLE)
  end

  test "marks registrable only an important item the game would take that is not registered yet" do
    bag = bag_with(:pbIsRegistered? => lambda { |id| id == :BICYCLE })
    takes = lambda { |id| [:OLDROD, :BICYCLE, :POTION].include?(id) }
    GameFunctions.with(:pbIsImportantItem? => important, :pbCanRegisterItem? => takes) do
      { :OLDROD => true, :BICYCLE => false, :BIKEVOUCHER => false, :POTION => false }.each do |id, want|
        assert_equal want, PokeAccess::Menus.bag_registrable?(bag, id), id.inspect
      end
    end
  end

  test "marks nothing registrable in a game without pbCanRegisterItem?, which draws no such frame" do
    bag = bag_with(:pbIsRegistered? => lambda { |_id| false })
    GameFunctions.with(:pbIsImportantItem? => important) do
      assert_equal false, PokeAccess::Menus.bag_registrable?(bag, :OLDROD)
    end
  end

  test "marks nothing registrable when the game's pbCanRegisterItem? fails" do
    bag = bag_with(:pbIsRegistered? => lambda { |_id| false })
    fails = lambda { |_id| raise "no quick menu" }
    GameFunctions.with(:pbIsImportantItem? => important, :pbCanRegisterItem? => fails) do
      assert_equal false, PokeAccess::Menus.bag_registrable?(bag, :OLDROD)
    end
  end

  test "says a party row painted in the field-move colour as a field move, any other row as it is" do
    win = BagRegisteredColorWindow.new([["Vuelo", 1], ["Corte", 1], "Datos", ["Cambiar", :Red], "Salir"])
    field = PokeAccess::I18n.t(:mn_field_move)
    { 0 => "Vuelo, #{field}", 1 => "Corte, #{field}", 2 => "Datos", 3 => "Cambiar", 4 => "Salir" }.each do |row, said|
      win.index = row
      assert_equal said, PokeAccess::Menus.focused_text(win), "row #{row}"
    end
  end

  test "reads the party rows plain where the list keeps no colour keys" do
    win = BagRegisteredColorWindow.new(["Vuelo", "Datos"])
    win.instance_variable_set(:@colorKey, nil)
    assert_equal "Vuelo", PokeAccess::Menus.focused_text(win)
  end

  test "says nothing for a party row past the last one" do
    win = BagRegisteredColorWindow.new([["Vuelo", 1], "Salir"])
    win.index = 9
    assert_nil PokeAccess::Menus.focused_text(win)
  end

  private

  # The game's pbIsImportantItem?, true for IMPORTANT.
  def important
    lambda { |id| IMPORTANT.include?(id) }
  end

  # A bag answering each method named with its lambda.
  def bag_with(methods)
    bag = Object.new
    methods.each { |name, body| bag.define_singleton_method(name, &body) }
    bag
  end

  # Each shape a bag gives the registered flag, by name: the bag and what it answers per item.
  def shapes
    nothing = lambda { |_id| false }
    slot = lambda { :BICYCLE }
    {
      "the modern predicate" =>
        [bag_with(:registered? => lambda { |id| id == :BICYCLE }), { :BICYCLE => true, :POTION => false }],
      "the modern predicate beside Z's old slot" =>
        [bag_with(:registered? => nothing, :registeredItem => slot), { :BICYCLE => true, :OLDROD => false }],
      "the modern predicate beside a slot holding a list" =>
        [bag_with(:registered? => nothing, :registeredItem => lambda { [:BICYCLE] }), { :BICYCLE => false }],
      "v18's plural predicate" =>
        [bag_with(:pbIsRegistered? => lambda { |id| id == :OLDROD }), { :OLDROD => true, :POTION => false }],
      "a predicate that fails, then gen-6's slot" =>
        [bag_with(:registered? => lambda { |_id| raise "broken" }, :registeredItem => slot),
         { :BICYCLE => true, :POTION => false }],
      "gen-6's single slot" =>
        [bag_with(:registeredItem => slot), { :BICYCLE => true, :OLDROD => false }],
      "a bare plural list" =>
        [bag_with(:registeredItems => lambda { [:BICYCLE, :OLDROD] }), { :OLDROD => true, :POTION => false }],
      "the single slot's instance variable" =>
        [with_ivar(:@registeredItem, :OLDROD), { :OLDROD => true, :BICYCLE => false }],
      "the list's instance variable" =>
        [with_ivar(:@registeredItems, [:OLDROD]), { :OLDROD => true, :POTION => false }],
      "none of them" =>
        [Object.new, { :BICYCLE => false }]
    }
  end

  # A bare object holding value in the instance variable named, as a bag that keeps its registry unexposed.
  def with_ivar(name, value)
    bag = Object.new
    bag.instance_variable_set(name, value)
    bag
  end
end
