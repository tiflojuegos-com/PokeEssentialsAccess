# Anil's Monotype type picker (games/anil/monotype.rb): the painted title as the list opens, then the focused display
# row ([name, symbol, starters], not a type id), and the option past the rows as the other list or the way back.

# MonotypeMenu::MonotypeMenu_Scene reduced to the calls the game's makes, its title and list painted by private
# methods.
module MonotypeMenu
  class MonotypeMenu_Scene
    def initialize(type_list, primary_list)
      @type_list = type_list
      @primary_list = primary_list
    end

    def pbStartScene
      @index = 0
      configure_menu
      pbRedrawList
      :started
    end

    # The selection loop, reduced to the moves it makes: each one redraws the list.
    def pbSelectElement(moves)
      moves.each do |i|
        @index = i
        pbRedrawList
      end
      @index
    end

    private

    def configure_menu
      @menu_size = @type_list.length + 1
      create_overlay_title
    end

    def create_overlay_title
      pbDrawTextPositions(nil, [["Elige un tipo Monotype", 256, 26]])
      :title_drawn
    end

    def pbRedrawList; :list_drawn; end
  end
end

# The runner loads another profile, so the file is evaluated here over the stand-in; its Game.define block names Anil
# a profile of this process too, and the list of profiles is put back after.
monotype_path = File.join(Harness::ROOT, "games", "anil", "monotype.rb")
monotype_profiles = PokeAccess::Game.profiles.dup
eval(Harness.source(monotype_path), TOPLEVEL_BINDING, monotype_path)
PokeAccess::Game.profiles.replace(monotype_profiles)

class MonotypeTest < PokeAccessTest
  Mono = PokeAccess::AnilMonotype
  ROWS = [["Planta", :GRASS, [:SNOVER]], ["Fuego", :FIRE, [:MAGBY]]]
  TITLE = "Elige un tipo Monotype"

  test "a row is named by its display name, the first of [name, symbol, starters]" do
    assert_equal "Planta", Mono.type_name(ROWS[0])
  end

  test "an entry that is not a row is named by its own name, else as it is" do
    { Struct.new(:name).new("Agua") => "Agua", "Hielo" => "Hielo" }.each do |entry, want|
      assert_equal want, Mono.type_name(entry), "for #{entry.inspect}"
    end
  end

  test "the focused row is said as its type" do
    assert_equal PokeAccess::I18n.t(:mono_type, :type => "Fuego"), Mono.text(picker(1, true))
  end

  test "the option past the rows offers the other list from the recommended one, else the way back" do
    { true => :mono_other, false => :mono_back }.each do |primary, key|
      assert_equal PokeAccess::I18n.t(key), Mono.text(picker(ROWS.length, primary)), "from the primary list: #{primary}"
    end
  end

  test "with no rows, no cursor or a row that cannot be named there is nothing to say" do
    unnamed = Object.new
    def unnamed.name; raise IOError, "unreadable row"; end
    { "no rows" => World.stub_scene(:@index => 0, :@primary_list => true),
      "no cursor" => World.stub_scene(:@type_list => ROWS, :@primary_list => true),
      "a row whose name raises" => World.stub_scene(:@type_list => [unnamed], :@index => 0, :@primary_list => true) }.each do |what, scene|
      assert_nil Mono.text(scene), what
      Mono.read(scene)
    end
    assert_nothing_spoken "nor does the list's read"
  end

  test "opening says the list's painted title, then queues its first row" do
    MonotypeMenu::MonotypeMenu_Scene.new(ROWS, true).pbStartScene
    assert_equal [[TITLE, true], [PokeAccess::I18n.t(:mono_type, :type => "Planta"), false]], SpeakCapture.log
  end

  test "a move says the focused row, interrupting" do
    scene = opened
    scene.pbSelectElement([1])
    assert_equal [[PokeAccess::I18n.t(:mono_type, :type => "Fuego"), true]], SpeakCapture.log
  end

  test "a redraw that changed nothing stays quiet" do
    scene = opened
    scene.pbSelectElement([1])
    SpeakCapture.clear
    scene.pbSelectElement([1])
    assert_nothing_spoken
  end

  test "the option past the rows is read from the list too" do
    scene = opened
    scene.pbSelectElement([ROWS.length])
    assert_equal [[PokeAccess::I18n.t(:mono_other), true]], SpeakCapture.log
  end

  test "the hooked screen keeps its own return values" do
    scene = MonotypeMenu::MonotypeMenu_Scene.new(ROWS, true)
    assert_equal :started, scene.pbStartScene
    assert_equal 1, scene.pbSelectElement([1])
    assert_equal :title_drawn, scene.send(:create_overlay_title)
  end

  test "a title that paints nothing is not said, and its value passes through" do
    assert_equal :nothing_painted, Mono.title { :nothing_painted }
    assert_nothing_spoken
  end

  private

  # The picker's state: the rows, the cursor at index and which of the two lists is showing.
  def picker(index, primary)
    World.stub_scene(:@type_list => ROWS, :@index => index, :@primary_list => primary)
  end

  # The recommended list, opened, with what it said cleared.
  def opened
    scene = MonotypeMenu::MonotypeMenu_Scene.new(ROWS, true)
    scene.pbStartScene
    SpeakCapture.clear
    scene
  end
end
