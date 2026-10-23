# The move line every screen says (MoveInfo): the damage category as one word right after the type, as the icon sits
# beside it, the power and accuracy words, and where each gen-6 move object keeps its category.
class MoveCategoryTest < PokeAccessTest
  T = PokeAccess::I18n
  MoveInfo = PokeAccess::MoveInfo

  test "says the category right after the type, then power, accuracy and pp" do
    line = MoveInfo.line("Rayo", "Electrico", 90, 100, :cat => MoveInfo.category_word(1), :pp => 15, :total_pp => 15)
    assert_equal ["Rayo", T.t(:mv_type, :t => "Electrico"), T.t(:cat_special), T.t(:mv_power, :p => "90"),
                  T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". "), line
  end

  test "says a game's note on the type right after the type, before the category" do
    line = MoveInfo.line("Rayo", "Electrico", 90, 100, :note => "Nota", :cat => MoveInfo.category_word(1))
    assert_equal ["Rayo", T.t(:mv_type, :t => "Electrico"), "Nota", T.t(:cat_special), T.t(:mv_power, :p => "90"),
                  T.t(:mv_acc, :a => 100)].join(". "), line
  end

  test "a reading asks the note for the move's name, and says it only in full" do
    asked = []
    with_type_note(lambda { |reading, name| asked.push([reading, name]); "Nota" }) do
      typed = "Rayo. #{T.t(:mv_type, :t => 'Electrico')}"
      assert_equal ["Rayo", typed, "#{typed}. Nota"], vb_levels { MoveInfo.leveled(:summary_move, "Rayo", "Electrico", nil, nil) }
    end
    assert_equal [[:summary_move, "Rayo"]], asked, "asked only where it is said"
  end

  test "the stock screens paint no note beside a move's type" do
    assert_nil MoveInfo.type_note(:summary_move, "Rayo")
  end

  test "words the three category numbers and nothing else" do
    { 0 => T.t(:cat_physical), 1 => T.t(:cat_special), 2 => T.t(:cat_status) }.each do |c, word|
      assert_equal word, MoveInfo.category_word(c), "category #{c}"
    end
    [nil, 3, :PHYSICAL, "1"].each { |c| assert_nil MoveInfo.category_word(c), "for #{c.inspect}" }
  end

  test "reads the rest without a gap when there is no category to tell" do
    rest = ["Rayo", T.t(:mv_type, :t => "Electrico"), T.t(:mv_power, :p => "90"), T.t(:mv_acc, :a => 100)].join(". ")
    [nil, ""].each do |cat|
      assert_equal rest, MoveInfo.line("Rayo", "Electrico", 90, 100, :cat => cat), "category #{cat.inspect}"
    end
  end

  test "says a power of 0 as no damage and of 1 as variable" do
    { 0 => T.t(:mv_power_none), -1 => T.t(:mv_power_none), 1 => T.t(:mv_power_var), 90 => "90" }.each do |power, word|
      assert_equal "Rayo. #{T.t(:mv_power, :p => word)}", MoveInfo.line("Rayo", nil, power, nil), "power #{power}"
    end
  end

  test "says an accuracy of 0 as never misses" do
    { 0 => T.t(:mv_acc_perfect), 1 => 1, 100 => 100 }.each do |acc, word|
      assert_equal "Rayo. #{T.t(:mv_acc, :a => word)}", MoveInfo.line("Rayo", nil, nil, acc), "accuracy #{acc}"
    end
  end

  test "ends with the description, and says pp only with its total" do
    assert_equal "Rayo. #{T.t(:mv_pp, :pp => 5, :tot => 10)}. Puede paralizar.",
                 MoveInfo.line("Rayo", nil, nil, nil, :pp => 5, :total_pp => 10, :desc => "Puede paralizar.")
    assert_equal "Rayo", MoveInfo.line("Rayo", "", nil, nil, :pp => 5, :desc => ""),
                 "no total, an empty type and description"
  end

  test "takes a party move's category from the move data, as it keeps none" do
    party_move = Struct.new(:id, :pp, :totalpp).new(4, 10, 10)
    assert_equal 1, MoveInfo.category_of(party_move), "PBMoveData's for move 4"
  end

  test "takes a gen-6 battle move's category from its @category, which has no reader, over the move data" do
    battle_move = Object.new
    battle_move.instance_variable_set(:@category, 2)
    def battle_move.id; 3; end
    assert_equal 2, MoveInfo.category_of(battle_move)
  end

  test "takes a move's own category answer first" do
    move = Struct.new(:id, :category).new(4, 0)
    move.instance_variable_set(:@category, 2)
    assert_equal 0, MoveInfo.category_of(move)
  end

  test "counts the Reborn engine's category symbols as the same numbers" do
    { :physical => 0, :special => 1, :status => 2, :other => nil }.each do |sym, c|
      move = Struct.new(:id, :category).new(:TACKLE, sym)
      if c
        assert_equal c, MoveInfo.category_of(move), "for #{sym}"
      else
        assert_nil MoveInfo.category_of(move), "for #{sym}"
      end
    end
  end

  test "the info key says it after the type" do
    party_move = Struct.new(:id, :pp, :totalpp).new(4, 10, 10)
    assert_equal ["Mov4", T.t(:mv_type, :t => "Tipo2"), T.t(:cat_special), T.t(:mv_power, :p => "44"),
                  T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 10, :tot => 10)].join(". "),
                 PokeAccess::Info.move_info(party_move)
  end

  test "the gen-6 fight menu says it after the type" do
    move = Object.new
    move.instance_variable_set(:@category, 2)
    def move.id; 7; end
    def move.name; "Gruñido"; end
    def move.type; 0; end
    def move.pp; 30; end
    def move.totalpp; 40; end
    disp = Object.new
    disp.instance_variable_set(:@battler, Struct.new(:moves).new([move]))
    disp.instance_variable_set(:@index, 0)
    PokeAccess::Battle.read_fight_move(disp)
    line = ["Gruñido", T.t(:mv_type, :t => "Tipo0"), T.t(:cat_status), T.t(:mv_pp, :pp => 30, :tot => 40)]
    assert_equal [[line.join(". "), true]], SpeakCapture.log
  end

  test "the gen-6 relearner line carries it" do
    assert_equal ["Mov5", T.t(:mv_type, :t => "Tipo0"), T.t(:cat_status), T.t(:mv_power, :p => "45"),
                  T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". "),
                 MoveInfo.by_id_via_data(5)
  end

  test "the relearner line says the type from medium and the category, figures and pp only in full" do
    full = MoveInfo.by_id_via_data(5)
    assert_equal ["Mov5", "Mov5. #{T.t(:mv_type, :t => "Tipo0")}", full],
                 vb_levels { MoveInfo.by_id_via_data(5, :learn_move) }
  end

  test "the relearner line says the total pp only where the move data has one" do
    { 15 => ". #{T.t(:mv_pp, :pp => 15, :tot => 15)}", 1 => ". #{T.t(:mv_pp, :pp => 1, :tot => 1)}", 0 => "",
      nil => "", "5" => "" }.each do |total, tail|
      with_move_data(:HYPNOSIS, :name => "Hipnosis", :total_pp => total) do
        assert_equal "Hipnosis#{tail}", MoveInfo.by_id_via_data(:HYPNOSIS), "total pp #{total.inspect}"
      end
    end
  end

  test "the relearner has no line for a move the data cannot name" do
    with_move_data(:NONAME, :name => "") { assert_nil MoveInfo.by_id_via_data(:NONAME), "an empty name" }
    with_move_data(:NONAME, :name => nil) { assert_nil MoveInfo.by_id_via_data(:NONAME), "no name" }
  end

  test "the relearner line ends with the data's description" do
    with_move_data(:HYPNOSIS, :name => "Hipnosis", :description => "Duerme al rival.") do
      assert_equal "Hipnosis. Duerme al rival.", MoveInfo.by_id_via_data(:HYPNOSIS)
    end
  end

  private

  # Runs the block with the move data answering for id alone, from fields (:name, :type, :power, :accuracy,
  # :total_pp, :category, :description), as an engine's data provider would; a field left out answers nil.
  def with_move_data(id, fields)
    provider = Object.new
    { :move_name => :name, :move_type_name => :type, :move_power => :power, :move_accuracy => :accuracy,
      :move_total_pp => :total_pp, :move_category => :category, :move_description => :description }.each do |meth, key|
      provider.define_singleton_method(meth) { |asked| asked == id ? fields[key] : nil }
    end
    Harness.with_provider(provider) { yield }
  end

  # Runs the block with MoveInfo.type_note answering through note, the stock one put back after.
  def with_type_note(note)
    meta = class << MoveInfo; self; end
    stock = MoveInfo.method(:type_note)
    meta.send(:define_method, :type_note) { |reading, name| note.call(reading, name) }
    yield
  ensure
    meta.send(:define_method, :type_note, stock)
  end
end
