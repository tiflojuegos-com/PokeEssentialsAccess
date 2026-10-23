# Rejuvenation's Zygarde summary page (games/rejuvenation/zygarde.rb): read whole as painted, each stat's cores and the
# types its icons show, and the core allocation's selector read as it moves and as a change redraws the page.
Harness.load_common("rv_common")

# Rejuvenation's drawZygardePage as Summary.rb paints it: each stat's value first (right-justified with figure spaces,
# ten per core), then the title, name, level and cores left, the stat labels, the type, ability and core effect rows
# and the mode's key hint; a Pokemon with no custom form paints nothing.
class PokemonSummaryScene
  def drawZygardePage(pokemon, allocation = false)
    return if pokemon.customForm.nil?
    inv = pokemon.customForm.checkFlag?(:CoreInvestment)
    ys = [76, 108, 140, 172, 204, 236]
    textpos = ys.each_with_index.map { |y, i| [(54 + 10 * inv[i]).to_s.rjust(3, [0x2007].pack("U")), 452, y, 0] }
    textpos += [["ZYGARDE CORES", 26, 16, 0], [pokemon.name, 46, 62, 0], ["50", 46, 92, 0], ["Cores:", 16, 320, 0],
                [(5 - inv.inject(0) { |a, b| a + b }).to_s, 130, 320, 0]]
    labels = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]
    textpos += labels.each_with_index.map { |l, i| [l, 240, ys[i], 0] }
    textpos += [["Type", 226, 284, 0], ["Ability", 226, 316, 0], ["Core Effect", 226, 348, 0],
                ["Aura Break", 432, 316, 0], ["+ 10", 432, 348, 0]]
    textpos.push([allocation ? "Back:  X" : "Assign Cores:  C", 8, 350, 0])
    pbDrawTextPositions(nil, textpos)
    :drawn
  end
end

