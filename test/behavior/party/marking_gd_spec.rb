# The marking screen of the summary and of the PC (v17 and later), six marks drawn as pictures; the game's own loop
# is replayed a frame per key, since its cursor and marks live in that loop's locals.

MARKING_KEYS = { :use => Input::C, :action => Input::A, :back => Input::B }

# Runs a spec with Input.trigger? answering for the key of the frame ($marking_key), as the game's loop asks.
def with_marking_keys
  trig = Input.method(:trigger?)
  Input.define_singleton_method(:trigger?) { |k| !$marking_key.nil? && MARKING_KEYS[$marking_key] == k }
  yield
ensure
  $marking_key = nil
  Input.define_singleton_method(:trigger?, trig)
end

# Where the cursor goes on each arrow, as every copy's loop moves it (anil/303_UI_Summary.rb:1153-1195).
def marking_move(key, index)
  case key
  when :up then index == 7 ? 6 : (index == 6 ? 4 : (index < 3 ? 7 : index - 3))
  when :down then index == 7 ? 1 : (index == 6 ? 7 : (index >= 3 ? 6 : index + 3))
  when :left then index < 6 ? (index % 3 == 0 ? index + 2 : index - 1) : index
  when :right then index < 6 ? (index % 3 == 2 ? index - 2 : index + 1) : index
  else index
  end
end

# A mark after the button: a bit flipped (v17, v19) or a value cycled through the picture's rows (v20 and later).
def marking_toggle(markings, index, variants)
  return markings ^ (1 << index) if markings.is_a?(Integer)
  markings[index] = ((markings[index] || 0) + 1) % variants
  markings
end

# A summary scene as pbStartScene leaves it, its marks picture `rows` tall, one row per state a mark can take.
def marking_summary_scene(rows = 2)
  scene = PokemonSummary_Scene.new
  picture = Struct.new(:height).new(PokemonSummary_Scene::MARK_HEIGHT * rows)
  scene.instance_variable_set(:@markingbitmap, Struct.new(:bitmap).new(picture))
  scene
end

# The summary's loop (anil/303_UI_Summary.rb:1084-1195). top is where the first row of the grid stands:
# 144 in vanilla, 148 in the SV summary, which moves the whole grid down.
def summary_marking(keys, top = 144)
  lambda do |pokemon|
    sel = Struct.new(:x, :y).new(0, 0)
    @sprites = { "markingsel" => sel }
    variants = @markingbitmap.bitmap.height / self.class::MARK_HEIGHT
    markings = pokemon.markings.is_a?(Array) ? pokemon.markings.clone : pokemon.markings
    index = 0
    redraw = true
    keys.each do |k|
      if redraw
        pbDrawTextPositions(nil, [["Marcar a #{pokemon.name}", 366, 102], ["OK", 366, 254], ["Cancelar", 366, 304]])
        redraw = false
      end
      sel.x = index < 6 ? 284 + 58 * (index % 3) : 284
      sel.y = index < 6 ? top + 50 * (index / 3) : top + (index == 6 ? 100 : 150)
      $marking_key = k
      Input.update
      if k == :use && index < 6
        markings = marking_toggle(markings, index, variants)
        redraw = true
      elsif k == :action && markings.is_a?(Array) && index < 6 && markings[index] > 0
        markings[index] = 0
        redraw = true
      else
        index = marking_move(k, index)
      end
    end
    markings
  end
end

def marked_poke(name, markings)
  pk = Poke.build(:name => name)
  pk.define_singleton_method(:markings) { markings }
  pk
end

Suite.define("marking: the summary grid says its title, the slot the cursor lands on, and each change") do
  t = PokeAccess::I18n
  scene = marking_summary_scene
  scene.marking_loop = summary_marking([nil, :right, :use, :down, :down, :down, nil])
  SpeakCapture.clear
  with_marking_keys { scene.pbMarking(marked_poke("Pika", [0, 1, 0, 0, 0, 0])) }
  eq "the painted title, then every slot and change, in the order they happen", SpeakCapture.lines,
     ["Marcar a Pika", "#{t.t(:mk_circle)}, #{t.t(:mk_off)}", "#{t.t(:mk_triangle)}, #{t.t(:mk_on)}",
      t.t(:mk_off), "#{t.t(:mk_star)}, #{t.t(:mk_off)}", "OK", "Cancelar"]
  eq "arriving at the screen waits for what was being said; after that the cursor interrupts",
     SpeakCapture.log.map { |l| l[1] }, [false, false, true, true, true, true, true]
end

Suite.define("marking: the SV summary's lower grid reads the same, buttons included") do
  t = PokeAccess::I18n
  scene = marking_summary_scene
  scene.marking_loop = summary_marking([nil, :down, :down, :down, nil], 148)
  SpeakCapture.clear
  with_marking_keys { scene.pbMarking(marked_poke("Pika", [0, 0, 0, 0, 0, 0])) }
  eq "measured from where the cursor starts, not from where vanilla puts it", SpeakCapture.lines,
     ["Marcar a Pika", "#{t.t(:mk_circle)}, #{t.t(:mk_off)}", "#{t.t(:mk_heart)}, #{t.t(:mk_off)}", "OK",
      "Cancelar"]
