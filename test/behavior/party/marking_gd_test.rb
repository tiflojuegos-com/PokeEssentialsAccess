# The marking screen of the summary and of the PC (v17 and later): six marks drawn as pictures, read as the cursor
# lands on each and as the button changes one, and the marks a Pokemon's panels list.
class MarkingGdTest < PokeAccessTest
  KEYS = { :use => Input::C, :action => Input::A }

  test "reads the title, then each slot the cursor lands on and each change, queued on arrival and interrupting after" do
    mark_in_summary(marked([0, 1, 0, 0, 0, 0]), [nil, :right, :use, :down, :down, :down, nil])
    assert_equal [["Marcar a Pika", false], [slot(:mk_circle, :mk_off), false], [slot(:mk_triangle, :mk_on), true],
                  [word(:mk_off), true], [slot(:mk_star, :mk_off), true], ["OK", true], ["Cancelar", true]],
                 SpeakCapture.log
  end

  test "measures the slots from where the cursor starts, as the SV summary moves the grid down" do
    mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil, :down, :down, :down, nil], :top => 148)
    assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_off), slot(:mk_heart, :mk_off), "OK", "Cancelar"],
                 SpeakCapture.lines
  end

  test "says nothing while the cursor stands off the grid's slots" do
    scene = summary_scene
    scene.marking_loop = cursor_loop([[284, 144], [458, 144], [226, 144], [342, 244], [284, 344], [284, 94],
                                      [313, 144], [284, 169], [342, 194]])
    scene.pbMarking(marked([0, 0, 0, 0, 0, 0]))
    assert_equal [[slot(:mk_circle, :mk_off), false], [slot(:mk_star, :mk_off), true]], SpeakCapture.log,
                 "past the columns, above or below the rows, beside OK or between slots, nothing; then a mark again"
  end

  test "says only the slots, OK and Cancel in the mod's own words, where the grid paints no text" do
    mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil, :down, :down, :down, nil], :painted => false)
    assert_equal [[slot(:mk_circle, :mk_off), false], [slot(:mk_heart, :mk_off), true], [word(:kb_ok), true],
                  [word(:pc_cancel), true]],
                 SpeakCapture.log
  end

  test "cycles a mark through the colours of the picture's rows and back to unmarked" do
    { 3 => [word(:mk_color, :n => 1), word(:mk_color, :n => 2), word(:mk_off)],
      4 => [word(:mk_color, :n => 1), word(:mk_color, :n => 2), word(:mk_color, :n => 3), word(:mk_off)] }.each do |rows, want|
      mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil] + [:use] * want.length, :rows => rows)
      assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_off)] + want, SpeakCapture.lines, "a picture #{rows} rows tall"
    end
  end

  test "clears a coloured mark with the action button" do
    mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil, :use, :use, :action], :rows => 4)
    assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_off), word(:mk_color, :n => 1), word(:mk_color, :n => 2),
                  word(:mk_off)],
                 SpeakCapture.lines
  end

  test "says nothing when the action button meets a mark already clear" do
    mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil, :action, nil], :rows => 4)
    assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_off)], SpeakCapture.lines
  end

  test "reads v17 and v19 marks from their bits, and the button flips one" do
    mark_in_summary(marked(0b000100), [nil, :right, :right, :use])
    assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_off), slot(:mk_triangle, :mk_off), slot(:mk_square, :mk_on),
                  word(:mk_off)],
                 SpeakCapture.lines
  end

  test "ignores the action button where the marks are bits" do
    mark_in_summary(marked(0b000001), [nil, :action, nil])
    assert_equal ["Marcar a Pika", slot(:mk_circle, :mk_on)], SpeakCapture.lines
  end

  test "reads the PC's message once, then the slot under the arrow and each change" do
    boxed = marked([1, 0, 0, 0, 0, 0])
    mark_in_pc(TestStorage.new([[nil, nil, nil, boxed]]), [0, 3], nil, [nil, :use, :down, :down, nil])
    assert_equal [["Marca a tu Pokemon.", false], [slot(:mk_circle, :mk_on), false], [word(:mk_off), true],
                  [slot(:mk_heart, :mk_off), true], ["OK", true]],
                 SpeakCapture.log
  end

  test "has no action button on the PC grid" do
    boxed = marked([1, 0, 0, 0, 0, 0])
    mark_in_pc(TestStorage.new([[boxed]]), [0, 0], nil, [nil, :action, nil])
    assert_equal ["Marca a tu Pokemon.", slot(:mk_circle, :mk_on)], SpeakCapture.lines
  end

  test "marks the Pokemon held on the PC when there is one" do
    held = marked([0, 0, 1, 0, 0, 0])
    mark_in_pc(TestStorage.new([[marked([0, 0, 0, 0, 0, 0])]]), [0, 0], held, [nil, :right, :right, nil])
    assert_equal ["Marca a tu Pokemon.", slot(:mk_circle, :mk_off), slot(:mk_triangle, :mk_off), slot(:mk_square, :mk_on)],
                 SpeakCapture.lines
  end

  test "marks a party member on the PC by its slot in the party" do
    member = marked([0, 0, 0, 0, 0, 1])
    mark_in_pc(TestStorage.new([[]], [marked([0, 0, 0, 0, 0, 0]), member]), [-1, 1], nil, [nil, :down, :right, :right, nil])
    assert_equal ["Marca a tu Pokemon.", slot(:mk_circle, :mk_off), slot(:mk_heart, :mk_off), slot(:mk_star, :mk_off),
                  slot(:mk_diamond, :mk_on)],
                 SpeakCapture.lines
  end

  test "still reads the grid where the PC keeps its storage out of reach, every mark as clear" do
    mark_in_pc(nil, [0, 0], nil, [nil])
    assert_equal ["Marca a tu Pokemon.", slot(:mk_circle, :mk_off)], SpeakCapture.lines
  end

  test "watches no button once the screen has closed" do
    mark_in_summary(marked([0, 0, 0, 0, 0, 0]), [nil])
    SpeakCapture.clear
    with_keys do |pressed|
      pressed[0] = :use
      Input.update
    end
    assert_nothing_spoken "a button pressed on another screen says no mark"
  end

  test "lists a Pokemon's set marks by name, in their order" do
    assert_equal [word(:mk_triangle), word(:mk_diamond)], PokeAccess::Marking.shown(marked([0, 1, 0, 0, 0, 1]), 2)
  end

  test "gives each listed mark its colour where marks have more than two states" do
    circle = word(:mk_circle)
    square = word(:mk_square)
    { [[0, 0, 2, 0, 0, 0], 4] => ["#{square} #{word(:mk_color, :n => 2)}"],
      [[1, 0, 0, 0, 0, 0], 3] => ["#{circle} #{word(:mk_color, :n => 1)}"],
      [[1, 0, 0, 0, 0, 0], 2] => [circle],
      [[1, 0, 2, 0, 0, 0], nil] => ["#{circle} #{word(:mk_color, :n => 1)}", "#{square} #{word(:mk_color, :n => 2)}"],
      [[1, 0, 1, 0, 0, 0], nil] => [circle, square] }.each do |(marks, variants), want|
      assert_equal want, PokeAccess::Marking.shown(marked(marks), variants), "#{marks.inspect} with #{variants.inspect} states"
    end
  end

  test "names the set bits of an older Pokemon's marks" do
    assert_equal [word(:mk_circle), word(:mk_diamond)], PokeAccess::Marking.shown(marked(0b100001))
  end

  test "lists no marks for a Pokemon without any, or whose marks cannot be read" do
    unreadable = Poke.build
    unreadable.define_singleton_method(:markings) { raise "no marks here" }
    { "no marks" => marked([0, 0, 0, 0, 0, 0]), "marks kept as nil" => marked(nil),
      "a seventh mark no picture names" => marked([0, 0, 0, 0, 0, 0, 1]), "marks that raise" => unreadable,
      "a Pokemon with no marks at all" => Poke.build }.each do |what, pk|
      assert_equal [], PokeAccess::Marking.shown(pk), what
    end
  end

  private

  # A Pokemon named Pika carrying markings as its era keeps them (an Array of values, or bits).
  def marked(markings)
    pk = Poke.build(:name => "Pika")
    pk.define_singleton_method(:markings) { markings }
    pk
  end

  # The text of i18n key with args.
  def word(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A mark's slot as read: its name, then its state.
  def slot(mark, state)
    "#{word(mark)}, #{word(state)}"
  end

  # Runs the block with Input.trigger? answering, frame by frame, for the key the loop holds in pressed[0], as the
  # game's loop asks it; the block gets pressed.
  def with_keys
    pressed = [nil]
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| KEYS[pressed[0]] == k }
    yield pressed
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end

  # A summary scene as pbStartScene leaves it, its marks picture `rows` tall, one row per state a mark can take.
  def summary_scene(rows = 2)
    scene = PokemonSummary_Scene.new
    picture = Struct.new(:height).new(PokemonSummary_Scene::MARK_HEIGHT * rows)
    scene.instance_variable_set(:@markingbitmap, Struct.new(:bitmap).new(picture))
    scene
  end

  # Marks pokemon on the summary's grid, a frame per key; the speech starts empty.
  # opts: :rows the marks picture's rows, :top where the grid's first row stands, :painted false for a grid that
  #   paints no title nor buttons
  def mark_in_summary(pokemon, keys, opts = {})
    scene = summary_scene(opts[:rows] || 2)
    with_keys do |pressed|
      scene.marking_loop = summary_loop(keys, pressed, opts[:top] || 144, opts.fetch(:painted, true))
      SpeakCapture.clear
      scene.pbMarking(pokemon)
    end
  end

  # Marks on the PC's grid, a frame per key, the Pokemon chosen as pbMark is called; the speech starts empty.
  def mark_in_pc(storage, selected, held, keys)
    scene = PokemonStorageScene.new(storage)
    with_keys do |pressed|
      scene.marking_loop = storage_loop(keys, pressed)
      SpeakCapture.clear
      scene.pbMark(selected, held)
    end
  end

  # Where the cursor goes on each arrow, as every copy's loop moves it (anil/303_UI_Summary.rb:1153-1195).
  def cursor_after(key, index)
    case key
    when :up then index == 7 ? 6 : (index == 6 ? 4 : (index < 3 ? 7 : index - 3))
    when :down then index == 7 ? 1 : (index == 6 ? 7 : (index >= 3 ? 6 : index + 3))
    when :left then index < 6 ? (index % 3 == 0 ? index + 2 : index - 1) : index
    when :right then index < 6 ? (index % 3 == 2 ? index - 2 : index + 1) : index
    else index
    end
  end

  # A mark after the button: a bit flipped (v17, v19) or a value cycled through the picture's rows (v20 and later).
  def mark_after(markings, index, variants)
    return markings ^ (1 << index) if markings.is_a?(Integer)
    markings[index] = ((markings[index] || 0) + 1) % variants
    markings
  end

  # The summary's loop (anil/303_UI_Summary.rb:1084-1195), replayed in the scene a frame per key, since its cursor and
  # marks live in its locals. top is where the grid's first row stands: 144 in vanilla, 148 in the SV summary.
  def summary_loop(keys, pressed, top, painted)
    move = method(:cursor_after)
    toggle = method(:mark_after)
    rows = lambda { |name| painted ? [["Marcar a #{name}", 366, 102], ["OK", 366, 254], ["Cancelar", 366, 304]] : [] }
    lambda do |pokemon|
      sel = Struct.new(:x, :y).new(0, 0)
      @sprites = { "markingsel" => sel }
      variants = @markingbitmap.bitmap.height / self.class::MARK_HEIGHT
      markings = pokemon.markings.is_a?(Array) ? pokemon.markings.clone : pokemon.markings
      index = 0
      redraw = true
      keys.each do |k|
        if redraw
          pbDrawTextPositions(nil, rows.call(pokemon.name))
          redraw = false
        end
        sel.x = index < 6 ? 284 + 58 * (index % 3) : 284
        sel.y = index < 6 ? top + 50 * (index / 3) : top + (index == 6 ? 100 : 150)
        pressed[0] = k
        Input.update
        if k == :use && index < 6
          markings = toggle.call(markings, index, variants)
          redraw = true
        elsif k == :action && markings.is_a?(Array) && index < 6 && markings[index] > 0
          markings[index] = 0
          redraw = true
        else
          index = move.call(k, index)
        end
      end
      markings
    end
  end

  # A summary loop that only moves the cursor sprite through points, a frame each, the first where it starts.
  def cursor_loop(points)
    lambda do |_pokemon|
      sel = Struct.new(:x, :y).new(0, 0)
      @sprites = { "markingsel" => sel }
      points.each do |(x, y)|
        sel.x = x
        sel.y = y
        Input.update
      end
    end
  end

  # The PC's loop (anil/314_UI_PokemonStorage.rb:1466-1544), run in the scene: the title painted twice with
  # drawTextEx (set, then fitted), the buttons in a positions batch, the arrow moved through pbMarkingSetArrow; no
  # action button.
  def storage_loop(keys, pressed)
    move = method(:cursor_after)
    toggle = method(:mark_after)
    lambda do |selected, heldpoke|
      msg = "Marca a tu Pokemon."
      drawTextEx(nil, 0, 0, 332, 1, msg)
      drawTextEx(nil, 0, 0, 332, 1, msg)
      pokemon = heldpoke || (selected[0] == -1 ? @storage.party[selected[1]] : @storage[selected[0], selected[1]]) rescue nil
      markings = pokemon ? (pokemon.markings.is_a?(Array) ? pokemon.markings.clone : pokemon.markings) : 0
      index = 0
      redraw = true
      keys.each do |k|
        if redraw
          pbDrawTextPositions(nil, [["OK", 402, 216], ["Cancelar", 402, 280]])
          pbMarkingSetArrow(nil, index)
          redraw = false
        end
        pressed[0] = k
        Input.update
        if [:up, :down, :left, :right].include?(k)
          index = move.call(k, index)
          pbMarkingSetArrow(nil, index)
        elsif k == :use && index < 6
          markings = toggle.call(markings, index, 2)
          redraw = true
        end
      end
      markings
    end
  end
end
