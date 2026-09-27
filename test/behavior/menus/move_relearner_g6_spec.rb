# The gen-6 move relearner: the focused id (plain or an [id, tag] pair, nil with no selection) and its detail, and the
# stock screen driven through the reader's own hooks, which claim the list with @access_dedicated, never @ignore_input.

# The stock gen-6 relearner as Pokemon Z's 147 runs it: pbStartScene draws the move list; pbChooseMove updates once a
# frame, the cursor moving inside the update, and redraws the list when it moved; a declined question runs pbChooseMove
# again. No stub has this class, so core/menus/gen6/move_relearner_g6.rb is evaluated once more over it.
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

verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.join(Harness::ROOT, "core", "menus", "gen6", "move_relearner_g6.rb")
ensure
  $VERBOSE = verbose
end

# The focused id and detail from the scene's state; then, on the stock screen, opening claims the list for the reader
# without freezing its cursor, and says the focused move, as each redraw does.
Suite.define("gen-6 relearner: mutes the generic read without freezing the cursor") do
  mr = PokeAccess::MoveRelearnerGen6
  info = PokeAccess::MoveInfo
  saved = info.method(:by_id_via_data)
  begin
    info.define_singleton_method(:by_id_via_data) { |id, _reading = nil| "detalle de #{id}" }

    win = Object.new
    def win.index; @index; end
    def win.index=(v); @index = v; end
    win.index = 1

    scene = Object.new
    scene.instance_variable_set(:@sprites, { "commands" => win })
    scene.instance_variable_set(:@moves, [11, 22, 33])

    eq "a plain id is read straight", mr.focused_id(scene), 22
    scene.instance_variable_set(:@moves, [[11, "MT"], [22, "MT"], [33, "MT"]])
    eq "and a [id, tag] pair is unwrapped to its id", mr.focused_id(scene), 22

    win.index = -1
    eq "no selection speaks nothing, not the last move in the list", mr.focused_id(scene), nil
    win.index = 99
    eq "and neither does an index past the end", mr.focused_id(scene), nil
    win.index = 1

    SpeakCapture.clear
    mr.detail(scene)
    spoke "the focused move's full detail is spoken", /detalle de 22/

    live = MoveRelearnerScene.new
    SpeakCapture.clear
    eq "opening keeps the screen's own value", live.pbStartScene([[11, "MT"], [22, "MT"], [33, "MT"]], win), :started

    truthy "opening the screen marks the list as owned by a dedicated reader",
           win.instance_variable_get(:@access_dedicated)
    falsy "and does NOT set @ignore_input, which would freeze the player's cursor",
          win.instance_variable_get(:@ignore_input)
    spoke "the list drawn as it opens says the focused move", /detalle de 22/

    SpeakCapture.clear
    live.pbDrawMoveList
    spoke "each redraw speaks the focused move", /detalle de 22/
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
    SpeakCapture.clear
  end
end

# Pokemon Z's relearner lists the moves a machine teaches beside the ones relearned for free, and only the
# "MT" painted on the row tells them apart, so the detail says it first.
Suite.define("gen-6 relearner: a row's tag is said before the move's detail") do
  info = PokeAccess::MoveInfo
  saved = info.method(:by_id_via_data)
  begin
    info.define_singleton_method(:by_id_via_data) { |id, _reading = nil| "detalle de #{id}" }
    win = Object.new
    def win.index; 1; end
    scene = Object.new
    scene.instance_variable_set(:@sprites, { "commands" => win })
    scene.instance_variable_set(:@moves, [[11, ""], [22, "MT"]])
    SpeakCapture.clear
    PokeAccess::MoveRelearnerGen6.detail(scene)
    eq "the machine's row says so", SpeakCapture.lines, ["MT. detalle de 22"]
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    PokeAccess::MoveRelearnerGen6.detail(scene)
    eq "brief leaves the tag, a price, to the info key", SpeakCapture.lines, ["detalle de 22"]
    eq "which keeps it", PokeAccess::Info.info_text, "MT. detalle de 22"
    PokeAccess::Config.verbosity = :full
    scene.instance_variable_set(:@moves, [[11, ""], [22, ""]])
    SpeakCapture.clear
    PokeAccess::MoveRelearnerGen6.detail(scene)
    eq "a free one says only the move", SpeakCapture.lines, ["detalle de 22"]
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
  end
