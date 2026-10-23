# Kyu's TextLog plugin (class Log): the page read is the page the game drew, rebuilt from @pos and @lines the way its
# last move drew it, and said as one line. The plugin's frame reader is plugins_smoke_test.rb's; the harness loads it.
class TextLogTest < PokeAccessTest
  # A short history, each entry the lines the game drew for it.
  THREE = [["primera linea"], ["segunda", "con dos"], ["tercera"]].freeze
  # A long history's entry sizes, in lines, repeated.
  SIZES = [1, 2, 3, 1, 4, 2, 1, 3, 2, 1].freeze
  # A walk over the long history: down from the newest page, up and down again, and down back to the end.
  WALK = ([:down] * 12 + [:up] * 5 + [:down, :up, :down, :down, :up, :up, :up] + [:down] * 12).freeze

  test "every page the game draws, opening and after each move, is the page read" do
    log = (0...37).map { |i| (1..SIZES[i % SIZES.length]).map { |l| "entrada #{i} linea #{l}" } }
    with_log(log) do
      [[nil, nil], [12, nil], [14, nil], [nil, 40]].each do |pad, pady|
        wrong, last = walk(log, WALK, pad, pady)
        assert_equal [], wrong.first(5), "INTERPAD #{pad.inspect}, PADY #{pady.inspect}: each page read is the one drawn"
        assert_equal true, last.include?(log.length - 1),
                     "INTERPAD #{pad.inspect}, PADY #{pady.inspect}: back down at the end, the newest entry is read"
      end
    end
  end

  test "the pages of random histories, walked at random, are the pages read" do
    [3, 17, 29, 41, 58].each do |seed|
      rng = Random.new(seed)
      log = (0...(12 + rng.rand(30))).map { |i| (1..(1 + rng.rand(4))).map { |l| "entrada #{i} linea #{l}" } }
      moves = (0...80).map { rng.rand(2).zero? ? :up : :down }
      pad = [nil, 6, 10, 16][rng.rand(4)]
      with_log(log) do
        wrong, _last = walk(log, moves, pad, nil)
        assert_equal [], wrong.first(5), "seed #{seed}, INTERPAD #{pad.inspect}"
      end
    end
  end

  test "a page ends at the entry before @pos and spans @lines entries" do
    with_log(THREE) do
      { [2, 2] => [0, 1], [2, 1] => [1], [3, 3] => [0, 1, 2], [1, 1] => [0] }.each do |(pos, lines), want|
        assert_equal want, page(pos, lines), "@pos #{pos}, @lines #{lines}"
      end
    end
  end

  test "a page with no line count reads the entry before @pos" do
    with_log(THREE) { assert_equal [1], page(2, 0) }
  end

  test "a page with more lines than entries before it starts at the first" do
    with_log(THREE) { assert_equal [0, 1], page(2, 5) }
  end

  test "at the top there is no page before the first entry" do
    with_log(THREE) { assert_nil page(0, 1) }
  end

  test "a @pos past the history's end is held to the newest entry" do
    with_log(THREE) do
      { [4, 2] => [1, 2], [4, 1] => [2], [99, 2] => [1, 2] }.each do |(pos, lines), want|
        assert_equal want, page(pos, lines), "@pos #{pos}, @lines #{lines}"
      end
    end
  end

  test "there is no page with no @pos, no history or an empty one" do
    with_log(THREE) { assert_nil page(nil, 1), "no @pos" }
    { "no history" => nil, "a history that is no list" => "primera linea", "an empty history" => [] }.each do |what, log|
      with_log(log) { assert_nil page(2, 1), what }
    end
  end

  test "a page whose start a move down left past the history is built back from the newest entry" do
    with_log(THREE) do
      scene = scene_at(1, 0)
      PokeAccess::TextLog.page_range(scene)
      scene.instance_variable_set(:@pos, 3)
      assert_equal [2], PokeAccess::TextLog.page_range(scene)
    end
  end

  test "a page drawn down holds an entry that fills the screen to its last pixel" do
    log = [%w[a b c d e], %w[f g h i j], ["k"]]
    with_log(log) do
      with_const(:INTERPAD, 14) do
        scene = scene_at(0, 0)
        PokeAccess::TextLog.page_range(scene)
        game_down(scene, log, 14, Graphics.height - 2 * 25)
        assert_equal [0, 1], PokeAccess::TextLog.page_range(scene)
      end
    end
  end

  test "a page drawn down from an entry taller than the screen holds nothing, and reads nothing" do
    with_log([["a"], (1..11).map { |i| "linea #{i}" }, ["b"]]) do
      scene = scene_at(1, 1)
      PokeAccess::TextLog.page_range(scene)
      scene.instance_variable_set(:@lines, 0)
      assert_nil PokeAccess::TextLog.page_text(scene)
    end
  end

  test "reads a page as one line, its entries in order" do
    with_log(THREE) { assert_equal "primera linea. segunda con dos", PokeAccess::TextLog.page_text(scene_at(2, 2)) }
  end

  test "reads an entry as one line, its drawn lines joined" do
    with_log(THREE) { assert_equal "segunda con dos", PokeAccess::TextLog.entry_text(1) }
  end

  test "reads an entry kept as plain text as it is" do
    with_log(["texto suelto"]) { assert_equal "texto suelto", PokeAccess::TextLog.entry_text(0) }
  end

  test "counts an entry kept as plain text as one line of a page drawn down" do
    with_log((0...11).map { |i| "entrada #{i}" }) do
      scene = scene_at(0, 0)
      PokeAccess::TextLog.page_range(scene)
      scene.instance_variable_set(:@pos, 8)
      scene.instance_variable_set(:@lines, 8)
      assert_equal (0..8).to_a, PokeAccess::TextLog.page_range(scene)
    end
  end

  test "an index outside the history, or none, has no entry" do
    with_log(THREE) do
      [nil, -1, 3, 7, "1"].each { |i| assert_nil PokeAccess::TextLog.entry_text(i), "index #{i.inspect}" }
    end
  end

  test "a page the scene's state cannot place reads nothing" do
    with_log(THREE) { assert_nil PokeAccess::TextLog.page_text(scene_at("dos", 1)) }
  end

  private

  # The page read for a scene first seen at @pos and @lines.
  def page(pos, lines)
    PokeAccess::TextLog.page_range(scene_at(pos, lines))
  end

  # A Log scene as far as the reader looks at it: its @pos and @lines.
  def scene_at(pos, lines)
    scene = Object.new
    scene.instance_variable_set(:@pos, pos)
    scene.instance_variable_set(:@lines, lines)
    scene
  end

  # Opens log as the game does and walks it with moves, under INTERPAD pad and PADY pady (nil: absent, the game's
  # default), reading the page twice after each move, as the reader polls every frame; answers the pages read
  # otherwise than drawn, as [move, drawn, first read, second read], and the last page read.
  def walk(log, moves, pad, pady)
    gap = pad || 4
    room = Graphics.height - 2 * (pady || 25)
    with_const(:INTERPAD, pad) do
      with_const(:PADY, pady) do
        scene = Object.new
        wrong = []
        read = nil
        ([:open] + moves).each do |m|
          drawn = send("game_#{m}", scene, log, gap, room)
          next unless drawn
          read = PokeAccess::TextLog.page_range(scene)
          again = PokeAccess::TextLog.page_range(scene)
          wrong.push([m, drawn, read, again]) unless read == drawn && again == drawn
        end
        [wrong, read]
      end
    end
  end

  # The entries a page Kyu's Log builds back from pos holds, oldest first (its opening page and a move up): each is 32
  # pixels a line plus pad, taken while the total fits room.
  def game_back_page(log, pos, pad, room)
    total = 0
    w = 0
    out = []
    while total <= room && pos - w >= 0
      total += 32 * log[pos - w].length + pad
      out.unshift(pos - w) if total <= room
      w += 1
    end
    out
  end

  # Kyu's opening: the page built back from the newest entry, @pos one past it.
  def game_open(scene, log, pad, room)
    drawn = game_back_page(log, log.length - 1, pad, room)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, log.length)
    drawn
  end

  # Kyu's move down: drawn forward from @pos while entries fit, so it can hold one entry past the new @pos; nil at the
  # newest entry.
  def game_down(scene, log, pad, room)
    pos = scene.instance_variable_get(:@pos)
    return nil unless pos < log.length - 1
    total = 0
    w = 0
    drawn = []
    while total <= room && pos + w <= log.length - 1
      h = 32 * log[pos + w].length
      drawn.push(pos + w) if total + h <= room
      total += h + pad
      w += 1
    end
    scene.instance_variable_set(:@pos, pos + w - 1)
    scene.instance_variable_set(:@lines, w - 1)
    drawn
  end

  # Kyu's move up: the page built back from the entry before the one the page started at; nil at the top.
  def game_up(scene, log, pad, room)
    pos = scene.instance_variable_get(:@pos) - scene.instance_variable_get(:@lines)
    return nil unless pos > 0
    drawn = game_back_page(log, pos - 1, pad, room)
    scene.instance_variable_set(:@lines, drawn.length)
    scene.instance_variable_set(:@pos, pos)
    drawn
  end

  # Runs the block with $PokemonGlobal.log answering log, as Kyu's plugin adds it; put back as it was after.
  def with_log(log)
    meta = $PokemonGlobal.singleton_class
    had = meta.method_defined?(:log, false) ? meta.instance_method(:log) : nil
    meta.send(:define_method, :log) { log }
    yield
  ensure
    if had
      meta.send(:define_method, :log, had)
    else
      meta.send(:remove_method, :log)
    end
  end

  # Runs the block with the game's top-level constant name at value (nil: absent), put back as it was after.
  def with_const(name, value)
    had = Object.const_defined?(name, false)
    was = had ? Object.const_get(name, false) : nil
    Object.send(:remove_const, name) if had
    Object.const_set(name, value) unless value.nil?
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, was) if had
  end
end
