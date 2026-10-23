# The gen-6 move relearner (core/menus/gen6/move_relearner_g6.rb), stock and older screen: the focused move with its
# row's tag, the list again back from a declined question, and the summary's info key while the move cursor is up.

# The stock gen-6 relearner as Pokemon Z's 147 runs it: pbStartScene draws the move list; pbChooseMove updates once a
# frame, the cursor moving inside the update, and redraws the list when it moved; a declined question runs pbChooseMove
# again.
class MoveRelearnerScene
  attr_accessor :frames

  def pbStartScene(moves, commands)
    @moves = moves
    @sprites = { "commands" => commands }
    pbDrawMoveList
    :started
  end

  def pbDrawMoveList
    :drawn
  end

  def pbUpdate
    :updated
  end

  def pbChooseMove
    list = @sprites["commands"]
    (@frames || [list.index]).each do |i|
      old = list.index
      list.index = i
      pbUpdate
      pbDrawMoveList if i != old
    end
    @frames = nil
    @moves[list.index]
  end
end

# The older relearner as Insurgence runs it (Uranium's is alike), under its game's name since a process binds a class
# name once: pbStartScene adds the CANCEL row (move 0) and paints the first row with pbRefreshInfo under the question
# its message window holds; pbChooseMove updates, then repaints each row the cursor moves to. It has no pbDrawMoveList.
module Insurgence
  class MoveRelearnerScene
    attr_accessor :picks

    def pbStartScene(moves, list, box)
      @moves = moves + [0]
      @sprites = { "list" => list, "msgwindow" => box }
      pbRefreshInfo(@moves[0])
      :started
    end

    def pbRefreshInfo(move)
      move
    end

    def pbUpdate
      :updated
    end

    def pbChooseMove
      list = @sprites["list"]
      pbUpdate
      (@picks || []).each do |i|
        list.index = i
        pbRefreshInfo(@moves[i])
        pbUpdate
      end
      @picks = nil
      @moves[list.index]
    end
  end
end

