# The MUI Pokedex data page's move sub-list (Anil, Emerald, Soulstones 2): the focused move as shown with how it is
# learnt, its title when it changes, its window kept from the generic reader; Z-Moves as their rows show them.
class PokedexMovesGdTest < PokeAccessTest
  # The level-up list: Tackle at level 1, Ember on evolving, Growl at level 12.
  LEVEL_UP = [[1, :TACKLE], [0, :EMBER], [12, :GROWL]]

  test "entering the list says its title, the move, its place and its description, queued" do
    page = move_page(LEVEL_UP, 0)
    assert_equal [["LEVEL-UP. #{move_text(:TACKLE)}. #{pos(1, 3)}. descTACKLE", false]], entered(page)
  end

  test "the next move cuts in, the title not said again, a move learnt on evolving marked so" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    assert_equal [["#{move_text(:EMBER)}. #{t(:pdx_mv_evo)}. #{pos(2, 3)}. descEMBER", true]], moved_to(page, 1)
  end

  test "a level row says its level" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    assert_equal [["#{move_text(:GROWL)}. #{t(:dbk_level, :n => 12)}. #{pos(3, 3)}. descGROWL", true]],
                 moved_to(page, 2)
  end

  test "the list's window is claimed, so the generic reader does not say a row's bare name" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    SpeakCapture.clear
    win = page.instance_variable_get(:@sprites)["movecmds"]
    win.index = 1
    win.update
    assert_equal [], SpeakCapture.log
  end

  test "the same row drawn again is not said again" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    SpeakCapture.clear
    page.pbDrawMoveList
    assert_equal [], SpeakCapture.log
  end

  test "coming back from the species that learn it says the move again, queued" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    SpeakCapture.clear
    page.pbChooseSpeciesDataList(:move)
    page.pbDrawMoveList
    assert_equal [["#{move_text(:TACKLE)}. #{pos(1, 3)}. descTACKLE", false]], SpeakCapture.log
  end

  test "another list says its new title first" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    switched = moved_to(page, 0) do
      page.instance_variable_set(:@moveList, [:TACKLE, :EMBER, :GROWL])
      page.instance_variable_set(:@moveListIndex, 2)
    end
    assert_equal [["INHERIT. #{move_text(:TACKLE)}. #{pos(1, 3)}. descTACKLE", true]], switched
  end

  test "a list with nothing in it says its title and that it is empty" do
    assert_equal [["INHERIT. #{t(:row_empty)}", false]], entered(move_page([], 2))
  end

  test "a page without its move window says nothing" do
    page = move_page(LEVEL_UP, 0)
    page.instance_variable_set(:@sprites, {})
    assert_equal [], entered(page)
  end

  test "the info key keeps the focused move whole" do
    page = move_page(LEVEL_UP, 0)
    entered(page)
    moved_to(page, 1)
    assert_equal "#{move_text(:EMBER)}. #{t(:pdx_mv_evo)}. descEMBER", PokeAccess::Info.info_text
  end

  test "a move row at the reading's levels: the name, then its type, mark and place, then the rest" do
    page = move_page([[0, :EMBER], [1, :TACKLE]], 0)
    said = vb_levels { entered(page).map { |text, _i| text } }
    assert_equal [["LEVEL-UP. MoveEMBER"],
                  ["LEVEL-UP. MoveEMBER. #{t(:mv_type, :t => 'TypeTYPE1')}. #{t(:pdx_mv_evo)}. #{pos(1, 2)}"],
                  ["LEVEL-UP. #{move_text(:EMBER)}. #{t(:pdx_mv_evo)}. #{pos(1, 2)}. descEMBER"]], said
  end

  test "a machine list names the machine the player holds" do
    page = move_page([:THUNDERBOLT], 1)
    with_machines([:TM24], [:TM24]) do
      assert_equal [["TM/TUTOR. #{move_text(:THUNDERBOLT)}. ItemTM24. #{pos(1, 1)}. descTHUNDERBOLT", false]],
                   entered(page)
    end
  end

  test "a machine the player does not hold is not named, nor one when there is no bag to ask" do
    page = move_page([:THUNDERBOLT], 1)
    { "not held" => [:POTION], "no bag" => nil }.each do |what, held|
      said = with_machines([:TM24, :POTION], held) { entered(page) }
      assert_equal [["TM/TUTOR. #{move_text(:THUNDERBOLT)}. #{pos(1, 1)}. descTHUNDERBOLT", false]], said, what
    end
  end

  test "an item whose data cannot tell machines apart is not taken for one" do
    page = move_page([:THUNDERBOLT], 1)
    old = Struct.new(:id, :name, :move).new(:OLDDISC, "Disco viejo", :THUNDERBOLT)
    with_machines([old], [:OLDDISC]) do
      assert_equal [["TM/TUTOR. #{move_text(:THUNDERBOLT)}. #{pos(1, 1)}. descTHUNDERBOLT", false]], entered(page)
    end
  end

  test "a machine list whose item data cannot be listed still says the move" do
    page = move_page([:THUNDERBOLT], 1)
    said = with_item_list(lambda { raise NoMethodError, "no item list" }) { entered(page) }
    assert_equal [["TM/TUTOR. #{move_text(:THUNDERBOLT)}. #{pos(1, 1)}. descTHUNDERBOLT", false]], said
  end

  test "a Z-Move of varying power names its crystal and says no category and no PP" do
    with_power_moves do
      page = z_page
      line = "MoveZVARIES. #{t(:mv_type, :t => 'TypeTYPE1')}. #{t(:mv_power, :p => t(:mv_power_var))}. " \
             "#{t(:mv_acc, :a => 100)}"
      assert_equal [["Z-MOVES. #{line}. Normastal Z. #{pos(1, 3)}. descZVARIES", false]], entered(page)
    end
  end

  test "a Z-Move of fixed power keeps its category, still with no PP" do
    with_power_moves do
      page = z_page
      entered(page)
      assert_equal [["#{move_text(:ZFIXED)}. #{pos(2, 3)}. descZFIXED", true]], moved_to(page, 1)
    end
  end

  test "an ordinary move in the Z-Move list says its PP" do
    with_power_moves do
      page = z_page
      entered(page)
      assert_equal [["#{move_text(:TACKLE)}. #{t(:mv_pp, :pp => 10, :tot => 10)}. #{pos(3, 3)}. descTACKLE", true]],
                   moved_to(page, 2)
    end
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def pos(i, n)
    t(:list_pos, :i => i, :n => n)
  end

  # A move's line as the page shows it at full, without PP: name, type, category, power and accuracy.
  def move_text(id)
    "Move#{id}. #{t(:mv_type, :t => 'TypeTYPE1')}. #{t(:cat_physical)}. #{t(:mv_power, :p => '40')}. " \
      "#{t(:mv_acc, :a => 100)}"
  end

  # A data page on the move list number list_index (0 level-up, 1 machines, 2 inherited, 3 Z-Moves) holding
  # moves (the level-up list's rows are [level, move]), its window listing their bare names.
  def move_page(moves, list_index)
    names = moves.map { |m| "Move#{m.is_a?(Array) ? m[1] : m}" }
    page = PokemonPokedexInfo_Scene.new
    page.instance_variable_set(:@sprites, { "movecmds" => Window_CommandPokemon.new(names) })
    page.instance_variable_set(:@moveCommands, names)
    page.instance_variable_set(:@moveList, moves)
    page.instance_variable_set(:@moveListIndex, list_index)
    page
  end

  # The Z-Move list: Normastal Z's move of varying power, one of fixed power, and Tackle.
  def z_page
    page = move_page([:ZVARIES, :ZFIXED, :TACKLE], 3)
    page.instance_variable_set(:@zcrystals, [Struct.new(:zmove, :name).new(:ZVARIES, "Normastal Z")])
    page
  end

  # What entering the page's list says.
  def entered(page)
    page.pbChooseMove
    SpeakCapture.clear
    page.pbDrawMoveList
    SpeakCapture.log.dup
  end

  # What moving the list's cursor to index says, after the block changes the page.
  def moved_to(page, index)
    SpeakCapture.clear
    yield if block_given?
    page.instance_variable_get(:@sprites)["movecmds"].index = index
    page.pbDrawMoveList
    SpeakCapture.log.dup
  end

  # Runs the block with GameData::Item listing items (by id, a TM teaching Thunderbolt, or as item data) and the bag
  # holding held, or no bag at all for nil.
  def with_machines(items, held)
    had_bag = $bag
    $bag = held ? Object.new : nil
    $bag.define_singleton_method(:has?) { |id| held.include?(id) } if held
    listed = items.map { |i| i.is_a?(Symbol) ? GameData::Item.new(i) : i }
    with_item_list(lambda { |&b| listed.each(&b) }) { yield }
  ensure
    $bag = had_bag
  end

  # Runs the block with GameData::Item.each, which the stub does not have, answering as body.
  def with_item_list(body)
    GameData::Item.define_singleton_method(:each, &body)
    yield
  ensure
    GameData::Item.singleton_class.send(:remove_method, :each)
  end

  # Runs the block with the moves whose id starts with Z as power moves (ZVARIES of varying power) and every move's
  # total PP at 10.
  def with_power_moves
    GameData::Move.class_eval do
      def powerMove?; @id.to_s.start_with?("Z"); end
      alias_method :pdx_z_power, :power
      def power; @id == :ZVARIES ? 1 : pdx_z_power; end
      def total_pp; 10; end
    end
    yield
  ensure
    GameData::Move.class_eval do
      remove_method :powerMove?
      remove_method :total_pp
      alias_method :power, :pdx_z_power
      remove_method :pdx_z_power
    end
  end
end