end

# Every row of the gen-6 relearner paints the move's PP, so the detail carries them too.
Suite.define("gen-6 relearner: the detail carries the PP the row paints") do
  t = PokeAccess::I18n
  line = PokeAccess::MoveInfo.by_id_via_data(7).to_s
  truthy "the move's PP, full, as the row writes it", line.include?(t.t(:mv_pp, :pp => 15, :tot => 15))
end

# On the moves page and the forget screen, the info key answers for the move under the cursor: the per-frame
# refresh of the shown Pokemon leaves it alone while the move cursor is up.
Suite.define("summary gen-6: the info key stays on the focused move while the move cursor is up") do
  pk = Poke.build(:name => "Chispa")
  scene = PokemonSummaryScene.new(pk)
  scene.instance_variable_set(:@sprites, { "movesel" => Struct.new(:visible).new(true) })
  PokeAccess::Info.set_info(:text, "movimiento enfocado")
  scene.pbUpdate
  eq "the refresh leaves it", PokeAccess::Info.info_text, "movimiento enfocado"
  scene.instance_variable_get(:@sprites)["movesel"].visible = false
  scene.pbUpdate
  match "and takes it back once the cursor is gone", PokeAccess::Info.info_text.to_s, /Chispa/
end

# Stand-ins for a move list and the older screen's (Insurgence, Uranium) message window.
module MoveRelearnerG6Spec
  def self.list(commands, index = 0)
    w = Object.new
    w.instance_variable_set(:@commands, commands)
    w.instance_variable_set(:@index, index)
    def w.index; @index; end
    def w.index=(v); @index = v; end
    w
  end

  def self.box(text = "")
    Struct.new(:text).new(text)
  end
end

Suite.define("gen-6 relearner, older screen (Insurgence, Uranium): the focused move's data, after the screen's question the first time") do
  info = PokeAccess::MoveInfo
  saved = info.method(:by_id_via_data)
  begin
    info.define_singleton_method(:by_id_via_data) { |id, reading = nil| reading ? "#{id} a nivel" : "#{id} entero" }
    scene = World.stub_scene(:@sprites => { "list" => MoveRelearnerG6Spec.list(["Placaje", "Gruñido", "CANCEL"]),
                                            "msgwindow" => MoveRelearnerG6Spec.box("¿Qué movimiento enseñar a Pikachu?") })
    r = PokeAccess::MoveRelearnerGen6
    r.refreshed(scene, 33)
    eq "the opening read joins the question and the move, queued", SpeakCapture.log,
       [["¿Qué movimiento enseñar a Pikachu? 33 a nivel", false]]
    eq "the info key keeps the whole move", PokeAccess::Info.info_text, "33 entero"
    SpeakCapture.clear
    r.refreshed(scene, 45)
    eq "later moves interrupt, without the question", SpeakCapture.log, [["45 a nivel", true]]
    SpeakCapture.clear
    scene.instance_variable_get(:@sprites)["list"].index = 2
    r.refreshed(scene, 0)
    eq "the CANCEL row by the list's own caption", SpeakCapture.lines, ["CANCEL"]
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
  end
end

# A declined question (Teach it? No, or Give up? No) runs pbChooseMove again over the same list, and nothing repaints
# the focused row: the loop's first update back says it again, and no other update does. The older screen (Insurgence,
# Uranium), which puts its question first, runs these hooks in insurgence_profile_spec and uranium_screens_spec.
Suite.define("gen-6 relearner: back on the list after a declined question, the focused row again") do
  info = PokeAccess::MoveInfo
  saved = info.method(:by_id_via_data)
  begin
    info.define_singleton_method(:by_id_via_data) { |id, reading = nil| reading ? "#{id} a nivel" : "#{id} entero" }
    scene = MoveRelearnerScene.new
    scene.pbStartScene([33, 45], MoveRelearnerG6Spec.list(["Placaje", "Gruñido"], 0))
    SpeakCapture.clear
    eq "the choice loop keeps the move it returns", scene.pbChooseMove, 33
    silent "the first run, right after the opening read, says nothing"
    scene.frames = [0, 0]
    scene.pbChooseMove
    eq "back from the question: the focused move's detail, on the loop's first update only", SpeakCapture.lines,
       ["33 a nivel"]
  ensure
    info.define_singleton_method(:by_id_via_data, saved)
  end
end
