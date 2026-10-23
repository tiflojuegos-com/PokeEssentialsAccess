# The v22 summary (UI::PokemonSummaryVisuals): each page said once on arrival under its handler's name, a switch of
# Pokemon led by the new one's glance, and the focused move and ribbon said as their cursors move.
class SummaryV22GdTest < PokeAccessTest
  # A move as the v22 Pokemon holds it.
  Move = Struct.new(:id, :name, :pp, :total_pp)
  # A move being learned, as v22 keeps it: an object with its id.
  NewMove = Struct.new(:id)

  test "switching Pokemon leads the page with the new one's glance, in one interrupting line" do
    vis = summary(party, :memo)
    vis.set_party_index(1)
    assert_equal [true], SpeakCapture.log.map { |_text, interrupt| interrupt }, "one line, interrupting"
    assert_spoken_once(/\A#{Regexp.escape(glance("Char", 25, 33, 44))}\.* #{Regexp.escape(memo)}\z/)
  end

  test "switching back is said again" do
    vis = summary(party, :memo)
    vis.set_party_index(1)
    SpeakCapture.clear
    vis.set_party_index(0)
    assert_spoken_once(/\A#{Regexp.escape(glance("Bulba", 12, 22, 22))}\.* #{Regexp.escape(memo)}\z/)
  end

  test "a switch's glance and page are said as sentences, with no second period between them" do
    vis = summary(party, :memo)
    vis.set_party_index(1)
    assert_equal [["#{glance('Char', 25, 33, 44)} #{memo}", true]], SpeakCapture.log
  end

  test "switching points the info key at the new Pokemon" do
    summary(party, :memo).set_party_index(1)
    assert_equal "#{glance('Char', 25, 33, 44)} ♂.", PokeAccess::Info.info_text
  end

  test "turning a page says it, interrupting, with no glance" do
    vis = summary(party, :info)
    vis.go_to_next_page(:memo)
    assert_equal [[memo, true]], SpeakCapture.log
  end

  test "a redraw of the page said says nothing" do
    vis = summary(party, :info)
    vis.go_to_next_page(:memo)
    SpeakCapture.clear
    vis.refresh
    assert_nothing_spoken
  end

  test "each page says its own text for the Pokemon shown" do
    stats = t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    type = t(:mv_type, :t => "TypeTYPE1")
    moves = t(:sm_moves, :list => "Placaje. #{type}. #{t(:mv_pp, :pp => 30, :tot => 35)}, " \
                                  "Ascuas. #{type}. #{t(:mv_pp, :pp => 20, :tot => 25)}")
    { :info => "#{t(:sum_data_of, :name => 'Char ♂', :level => 25)} #{t(:sum_item, :i => t(:sum_none))} " \
               "#{t(:sum_ot, :name => t(:sum_loaned))} #{t(:sum_id, :id => t(:pdx_unknown_short))}",
      :skills => "#{t(:sm_stats)}. #{stats} #{t(:sum_ability, :a => 'Ability1')}",
      :moves => moves, :detailed_moves => moves, :ribbons => t(:sm_ribbons, :n => 2) }.each do |page, text|
      summary([fighter], :memo).go_to_next_page(page)
      assert_equal [[text, true]], SpeakCapture.log, "page #{page}"
    end
  end

  test "a page is said under the name its handler gives it" do
    with_const(UI::PokemonSummaryVisuals, :PAGE_HANDLERS, :memo => { :name => proc { "Memorias" } }) do
      summary(party, :info).go_to_next_page(:memo)
    end
    assert_equal [["Memorias. #{memo}", true]], SpeakCapture.log
  end

  test "a page it has no text for is said by its handler's name alone" do
    with_const(UI::PokemonSummaryVisuals, :PAGE_HANDLERS, :contest => { :name => proc { "Concursos" } }) do
      summary(party, :info).go_to_next_page(:contest)
    end
    assert_equal [["Concursos", true]], SpeakCapture.log
  end

  test "a handler with no name, a name that fails or no table at all gives the page none" do
    { "no name" => {}, "a name that fails" => { :name => proc { raise ArgumentError, "no name" } },
      "no table" => "Memorias" }.each do |what, handler|
      SpeakCapture.clear
      with_const(UI::PokemonSummaryVisuals, :PAGE_HANDLERS, :memo => handler) do
        summary(party, :info).go_to_next_page(:memo)
      end
      assert_equal [[memo, true]], SpeakCapture.log, what
    end
  end

  test "with no Pokemon shown, says nothing" do
    UI::PokemonSummaryVisuals.new([nil], 0).refresh
    assert_nothing_spoken
  end

  test "a switch to a Pokemon whose data cannot be read says nothing" do
    members = party
    members[1].define_singleton_method(:level) { raise NoMethodError, "no level" }
    summary(members, :memo).set_party_index(1)
    assert_nothing_spoken
  end

  test "the focused move is said in full as the cursor reaches it, once" do
    vis = summary([fighter], :moves)
    [1, 1, 0].each do |index|
      vis.instance_variable_set(:@move_index, index)
      vis.refresh_move_cursor
    end
    assert_equal [[known_move("Ascuas", 20, 25, "descEMBER"), true],
                  [known_move("Placaje", 30, 35, "descTACKLE"), true]], SpeakCapture.log
  end

  test "a move cursor on no slot says nothing" do
    summary([fighter], :moves).refresh_move_cursor
    assert_nothing_spoken
  end

  test "the extra slot says the move being learned, kept as an id or as a move" do
    with_const(Object, :Pokemon, max_moves(4)) do
      [:THUNDERBOLT, NewMove.new(:THUNDERBOLT)].each do |learning|
        vis = summary([fighter], :moves)
        vis.instance_variable_set(:@new_move, learning)
        vis.instance_variable_set(:@move_index, 4)
        SpeakCapture.clear
        vis.refresh_move_cursor
        assert_equal [["MoveTHUNDERBOLT. #{figures}. descTHUNDERBOLT", true]], SpeakCapture.log, learning.inspect
      end
    end
  end

  test "while a move is being learned, the moves known are still said by their own detail" do
    vis = summary([fighter], :moves)
    vis.instance_variable_set(:@new_move, :THUNDERBOLT)
    vis.instance_variable_set(:@move_index, 1)
    with_const(Object, :Pokemon, max_moves(4)) { vis.refresh_move_cursor }
    assert_equal [[known_move("Ascuas", 20, 25, "descEMBER"), true]], SpeakCapture.log
  end

  test "says the focused ribbon by its name, adding its description in full" do
    said = vb_levels do
      point_ribbon(summary([fighter], :ribbons), 1)
      SpeakCapture.log.dup
    end
    assert_equal [[["RibbonSHOCK", true]], [["RibbonSHOCK", true]], [["RibbonSHOCK. rdescSHOCK", true]]], said
  end

  test "the info key keeps the focused ribbon whole at any level" do
    PokeAccess::Config.verbosity = :brief
    point_ribbon(summary([fighter], :ribbons), 1)
    assert_equal "RibbonSHOCK. rdescSHOCK", PokeAccess::Info.info_text
  end

  test "a ribbon cursor that stays, is on no ribbon or has no Pokemon says nothing" do
    { "the same ribbon again" => lambda { |vis| point_ribbon(vis, 0); SpeakCapture.clear; point_ribbon(vis, 0) },
      "no ribbon index" => lambda { |vis| point_ribbon(vis, nil) },
      "past the last ribbon" => lambda { |vis| point_ribbon(vis, 5) },
      "no Pokemon shown" => lambda { |vis| vis.pokemon = nil; point_ribbon(vis, 1) } }.each do |what, steps|
      steps.call(summary([fighter], :ribbons))
      assert_nothing_spoken what
    end
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # Bulba and Char, the second hurt.
  def party
    [Poke.build(:name => "Bulba", :species => 1, :level => 12, :hp => 22, :totalhp => 22),
     Poke.build(:name => "Char", :species => 4, :level => 25, :hp => 33, :totalhp => 44)]
  end

  # A Pokemon with two moves and two ribbons, which it counts as the game's Pokemon does (numRibbons).
  def fighter
    moves = [Move.new(:TACKLE, "Placaje", 30, 35), Move.new(:EMBER, "Ascuas", 20, 25)]
    pk = Poke.build(:name => "Char", :moves => moves, :ribbons => [:ALERT, :SHOCK])
    pk.define_singleton_method(:numRibbons) { ribbons.length }
    pk
  end

  # What the move reading says of any move between its name and its pp, from the figures the stubs give every move:
  # type TYPE1, physical, power 40, accuracy 100.
  def figures
    [t(:mv_type, :t => "TypeTYPE1"), t(:cat_physical), t(:mv_power, :p => 40), t(:mv_acc, :a => 100)].join(". ")
  end

  # A move the Pokemon knows, said in full: its name, the figures, its pp and its description.
  def known_move(name, pp, total, description)
    "#{name}. #{figures}. #{t(:mv_pp, :pp => pp, :tot => total)}. #{description}"
  end

  # The summary of members opened on page with the first member shown, that page said and nothing said kept.
  def summary(members, page)
    vis = UI::PokemonSummaryVisuals.new(members, 0)
    vis.page = page
    vis.refresh
    SpeakCapture.clear
    vis
  end

  # The ribbon cursor moved to index, as the ribbons page redraws it.
  def point_ribbon(vis, index)
    vis.instance_variable_set(:@ribbon_index, index)
    vis.refresh_ribbon_cursor
  end

  # The glance a switch leads with.
  def glance(name, level, hp, total)
    t(:pk_glance, :name => name, :level => level, :hp => hp, :tot => total)
  end

  # The memo page of a Pokemon with no nature to tell.
  def memo
    "#{t(:sm_memo)}."
  end

  # A stand-in for v22's Pokemon class, holding only its MAX_MOVES.
  def max_moves(n)
    holder = Module.new
    holder.const_set(:MAX_MOVES, n)
    holder
  end

  # Runs the block with owner::name set to value, then puts back whatever was there, or nothing.
  def with_const(owner, name, value)
    had = owner.const_defined?(name, false)
    was = had ? owner.const_get(name, false) : nil
    owner.send(:remove_const, name) if had
    owner.const_set(name, value)
    yield
  ensure
    owner.send(:remove_const, name) if owner.const_defined?(name, false)
    owner.const_set(name, was) if had
  end
end
