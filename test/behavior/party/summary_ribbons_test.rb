# The gen-6 ribbon grid (Awakening's): the focused cell said through drawSelectedRibbon with its place where the level
# keeps it, and a ribbon carried in the grid (ribbonpresel) said as it is picked up, placed or put back.
class SummaryRibbonsTest < PokeAccessTest
  # A cursor sprite of the grid: the cell it is on and whether it shows.
  Cursor = Struct.new(:index, :visible)

  test "says the focused ribbon's name and description, interrupting" do
    PokemonSummaryScene.new.drawSelectedRibbon(2)
    assert_equal [["Cinta2. Descripcion2", true]], SpeakCapture.log
  end

  test "an empty cell, or one whose ribbon the game does not name, is said as empty" do
    with_ribbon_data(:names => { 9 => "" }) do
      [nil, 9].each do |id|
        SpeakCapture.clear
        PokemonSummaryScene.new.drawSelectedRibbon(id)
        assert_equal [[t(:rb_empty), true]], SpeakCapture.log, "ribbon #{id.inspect}"
      end
    end
  end

  test "a ribbon without a description is said by its name alone" do
    with_ribbon_data(:descriptions => { 2 => " " }) { PokemonSummaryScene.new.drawSelectedRibbon(2) }
    assert_equal [["Cinta2", true]], SpeakCapture.log
  end

  test "says where the cell is, four to a row, the rows scrolled away counted" do
    { [0, 0] => [1, 1], [3, 0] => [1, 4], [4, 0] => [2, 1], [5, 2] => [4, 2] }.each do |(index, offset), (row, col)|
      SpeakCapture.clear
      cell_scene(index, offset).drawSelectedRibbon(2)
      assert_equal [["Cinta2. Descripcion2#{t(:pc_pos, :row => row, :col => col)}", true]], SpeakCapture.log,
                   "cell #{index} with #{offset} rows scrolled"
    end
  end

  test "a cursor on no cell says no place" do
    cell_scene(nil, 2).drawSelectedRibbon(2)
    assert_equal [["Cinta2. Descripcion2", true]], SpeakCapture.log
  end

  test "says the ribbon alone in brief, its place from medium, and its description in full" do
    scene = cell_scene(5, 2)
    pos = t(:pc_pos, :row => 4, :col => 2)
    said = vb_levels do
      SpeakCapture.clear
      scene.drawSelectedRibbon(2)
      SpeakCapture.lines
    end
    assert_equal [["Cinta2"], ["Cinta2#{pos}"], ["Cinta2. Descripcion2#{pos}"]], said
  end

  test "the info key keeps the whole cell at any level" do
    PokeAccess::Config.verbosity = :brief
    cell_scene(5, 2).drawSelectedRibbon(2)
    assert_equal "Cinta2. Descripcion2#{t(:pc_pos, :row => 4, :col => 2)}", PokeAccess::Info.info_text
  end

  test "says nothing on the frame it first sees the grid, even over a carried ribbon" do
    scene = grid_scene
    carry_cursor(scene).visible = true
    frame(scene)
    move_cursor(scene).visible = true
    frame(scene)
    frame(scene)
    assert_nothing_spoken
  end

  test "picking a ribbon up says so with the keys that place it, interrupting" do
    scene = ribbon_grid
    pick_up(scene)
    assert_equal [["#{t(:rb_picked)}. #{t(:rb_picked_hint)}", true]], SpeakCapture.log
  end

  test "with the hints left out, picking a ribbon up says so alone" do
    PokeAccess::Config.verbosity = :brief
    scene = ribbon_grid
    pick_up(scene)
    assert_equal [[t(:rb_picked), true]], SpeakCapture.log
  end

  test "placing the ribbon is said behind the cell the drop repaints" do
    scene = ribbon_grid
    pick_up(scene)
    move_cursor(scene).index = 1
    frame(scene)
    SpeakCapture.clear
    drop(scene)
    assert_equal [[t(:rb_placed), false]], SpeakCapture.log
  end

  test "the back button puts the ribbon back, said at once as the carry ends and not as it is pressed" do
    scene = ribbon_grid
    pick_up(scene)
    SpeakCapture.clear
    frame(scene, true)
    drop(scene)
    assert_equal [[t(:rb_cancel), true]], SpeakCapture.log
  end

  test "a back button that cannot be read does not cancel the carry" do
    scene = ribbon_grid
    pick_up(scene)
    SpeakCapture.clear
    frame(scene, :unreadable)
    drop(scene)
    assert_equal [[t(:rb_placed), false]], SpeakCapture.log
  end

  test "a carry after a cancelled one is placed" do
    scene = ribbon_grid
    pick_up(scene)
    frame(scene, true)
    drop(scene)
    pick_up(scene)
    SpeakCapture.clear
    drop(scene)
    assert_equal [[t(:rb_placed), false]], SpeakCapture.log
  end

  test "coming back to the grid empty-handed after leaving it holding a ribbon says nothing" do
    scene = ribbon_grid
    pick_up(scene)
    move_cursor(scene).visible = false
    frame(scene)
    move_cursor(scene).visible = true
    carry_cursor(scene).visible = false
    SpeakCapture.clear
    frame(scene)
    frame(scene)
    assert_nothing_spoken
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A summary scene whose grid cursor is on cell index with offset rows scrolled away; no cursor for a nil index.
  def cell_scene(index, offset)
    scene = PokemonSummaryScene.new
    scene.instance_variable_set(:@sprites, { "ribbonsel" => Cursor.new(index, true) })
    scene.instance_variable_set(:@ribbonOffset, offset)
    scene
  end

  # A summary scene on another page, its grid cursors hidden: the frame that shows them is the first over the grid.
  def grid_scene
    scene = PokemonSummaryScene.new(Poke.build(:name => "Pika"))
    scene.instance_variable_set(:@sprites, { "ribbonsel" => Cursor.new(0, false),
                                             "ribbonpresel" => Cursor.new(0, false) })
    frame(scene)
    scene
  end

  # A summary scene with its ribbon grid shown, the first frame over it gone by and nothing said kept.
  def ribbon_grid
    scene = grid_scene
    move_cursor(scene).visible = true
    frame(scene)
    SpeakCapture.clear
    scene
  end

  def move_cursor(scene); scene.instance_variable_get(:@sprites)["ribbonsel"]; end

  def carry_cursor(scene); scene.instance_variable_get(:@sprites)["ribbonpresel"]; end

  def pick_up(scene)
    carry_cursor(scene).visible = true
    frame(scene)
  end

  def drop(scene)
    carry_cursor(scene).visible = false
    frame(scene)
  end

  # One frame of the ribbon selection: the back button down in it when back is true, and the buttons unreadable
  # (Input.trigger? raising) when it is :unreadable.
  def frame(scene, back = false)
    trigger = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) do |key|
      raise IOError, "the buttons cannot be read" if back == :unreadable
      back == true && key == Input::B
    end
    scene.pbUpdate
  ensure
    Input.define_singleton_method(:trigger?, trigger)
  end

  # Runs the block with PBRibbons answering the names and descriptions given for their ids, the rest as before.
  def with_ribbon_data(opts)
    names = opts[:names] || {}
    descriptions = opts[:descriptions] || {}
    get_name = PBRibbons.method(:getName)
    get_description = PBRibbons.method(:getDescription)
    PBRibbons.define_singleton_method(:getName) { |id| names.key?(id) ? names[id] : get_name.call(id) }
    PBRibbons.define_singleton_method(:getDescription) do |id|
      descriptions.key?(id) ? descriptions[id] : get_description.call(id)
    end
    yield
  ensure
    PBRibbons.define_singleton_method(:getName, get_name)
    PBRibbons.define_singleton_method(:getDescription, get_description)
  end
end