class RejuvenationZygardeTest < PokeAccessTest
  # The custom form that keeps the cores invested in each stat, the Pokemon that carries it and the stat selector.
  Form = Struct.new(:investment) do
    def checkFlag?(flag)
      flag == :CoreInvestment ? investment : nil
    end
  end
  Mon = Struct.new(:name, :customForm, :type1, :type2)
  Selector = Struct.new(:index, :visible)

  # The names the game's getTypeName gives the types, its translation of each.
  TYPE_NAMES = { :DRAGON => "Dragón", :GROUND => "Tierra" }

  # The stat labels the page paints, top to bottom.
  STATS = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]

  test "a draw outside the allocation reads the whole page as painted, queued" do
    with_type_names do
      pk = zygarde
      summary(pk).drawZygardePage(pk)
      page = ["ZYGARDE CORES", stat(0, 64, 1), stat(1, 74, 2), stat(2, 54, 0), stat(3, 54, 0), stat(4, 54, 0),
              stat(5, 54, 0), "Type Dragón, Tierra", "Ability Aura Break", "Core Effect + 10", "Cores: 2",
              "Assign Cores: C"]
      assert_equal [[PokeAccess.sentences(page), false]], SpeakCapture.log
    end
  end

  test "the hooked draw hands back what the page's own draw returns" do
    pk = zygarde
    assert_equal :drawn, summary(pk).drawZygardePage(pk)
  end

  test "opening the allocation reads its first row with the cores left and the hint that closes it, cutting in" do
    pk = zygarde
    scene = summary(pk)
    scene.instance_variable_get(:@sprites)["statsel"].visible = true
    scene.drawZygardePage(pk, true)
    assert_equal [[PokeAccess.sentences([stat(0, 64, 1), "Cores: 2", "Back: X"]), true]], SpeakCapture.log
  end

  test "moving the selector says the row it lands on, cutting in" do
    pk = zygarde
    scene = allocating(pk)
    selector(scene).index = 1
    scene.pbUpdate
    assert_equal [[stat(1, 74, 2), true]], SpeakCapture.log
  end

  test "the selector resting on a row says nothing more" do
    pk = zygarde
    scene = allocating(pk)
    selector(scene).index = 1
    scene.pbUpdate
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "a core added redraws its row as it now stands and the cores left, without the hint again" do
    pk = zygarde
    scene = allocating(pk)
    selector(scene).index = 1
    scene.pbUpdate
    SpeakCapture.clear
    pk.customForm.investment[1] = 3
    scene.drawZygardePage(pk, true)
    assert_equal [[PokeAccess.sentences([stat(1, 84, 3), "Cores: 1"]), true]], SpeakCapture.log
  end

  test "the frame after a redraw does not repeat its row" do
    pk = zygarde
    scene = allocating(pk)
    pk.customForm.investment[0] = 2
    scene.drawZygardePage(pk, true)
    SpeakCapture.clear
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "the type row names each type as the game names it, a single type once" do
    with_type_names do
      { [:DRAGON, :GROUND] => "Type Dragón, Tierra", [:DRAGON, nil] => "Type Dragón",
        [:DRAGON, :DRAGON] => "Type Dragón" }.each do |types, said|
        pk = zygarde([1, 2, 0, 0, 0, 0], types)
        scene = allocating(pk)
        selector(scene).index = 6
        scene.pbUpdate
        assert_equal [said], SpeakCapture.lines, "types #{types.inspect}"
      end
    end
  end

  test "a type the game has no name for is said by its own name" do
    GameFunctions.with(:getTypeName => lambda { |_t| "" }) do
      pk = zygarde([1, 2, 0, 0, 0, 0], [:FAIRY, nil])
      scene = allocating(pk)
      selector(scene).index = 6
      scene.pbUpdate
      assert_equal ["Type Fairy"], SpeakCapture.lines
    end
  end

  test "the ability row says the ability" do
    pk = zygarde
    scene = allocating(pk)
    selector(scene).index = 7
    scene.pbUpdate
    assert_equal ["Ability Aura Break"], SpeakCapture.lines
  end

  test "leaving the allocation reads the page as it now stands" do
    with_type_names do
      pk = zygarde
      scene = summary(pk)
      scene.drawZygardePage(pk)
      sel = selector(scene)
      sel.visible = true
      scene.drawZygardePage(pk, true)
      pk.customForm.investment[1] = 3
      scene.drawZygardePage(pk, true)
      sel.visible = false
      SpeakCapture.clear
      scene.drawZygardePage(pk)
      page = ["ZYGARDE CORES", stat(0, 64, 1), stat(1, 84, 3), stat(2, 54, 0), stat(3, 54, 0), stat(4, 54, 0),
              stat(5, 54, 0), "Type Dragón, Tierra", "Ability Aura Break", "Core Effect + 10", "Cores: 1",
              "Assign Cores: C"]
      assert_equal [[PokeAccess.sentences(page), true]], SpeakCapture.log
    end
  end

  test "the allocation opened again after leaving says its closing hint again" do
    pk = zygarde
    scene = allocating(pk)
    sel = selector(scene)
    sel.visible = false
    scene.drawZygardePage(pk)
    sel.visible = true
    sel.index = 0
    SpeakCapture.clear
    scene.drawZygardePage(pk, true)
    assert_equal [[PokeAccess.sentences([stat(0, 64, 1), "Cores: 2", "Back: X"]), true]], SpeakCapture.log
  end

  test "a hidden selector says nothing as it moves" do
    pk = zygarde
    scene = allocating(pk)
    sel = selector(scene)
    sel.visible = false
    sel.index = 2
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "a Pokemon with no cores, reached on this page, paints nothing and is not read" do
    pk = zygarde
    scene = summary(pk)
    scene.drawZygardePage(pk)
    SpeakCapture.clear
    scene.drawZygardePage(Mon.new("Pikachu", nil, :ELECTRIC, nil))
    assert_nothing_spoken
  end

  private

  # A Zygarde with cores invested per stat (HP first) and its two types.
  def zygarde(investment = [1, 2, 0, 0, 0, 0], types = [:DRAGON, :GROUND])
    Mon.new("Zygarde", Form.new(investment), types[0], types[1])
  end

  # The summary scene on pk, its selector hidden, with the profile's hooks bound.
  def summary(pk)
    load_profile
    scene = PokemonSummaryScene.new(pk)
    scene.instance_variable_set(:@sprites, { "statsel" => Selector.new(0, false) })
    scene
  end

  # The scene with the allocation open on its first row (as C opens it), its first reading cleared.
  def allocating(pk)
    scene = summary(pk)
    selector(scene).visible = true
    scene.drawZygardePage(pk, true)
    SpeakCapture.clear
    scene
  end

  def selector(scene)
    scene.instance_variable_get(:@sprites)["statsel"]
  end

  # A stat's row as the page shows it: its label and value, with the cores invested in it.
  def stat(i, value, cores)
    "#{STATS[i]} #{value}, #{PokeAccess::I18n.t(:rj_zyg_cores, :n => cores)}"
  end

  # Runs the block with the game's getTypeName answering its own names for the types.
  def with_type_names(&blk)
    GameFunctions.with(:getTypeName => lambda { |t| TYPE_NAMES[t].to_s }, &blk)
  end

  # Evaluates the profile file once per process, over the stand-in above, after every test file has loaded, so no
  # later reopening of the summary scene can drop its hooks.
  def load_profile
    return if self.class.instance_variable_get(:@profile_loaded)
    path = File.join(Harness::ROOT, "games", "rejuvenation", "zygarde.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    self.class.instance_variable_set(:@profile_loaded, true)
  end
end
