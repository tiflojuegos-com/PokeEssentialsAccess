# Reminiscencia's one-page status sheet (games/reminiscencia/summary_extra.rb): the whole sheet as painted, an egg's
# without the species inside, Hidden Power as the sheet works it out, and what a redraw says for the key pressed.

# Only the profile's module is evaluated: its wiring would make the shared summary single-page for every other test.
remin_summary_path = File.join(Harness::ROOT, "games", "reminiscencia", "summary_extra.rb")
eval(Harness.source(remin_summary_path)[/\A.*?(?=^PokeAccess::Summary\.single_page)/m], TOPLEVEL_BINDING,
     remin_summary_path)

class ReminSummaryEggTest < PokeAccessTest
  T = PokeAccess::I18n
  Remi = PokeAccess::RemiSummary
  Move = Struct.new(:id, :pp, :totalpp)

  MALE = " \xE2\x99\x82"

  # The six rows of the sheet's stat columns, as it lists them.
  STAT_LABELS = [:st_hp, :st_atk, :st_def, :st_spatk, :st_spdef, :st_speed]

  test "a hatched Pokemon's sheet reads in the order painted: head, nature, stats, stars, EVs, ability, moves, keys" do
    assert_equal sheet("Chispa#{MALE}, Especie25"), Remi.estado(Object.new, chispa)
  end

  test "an egg's sheet names the egg and never the species inside" do
    egg = chispa(:name => "Huevo")
    def egg.egg?; true; end
    def egg.isEgg?; true; end
    assert_equal sheet("Huevo#{MALE}"), Remi.estado(Object.new, egg)
  end

  test "the head names the types the icons show and the star a shiny one has, and no level" do
    pk = chispa(:level => 77, :shiny => true)
    pk.define_singleton_method(:type1) { 13 }
    pk.define_singleton_method(:type2) { 2 }
    head = "Chispa#{MALE}, Especie25, #{T.t(:mv_type, :t => 'Tipo13 Tipo2')}, #{T.t(:pk_shiny)}"
    assert_equal sheet(head), Remi.estado(Object.new, pk)
  end

  test "the stats its nature raises and lowers follow the nature's name" do
    pk = chispa(:nature => 1)
    effect = T.t(:sm_nature_effect, :up => "Estadistica1", :down => "Estadistica2")
    assert_equal sheet("Chispa#{MALE}, Especie25", :nature => "Naturaleza1", :after_nature => [effect]),
                 Remi.estado(Object.new, pk)
  end

  test "the condition follows the nature: fainted with no HP left, else the ailment" do
    assert_equal sheet("Chispa#{MALE}, Especie25", :hp => 0, :after_nature => [T.t(:pk_fainted)]),
                 Remi.estado(Object.new, chispa(:hp => 0))
    assert_equal sheet("Chispa#{MALE}, Especie25", :after_nature => [T.t(:st_sleep)]),
                 Remi.estado(Object.new, chispa(:status => 1))
  end

  test "the condition is said only for no HP or an ailment the game names" do
    { { :hp => 0 } => T.t(:pk_fainted), { :status => 1 } => T.t(:st_sleep), { :status => 5 } => T.t(:st_freeze),
      { :hp => 1 } => nil, { :status => 0 } => nil, { :status => 9 } => nil }.each do |opts, said|
      got = Remi.status_phrase(chispa(opts))
      said ? assert_equal(said, got, opts.inspect) : assert_nil(got, opts.inspect)
    end
  end

  test "the per-species bonus is said in percent after the EVs, the HP the sheet leaves as dashes left out" do
    scene = World.stub_scene(:@bonusHP => 7, :@bonusATK => 10, :@bonusSPD => -5)
    bonus = stat_row(T.t(:rem_sum_bonus), [nil, "10%", "0%", "0%", "0%", "-5%"])
    assert_equal sheet("Chispa#{MALE}, Especie25", :after_evs => [bonus]), Remi.estado(scene, chispa)
  end

  test "the IV column is said as the stars it paints: three from 21, two from 11, one from 1" do
    { 31 => 3, 21 => 3, 20 => 2, 11 => 2, 10 => 1, 1 => 1, 0 => 0 }.each do |iv, stars|
      assert_equal [stars], Remi.iv_stars([iv]), "IV #{iv}"
    end
  end

  test "the held item is named after the ability" do
    assert_equal sheet("Chispa#{MALE}, Especie25", :item => T.t(:sum_item, :i => "Repel")),
                 Remi.estado(Object.new, chispa(:item => 25))
  end

  test "the moves list each move's name, the type its button shows and its PP, past the empty slots" do
    pk = chispa(:moves => [Move.new(33, 35, 35), Move.new(0, 0, 0), Move.new(57, 10, 0)])
    moves = "Mov33. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}, " \
            "Mov57. #{T.t(:mv_type, :t => 'Tipo1')}"
    assert_equal T.t(:sm_moves, :list => moves), Remi.moves_text(pk)
  end

  test "Hidden Power is listed with the type the sheet works out of the IVs" do
    pk = chispa(:moves => [Move.new(33, 35, 35), Move.new(333, 15, 15)])
    moves = "Mov33. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}, " \
            "Mov333. #{T.t(:mv_type, :t => 'Tipo7')}. #{T.t(:mv_pp, :pp => 15, :tot => 15)}"
    with_hidden_power([7, 70]) { assert_equal T.t(:sm_moves, :list => moves), Remi.moves_text(pk) }
  end

  test "Hidden Power keeps the move's own type where the sheet cannot work it out" do
    pk = chispa(:moves => [Move.new(333, 15, 15)])
    moves = "Mov333. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 15, :tot => 15)}"
    GameFunctions.with(:pbHiddenPower => lambda { |_iv| raise "no IVs" }) do
      assert_equal T.t(:sm_moves, :list => moves), Remi.moves_text(pk)
    end
  end

  test "a sheet with no move to list says so" do
    [[], [Move.new(0, 0, 0)]].each do |moves|
      assert_equal T.t(:sm_no_moves), Remi.moves_text(chispa(:moves => moves)), moves.inspect
    end
  end

  test "a focused move slot that is empty or missing says so in the language's words" do
    pk = chispa(:moves => [Move.new(33, 35, 35), Move.new(0, 0, 0)])
    [1, 3].each { |slot| assert_equal T.t(:rem_sum_no_move), Remi.focused_move(pk, slot), "slot #{slot}" }
  end

  test "a focused move is read from its own data" do
    pk = chispa(:moves => [Move.new(33, 35, 35)])
    assert_equal move_line("Mov33", "Tipo1", 73, 35), Remi.focused_move(pk, 0)
  end

  test "a focused Hidden Power gives the type and power the sheet works out, and the info key keeps it whole" do
    pk = chispa(:moves => [Move.new(33, 35, 35), Move.new(333, 15, 15)])
    with_hidden_power([7, 70]) do
      assert_equal move_line("Mov333", "Tipo7", 70, 15), Remi.focused_move(pk, 1)
      assert_equal move_line("Mov333", "Tipo7", 70, 15), PokeAccess::Info.info_text
    end
  end

  test "the ability key says the ability, and the key that reads its description while hints are said" do
    plain = T.t(:rem_sum_ability, :a => "Habilidad1")
    hinted = "#{plain} #{T.t(:rem_sum_ability_hint)}"
    assert_equal [plain, hinted, hinted], vb_levels { Remi.ability_text(chispa) }
  end

  test "a Pokemon whose ability cannot be read says it has none" do
    assert_equal T.t(:rem_sum_no_ability), Remi.ability_text(Struct.new(:name).new("Chispa"))
  end

  test "the keys the sheet paints are said as the player has them now" do
    assert_equal T.t(:rem_sum_keys, :moves => "1, 2, 3, 4", :ability => "T", :back => "X"), Remi.keys_line
    PokeAccess::Config.rebinds = { :key_1 => 0x39, :fast_travel => 0x37 }
    assert_equal T.t(:rem_sum_keys, :moves => "9, 2, 3, 4", :ability => "7", :back => "X"), Remi.keys_line
  end

  test "the keys close the sheet while hints are said, and are left out at brief" do
    whole = sheet("Chispa#{MALE}, Especie25")
    brief = sheet("Chispa#{MALE}, Especie25", :keys => false)
    assert_equal [brief, whole, whole], vb_levels { Remi.estado(Object.new, chispa) }
  end

  test "a redraw with no Pokemon on the sheet says nothing" do
    assert_nil Remi.text(World.stub_scene)
  end

  test "a redraw opens on the whole sheet, and the same state drawn again says nothing" do
    scene = World.stub_scene(:@pokemon => chispa)
    assert_equal [sheet("Chispa#{MALE}, Especie25"), nil], [Remi.text(scene), Remi.text(scene)]
  end

  test "a move focused with its key says that move, and another move its own" do
    pk = chispa(:moves => [Move.new(33, 35, 35), Move.new(57, 10, 10)])
    scene = World.stub_scene(:@pokemon => pk, :@infomove => true, :@chosenmove => 0)
    first = Remi.text(scene)
    scene.instance_variable_set(:@chosenmove, 1)
    assert_equal [move_line("Mov33", "Tipo1", 73, 35), move_line("Mov57", "Tipo1", 97, 10)], [first, Remi.text(scene)]
  end

  test "the ability key's redraw says the ability" do
    scene = World.stub_scene(:@pokemon => chispa, :@infohab => true)
    assert_equal "#{T.t(:rem_sum_ability, :a => 'Habilidad1')} #{T.t(:rem_sum_ability_hint)}", Remi.text(scene)
  end

  test "switching to another Pokemon reads its sheet" do
    scene = World.stub_scene(:@pokemon => chispa)
    Remi.text(scene)
    scene.instance_variable_set(:@pokemon, chispa(:name => "Rayo"))
    assert_equal sheet("Rayo#{MALE}, Especie25"), Remi.text(scene)
  end

  private

  # Chispa, a level 12 Pikachu-numbered Pokemon with distinct stats, IVs and EVs and one move; opts override fields.
  def chispa(opts = {})
    Poke.build({ :name => "Chispa", :species => 25, :level => 12, :hp => 31, :totalhp => 40,
                 :iv => [31, 20, 11, 10, 1, 0], :ev => [4, 252, 0, 6, 1, 248],
                 :moves => [Move.new(33, 35, 35)] }.merge(opts))
  end

  # The sheet Chispa's fields paint, as sentences: head, nature, what follows the nature, stats, IV stars, EVs, what
  # follows them, ability, item, moves and the keys.
  # opts: :nature its name; :after_nature, :after_evs sentences; :hp the HP shown; :item the item sentence; :keys false
  #   leaves the keys out
  def sheet(head, opts = {})
    hp = opts.fetch(:hp, 31)
    parts = [head, T.t(:sm_nature, :n => opts.fetch(:nature, "Naturaleza0"))] + (opts[:after_nature] || [])
    parts.push(stat_row(T.t(:rem_sum_stats), [T.t(:list_pos, :i => hp, :n => 40), 30, 28, 32, 26, 35]))
    parts.push(stat_row(T.t(:rem_sum_rating), [3, 2, 2, 1, 0, 1].map { |n| T.t(:list_pos, :i => n, :n => 3) }))
    parts.push(stat_row(T.t(:rem_sum_evs), [4, 252, 0, 1, 248, 6]))
    parts.concat(opts[:after_evs] || [])
    parts.push(T.t(:sum_ability, :a => "Habilidad1"))
    parts.push(opts[:item]) if opts[:item]
    parts.push(T.t(:sm_moves, :list => "Mov33. #{T.t(:mv_type, :t => 'Tipo1')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}"))
    parts.push(T.t(:rem_sum_keys, :moves => "1, 2, 3, 4", :ability => "T", :back => "X")) unless opts[:keys] == false
    PokeAccess.sentences(parts)
  end

  # "Title. label value, ..." over the six stat rows in the sheet's order; a nil value is a row left out.
  def stat_row(title, values)
    "#{title}. " + STAT_LABELS.zip(values).reject { |_k, v| v.nil? }.map { |k, v| "#{T.t(k)} #{v}" }.join(", ")
  end

  # A physical move's detail line: name, type, category, power, accuracy 100 and its PP, all left.
  def move_line(name, type, power, pp)
    [name, T.t(:mv_type, :t => type), T.t(:cat_physical), T.t(:mv_power, :p => power), T.t(:mv_acc, :a => 100),
     T.t(:mv_pp, :pp => pp, :tot => pp)].join(". ")
  end

  # Runs the block with the game's pbHiddenPower working out the given [type, power].
  def with_hidden_power(answer, &blk)
    GameFunctions.with(:pbHiddenPower => lambda { |_iv| answer }, &blk)
  end
end