class MoveRelearnerG6Test < PokeAccessTest
  Relearner = PokeAccess::MoveRelearnerGen6
  QUESTION = "¿Qué movimiento enseñar a Pikachu?"

  class << self
    private

    # Binds the reader's hooks (its file from the first hook on) to the stand-in named cname, as boot binds them to
    # the relearner a game has: SCENE names the stand-in while they bind and then takes its boot value back, and the
    # stand-in leaves the top level, so no later file sees a relearner the stubs lack. Answers the stand-in.
    def bound(cname)
      booted = Relearner::SCENE
      path = File.join(Harness::ROOT, "core", "menus", "gen6", "move_relearner_g6.rb")
      src = Harness.source(path)
      at = src.index(/^PokeAccess::Hooks\./)
      scene_named(cname)
      eval(src[at..-1], TOPLEVEL_BINDING, path, src[0, at].count("\n") + 1)
      stand_in = PokeAccess.const_at(cname)
      Object.send(:remove_const, cname.split("::").first.to_sym)
      stand_in
    ensure
      scene_named(booted)
    end

    # Sets the reader's SCENE, the class name its hooks bind to.
    def scene_named(name)
      Relearner.send(:remove_const, :SCENE)
      Relearner.const_set(:SCENE, name)
    end
  end

  Stock = bound("MoveRelearnerScene")
  Older = bound("Insurgence::MoveRelearnerScene")

  test "the focused move is the row's id, a [id, tag] pair unwrapped" do
    { [[11, 22, 33], 1] => 22, [[[11, "MT"], [22, "MT"], [33, "MT"]], 1] => 22,
      [[11, 22, 33], 0] => 11, [[11, 22, 33], 2] => 33 }.each do |(moves, index), want|
      assert_equal want, Relearner.focused_id(stock_scene(moves, index)), "#{moves.inspect} at #{index}"
    end
  end

  test "there is no focused move with no selection or past the end of the list" do
    [-1, 3, 99].each do |index|
      assert_nil Relearner.focused_id(stock_scene([11, 22, 33], index)), "at index #{index}"
    end
  end

  test "with no focused move the detail says nothing" do
    with_move_info do
      Relearner.detail(stock_scene([11, 22], -1))
      assert_nothing_spoken
    end
  end

  test "a machine row says its tag before the move from the medium level" do
    with_move_info do
      scene = stock_scene([[11, ""], [22, "MT"]], 1)
      said = vb_levels do
        SpeakCapture.clear
        Relearner.detail(scene)
        SpeakCapture.log.dup
      end
      assert_equal [[["22 a nivel", true]], [["MT. 22 a nivel", true]], [["MT. 22 a nivel", true]]], said,
                   "brief, medium and full"
    end
  end

  test "the info key keeps a machine row's tag and the whole move at every level" do
    with_move_info do
      scene = stock_scene([[11, ""], [22, "MT"]], 1)
      kept = vb_levels do
        Relearner.detail(scene)
        PokeAccess::Info.info_text
      end
      assert_equal ["MT. 22 entero"] * 3, kept
    end
  end

  test "a free row says only the move, and the info key keeps the whole move" do
    with_move_info do
      Relearner.detail(stock_scene([[11, ""], [22, ""]], 1))
      assert_equal [["22 a nivel", true]], SpeakCapture.log
      assert_equal "22 entero", PokeAccess::Info.info_text
    end
  end

  test "a tagged row whose move has no data says nothing and leaves the info key empty" do
    with_move_info do
      Relearner.detail(stock_scene([[99, "MT"]], 0))
      assert_nothing_spoken
      assert_nil PokeAccess::Info.info_text
    end
  end

  test "the detail carries the PP the row paints" do
    Relearner.detail(stock_scene([7], 0))
    pp = PokeAccess::I18n.t(:mv_pp, :pp => 15, :tot => 15)
    assert_includes SpeakCapture.last, pp, "said at the full level"
    assert_includes PokeAccess::Info.info_text, pp, "and kept for the info key"
  end

  test "a move lookup or a list that raises leaves the reader silent, never the screen stopped" do
    broken = Object.new
    def broken.index; raise IndexError, "disposed window"; end
    with_lookup(lambda { |_id, _reading = nil| raise ArgumentError, "no move data" }) do
      Relearner.detail(stock_scene([7], 0))
      Relearner.refreshed(older_scene([7], 0), 7)
    end
    scene = World.stub_scene(:@sprites => { "list" => broken, "msgwindow" => msg_box(QUESTION) }, :@moves => [7])
    def scene.pbRefreshInfo(_move); end
    reenter(scene)
    assert_nothing_spoken
  end

  test "opening the stock screen claims its list for the reader without freezing the cursor" do
    with_move_info do
      win = move_list(["Placaje", "Gruñido"], 0)
      Stock.new.pbStartScene([33, 45], win)
      assert_equal true, PokeAccess.dedicated?(win), "the generic list read is muted"
      assert_nil win.instance_variable_get(:@ignore_input), "the engine's input freeze is left alone"
    end
  end

  test "opening the stock screen says the focused move, and so does each redraw" do
    with_move_info do
      scene = Stock.new
      scene.pbStartScene([[11, "MT"], [22, "MT"]], move_list(["Placaje", "Gruñido"], 1))
      assert_equal [["MT. 22 a nivel", true]], SpeakCapture.log, "the list drawn as it opens"
      SpeakCapture.clear
      scene.pbDrawMoveList
      assert_equal [["MT. 22 a nivel", true]], SpeakCapture.log, "a redraw"
    end
  end

  test "the hooked stock screen keeps its own return values" do
    with_move_info do
      scene = Stock.new
      assert_equal :started, scene.pbStartScene([33, 45], move_list(["Placaje", "Gruñido"], 1))
      assert_equal :drawn, scene.pbDrawMoveList
      assert_equal :updated, scene.pbUpdate
      assert_equal 45, scene.pbChooseMove
    end
  end

  test "back on the stock list from a declined question, the loop's first update says the move as a redraw does" do
    with_move_info do
      scene = Stock.new
      scene.pbStartScene([33, 45], move_list(["Placaje", "Gruñido"], 0))
      SpeakCapture.clear
      scene.pbChooseMove
      assert_nothing_spoken "the first run, right after the opening read, says nothing"
      scene.frames = [0, 0]
      scene.pbChooseMove
      assert_equal [["33 a nivel", true]], SpeakCapture.log, "the second run, once, on its first update"
      SpeakCapture.clear
      scene.pbChooseMove
      assert_equal [["33 a nivel", true]], SpeakCapture.log, "and every run after it"
    end
  end

  test "binding to the stock screen reports nothing missing, though it has no pbRefreshInfo" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\AMoveRelearnerScene#/)
  end

  test "opening the older screen says its question and then its first row, queued" do
    with_move_info do
      Older.new.pbStartScene([1, 45], move_list(rows_of([1, 45, 0]), 0), msg_box(QUESTION))
      assert_equal [["#{QUESTION} 1 a nivel", false]], SpeakCapture.log
    end
  end

  test "opening the older screen claims its list for the reader" do
    with_move_info do
      list = move_list(rows_of([1, 45, 0]), 0)
      Older.new.pbStartScene([1, 45], list, msg_box(QUESTION))
      assert_equal true, PokeAccess.dedicated?(list)
    end
  end

  test "a move on the older screen says its row, interrupting, without the question" do
    with_move_info do
      scene = older_opened([1, 45])
      scene.picks = [1]
      scene.pbChooseMove
      assert_equal [["45 a nivel", true]], SpeakCapture.log
    end
  end

  test "the older screen's info key keeps the whole move of the focused row" do
    with_move_info do
      scene = older_opened([1, 45])
      scene.picks = [1]
      scene.pbChooseMove
      assert_equal "45 entero", PokeAccess::Info.info_text
    end
  end

  test "the older screen's CANCEL row is said by the list's own caption" do
    with_move_info do
      scene = older_opened([1, 45])
      scene.picks = [2]
      scene.pbChooseMove
      assert_equal [["CANCEL", true]], SpeakCapture.log
    end
  end

  test "the older screen with no question painted says its first row alone, queued" do
    with_move_info do
      { "no message window" => nil, "an empty one" => msg_box("") }.each do |what, box|
        SpeakCapture.clear
        Older.new.pbStartScene([1], move_list(rows_of([1, 0]), 0), box)
        assert_equal [["1 a nivel", false]], SpeakCapture.log, what
      end
    end
  end

  test "a row with nothing to say keeps the question for the next one" do
    with_move_info do
      { "a CANCEL row with no list to caption it" => [[0, 1], nil],
        "a move whose line is empty" => [[98, 1], move_list(rows_of([98, 1, 0]), 0)] }.each do |what, (moves, list)|
        SpeakCapture.clear
        scene = Older.new
        scene.pbStartScene(moves, list, msg_box(QUESTION))
        assert_nothing_spoken what
        scene.pbRefreshInfo(1)
        assert_equal [["#{QUESTION} 1 a nivel", false]], SpeakCapture.log, "after #{what}"
      end
    end
  end

  test "back on the older screen's list after a declined question, its question and focused row, queued, once" do
    with_move_info do
      scene = older_opened([1, 45])
      scene.pbChooseMove
      assert_nothing_spoken "the first entry says nothing"
      scene.pbChooseMove
      assert_equal [["#{QUESTION} 1 a nivel", false]], SpeakCapture.log, "the second entry's first update"
      SpeakCapture.clear
      scene.pbUpdate
      assert_nothing_spoken "and no later update"
    end
  end

  test "back on an older screen whose list cannot be read, its question alone" do
    with_move_info do
      { "no list" => [{ "msgwindow" => msg_box(QUESTION) }, [1]],
        "no moves" => [{ "msgwindow" => msg_box(QUESTION), "list" => move_list(["Mov1"], 0) }, nil] }.each do |what, (sprites, moves)|
        SpeakCapture.clear
        scene = World.stub_scene(:@sprites => sprites, :@moves => moves)
        def scene.pbRefreshInfo(_move); end
        reenter(scene)
        assert_equal [[QUESTION, false]], SpeakCapture.log, what
      end
    end
  end

  test "back on an older screen with neither a row nor a question to read, nothing is said" do
    scene = World.stub_scene(:@sprites => { "msgwindow" => msg_box("") }, :@moves => [1])
    def scene.pbRefreshInfo(_move); end
    reenter(scene)
    assert_nothing_spoken
  end

  test "the hooked older screen keeps its own return values" do
    with_move_info do
      scene = Older.new
      assert_equal :started, scene.pbStartScene([1, 45], move_list(rows_of([1, 45, 0]), 0), msg_box(QUESTION))
      assert_equal 45, scene.pbRefreshInfo(45)
      assert_equal :updated, scene.pbUpdate
      scene.picks = [1]
      assert_equal 45, scene.pbChooseMove
    end
  end

  test "binding to the older screen reports nothing missing, though it has no pbDrawMoveList" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\AInsurgence::MoveRelearnerScene#/)
  end

  test "the info key stays on the focused move while the summary's move cursor is up" do
    scene = summary_with_cursor(true)
    PokeAccess::Info.set_info(:text, "movimiento enfocado")
    scene.pbUpdate
    assert_equal "movimiento enfocado", PokeAccess::Info.info_text
  end

  test "the info key goes back to the shown Pokemon once the summary's move cursor is gone" do
    scene = summary_with_cursor(false)
    PokeAccess::Info.set_info(:text, "movimiento enfocado")
    scene.pbUpdate
    glance = PokeAccess::I18n.t(:pk_glance, :name => "Chispa", :level => 25, :hp => 40, :tot => 40)
    assert_match(/\A#{Regexp.escape(glance)}/, PokeAccess::Info.info_text)
  end

  test "each move says its place in the list after its name, so the last and the first are told apart" do
    said = [2, 0].map do |i|
      Relearner.detail(stock_scene([7, 8, 9], i))
      SpeakCapture.last.split(". ").first
    end
    assert_equal [entry("Mov9", 3, 3), entry("Mov7", 1, 3)], said
  end

  test "a move's place is left out at the brief level" do
    PokeAccess::Config.verbosity = :brief
    Relearner.detail(stock_scene([7, 8, 9], 2))
    assert_equal "Mov9", SpeakCapture.last
  end

  test "the first move said is led by the species the Pokemon's icon shows and its types, and only the first" do
    pk = Poke.build(:name => "Chispa", :species => 25)
    pk.define_singleton_method(:type1) { 13 }
    pk.define_singleton_method(:type2) { 2 }
    scene = stock_scene([7, 8], 0)
    scene.instance_variable_set(:@pokemon, pk)
    Relearner.detail(scene)
    Relearner.detail(scene)
    head = "Especie25, " + PokeAccess::I18n.t(:pc_types, :t => "Tipo13 Tipo2")
    assert_equal ["#{head}. #{entry('Mov7', 1, 2)}", entry("Mov7", 1, 2)],
                 SpeakCapture.lines.map { |l| l.split(". ")[0, l.start_with?(head) ? 2 : 1].join(". ") }
  end

  private

  # A list row's name with its place, as the positions reading says it.
  def entry(name, n, tot)
    PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => tot)
  end

  # Runs the block with the move data answering as lookup does; the real lookup is put back after.
  def with_lookup(lookup)
    info = PokeAccess::MoveInfo
    saved = info.method(:by_id_via_data)
    info.define_singleton_method(:by_id_via_data, &lookup)
    yield
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
  end

  # Runs the block with the move data answering "<id> a nivel" at a reading's level and "<id> entero" whole, nothing
  # for move 99 and an empty line for move 98.
  def with_move_info(&blk)
    lookup = lambda do |id, reading = nil|
      next nil if id == 99
      next "" if id == 98
      reading ? "#{id} a nivel" : "#{id} entero"
    end
    with_lookup(lookup, &blk)
  end

  # A move list window over commands with its cursor at index.
  def move_list(commands, index = 0)
    w = Object.new
    w.instance_variable_set(:@commands, commands)
    w.instance_variable_set(:@index, index)
    def w.index; @index; end
    def w.index=(v); @index = v; end
    w
  end

  # The older screen's message window, holding text.
  def msg_box(text)
    Struct.new(:text).new(text)
  end

  # The older screen's rows for moves, as it paints them: "Mov<id>", and CANCEL for move 0.
  def rows_of(moves)
    moves.map { |m| m.to_i > 0 ? "Mov#{m}" : "CANCEL" }
  end

  # The stock screen's state: moves and the "commands" list with its cursor at index.
  def stock_scene(moves, index)
    World.stub_scene(:@sprites => { "commands" => move_list(moves.map { |m| m.to_s }, index) }, :@moves => moves)
  end

  # The older screen's state, told apart by pbRefreshInfo: its "list" over moves and the question window.
  def older_scene(moves, index)
    scene = World.stub_scene(:@sprites => { "list" => move_list(rows_of(moves), index), "msgwindow" => msg_box(QUESTION) },
                             :@moves => moves)
    def scene.pbRefreshInfo(_move); end
    scene
  end

  # The older screen opened on moves, its CANCEL row after them and its cursor on the first, with what it said
  # cleared.
  def older_opened(moves)
    scene = Older.new
    scene.pbStartScene(moves, move_list(rows_of(moves + [0]), 0), msg_box(QUESTION))
    SpeakCapture.clear
    scene
  end

  # The reader's part in scene's choice loop entered twice, the second time back from a declined question, and in
  # that loop's first update.
  def reenter(scene)
    Relearner.choosing(scene)
    Relearner.choosing(scene)
    Relearner.again(scene)
  end

  # A gen-6 summary of "Chispa" whose move cursor is shown or hidden.
  def summary_with_cursor(shown)
    scene = PokemonSummaryScene.new(Poke.build(:name => "Chispa"))
    scene.instance_variable_set(:@sprites, { "movesel" => Struct.new(:visible).new(shown) })
    scene
  end
end