end

Suite.define("marking: a picture with more rows gives each mark colours, and the action button clears it") do
  t = PokeAccess::I18n
  scene = marking_summary_scene(4)
  scene.marking_loop = summary_marking([nil, :use, :use, :use, :action, :action])
  SpeakCapture.clear
  with_marking_keys { scene.pbMarking(marked_poke("Pika", [0, 0, 0, 0, 0, 0])) }
  eq "the button cycles the colours of the picture's rows and back, the action button clears",
     SpeakCapture.lines,
     ["Marcar a Pika", "#{t.t(:mk_circle)}, #{t.t(:mk_off)}", t.t(:mk_color, :n => 1), t.t(:mk_color, :n => 2),
      t.t(:mk_color, :n => 3), t.t(:mk_off)]
end

Suite.define("marking: v17 and v19 keep the marks as bits, and the button flips one") do
  t = PokeAccess::I18n
  scene = marking_summary_scene
  scene.marking_loop = summary_marking([nil, :right, :right, :use, :action])
  SpeakCapture.clear
  with_marking_keys { scene.pbMarking(marked_poke("Pika", 0b000100)) }
  eq "the square is read as set from its bit, flipping it says so, and the action button does nothing",
     SpeakCapture.lines,
     ["Marcar a Pika", "#{t.t(:mk_circle)}, #{t.t(:mk_off)}", "#{t.t(:mk_triangle)}, #{t.t(:mk_off)}",
      "#{t.t(:mk_square)}, #{t.t(:mk_on)}", t.t(:mk_off)]
end

# The PC's loop (anil/314_UI_PokemonStorage.rb:1466-1544): the title painted twice with drawTextEx (set, then
# fitted), the buttons in a positions batch, the arrow moved through pbMarkingSetArrow; no action button.
def storage_marking(keys)
  lambda do |selected, heldpoke|
    msg = "Marca a tu Pokemon."
    drawTextEx(nil, 0, 0, 332, 1, msg)
    drawTextEx(nil, 0, 0, 332, 1, msg)
    pokemon = heldpoke || (selected[0] == -1 ? @storage.party[selected[1]] : @storage[selected[0], selected[1]])
    markings = pokemon.markings.is_a?(Array) ? pokemon.markings.clone : pokemon.markings
    index = 0
    redraw = true
    keys.each do |k|
      if redraw
        pbDrawTextPositions(nil, [["OK", 402, 216], ["Cancelar", 402, 280]])
        pbMarkingSetArrow(nil, index)
        redraw = false
      end
      $marking_key = k
      Input.update
      if [:up, :down, :left, :right].include?(k)
        index = marking_move(k, index)
        pbMarkingSetArrow(nil, index)
      elsif k == :use && index < 6
        markings = marking_toggle(markings, index, 2)
        redraw = true
      end
    end
    markings
  end
end

# A PC storage shaped as the modern one the reader asks: party, and [box, slot] for a box.
def marking_storage(party, boxes)
  s = Object.new
  s.define_singleton_method(:party) { party }
  s.define_singleton_method(:[]) { |box, index| boxes[[box, index]] }
  s
end

Suite.define("marking: the PC grid says its message, the arrow's slot and each change") do
  t = PokeAccess::I18n
  boxed = marked_poke("Bulba", [1, 0, 0, 0, 0, 0])
  scene = PokemonStorageScene.new(marking_storage([], { [0, 3] => boxed }))
  scene.marking_loop = storage_marking([nil, :use, :down, :action, :down, nil])
  SpeakCapture.clear
  with_marking_keys { scene.pbMark([0, 3], nil) }
  eq "the message once, the Pokemon in the box slot read from its own marks, and no action button",
     SpeakCapture.lines,
     ["Marca a tu Pokemon.", "#{t.t(:mk_circle)}, #{t.t(:mk_on)}", t.t(:mk_off),
      "#{t.t(:mk_heart)}, #{t.t(:mk_off)}", "OK"]
end

Suite.define("marking: the PC marks the Pokemon held when there is one, and the party's by its slot") do
  t = PokeAccess::I18n
  held = marked_poke("Held", [0, 0, 1, 0, 0, 0])
  member = marked_poke("Member", [0, 0, 0, 0, 0, 1])
  scene = PokemonStorageScene.new(marking_storage([member], {}))
  scene.marking_loop = storage_marking([nil, :right, :right, nil])
  SpeakCapture.clear
  with_marking_keys { scene.pbMark([0, 0], held) }
  eq "the held one's square is set", SpeakCapture.lines.last, "#{t.t(:mk_square)}, #{t.t(:mk_on)}"

  scene.marking_loop = storage_marking([nil, :down, :right, :right, nil])
  SpeakCapture.clear
  with_marking_keys { scene.pbMark([-1, 0], nil) }
  eq "the party member's diamond is set", SpeakCapture.lines.last, "#{t.t(:mk_diamond)}, #{t.t(:mk_on)}"
end

Suite.define("marking: once the screen is closed nothing is watched") do
  SpeakCapture.clear
  with_marking_keys do
    $marking_key = :use
    Input.update
  end
  silent "a button pressed on another screen says no mark"
end
