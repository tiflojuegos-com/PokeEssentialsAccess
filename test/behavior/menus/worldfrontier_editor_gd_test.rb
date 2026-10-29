# World Frontier's Pokemon editor, gamedata pass (games/worldfrontier/estadisticas.rb): the hub's panels, the stat
# points editor, and the nature, ability, move and learnable move pickers, whose cursor lives in a local variable and
# is followed from what they draw for it or from the keys read as the cursor sound plays.

# The controls key its constants name lives in royal_common's controls reader, which another test evaluates.
module PokeAccess
  module RoyalControls
    class << self
      attr_accessor :key
    end
  end
end

# The cursor sound the pickers play when their cursor moves, and the decision, cancel and buzzer ones of their keys.
def pbPlayCursorSE; :cursor; end
def pbPlayDecisionSE; :decision; end
def pbPlayCancelSE; :cancel; end
def pbPlayBuzzerSE; :buzzer; end

# A nature as the editor reads it: its name and the stat changes its panel and grid show.
WfNature = Struct.new(:name, :stat_changes)

# A move of the Pokemon: its id and the PP and type its rows paint.
class WfMove
  attr_reader :id
  def initialize(id); @id = id; end
  def total_pp; 15; end
  def display_type(_pk); :ELECTRIC; end
end

# The Pokemon the editor works on, as far as its panels read it.
class WfMon
  attr_accessor :ev, :moves, :nature_for_stats, :nature_for_stats_id, :nature_id, :ability_index, :ability_id
  attr_reader :name
  def initialize(name)
    @name = name
    @ev = { :HP => 0, :ATTACK => 0, :DEFENSE => 0, :SPECIAL_ATTACK => 0, :SPECIAL_DEFENSE => 0, :SPEED => 0 }
    @moves = [WfMove.new(:THUNDERBOLT), nil, nil, nil]
    @nature_for_stats = WfNature.new("Firme", [[:ATTACK, 1], [:SPECIAL_ATTACK, -1]])
    @nature_for_stats_id = :ADAMANT
    @nature_id = :ADAMANT
    @ability_index = 0
    @ability_id = :STATIC
  end

  def ability; WfNature.new("Elec", []); end
  def totalhp; 100 + @ev[:HP]; end
  def attack; 50 + @ev[:ATTACK]; end
  def defense; 40; end
  def spatk; 60; end
  def spdef; 45; end
  def speed; 90; end
end

# The hub: a grid of panels and buttons over a working copy of the Pokemon.
class PokemonEditor_Scene
  GRID = [[:stats, :moves], [:nature, :ability], [:confirm, :reset, :exit]]
  attr_reader :working, :original
  def initialize(original, working); @original = original; @working = working; @cursor_row = 0; @cursor_col = 0; end
  def current_section; GRID[@cursor_row][@cursor_col]; end
  def pbRefresh; :hub; end
  def pbShow; pbRefresh; end
  def move(row, col); @cursor_row = row; @cursor_col = col; pbRefresh; end
end

# The stat points editor: the points per stat being set, the cursor, and the values they lead to.
class PokemonStatEditor_Scene
  def initialize(pkmn); @pkmn = pkmn; @working = pkmn.ev.dup; @cursor = 0; end
  def pbPreviewStats(working)
    base = { :HP => 100, :ATTACK => 50, :DEFENSE => 40, :SPECIAL_ATTACK => 60, :SPECIAL_DEFENSE => 45, :SPEED => 90 }
    out = {}
    base.each { |s, v| out[s] = v + working[s].to_i }
    out
  end
  def pbRefresh; :stats; end
  def cursor_to(i); @cursor = i; pbRefresh; end
  def set(points); @working[[:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED][@cursor]] = points; pbRefresh; end
end

# What each picker's loop does, set by the test: the frames it runs between opening and closing.
module WfEditorScript
  class << self
    attr_accessor :steps
  end
  def self.run(*args)
    (steps || []).each { |s| s.call(*args) }
  end
end

# The editor's pickers, each a loop of its own as WF Estadisticas writes them.
module WFEstadisticas
  MAX_TOTAL_POINTS = 66
  MAX_POINTS_PER_STAT = 32
  NATURE_AXIS = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
  CELLS = { [:ATTACK, :DEFENSE] => WfNature.new("Huraña", [[:ATTACK, 1], [:DEFENSE, -1]]),
            [:DEFENSE, :DEFENSE] => nil }
  NEUTRAL = { :DEFENSE => WfNature.new("Dócil", []) }

  module_function

  def _build_nature_lookup; [CELLS, NEUTRAL]; end
  def _locate_nature_cell(_current, _by_cell, _neutral); [0, 1]; end
  def _build_ability_options(_pkmn); [["Elec", 0, :STATIC], ["Pararrayos", 2, :LIGHTNINGROD]]; end
  def _draw_centered_wrapped(_overlay, text, *_rest); text; end
  def _draw_move_detail_panel(_overlay, _typebitmap, _catbitmap, _move, _pkmn = nil); :panel; end
  def move_is_protected?(_pkmn, id); id == :PROTECTED; end
  def pbChooseNature(current); WfEditorScript.run(current); :JOLLY; end
  def pbChooseAbility(pkmn); WfEditorScript.run(pkmn); 2; end
  def pbEditMoves(pkmn); WfEditorScript.run(pkmn); :done; end
  def pbChooseLearnableMove(pkmn, _replace = nil); WfEditorScript.run(pkmn); :SURF; end
end

controls_was = PokeAccess::RoyalControls.key
%w[constants estadisticas].each do |name|
  path = File.join(Harness::ROOT, "games", "worldfrontier", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end
PokeAccess::RoyalControls.key = controls_was

class WorldfrontierEditorGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  Editor = PokeAccess::WfEditor

  # A move's data as the editor's panels read it.
  MoveData = Struct.new(:id, :name, :power, :accuracy, :type, :category, :description, :total_pp, :function_code)

  def setup
    super
    WfEditorScript.steps = []
    Editor.instance_variable_set(:@frames, [])
  end

  test "the hub opens on its title and focused panel, then says each panel it moves to, marking what changed" do
    with_moves do
      orig = WfMon.new("Pikachu")
      work = WfMon.new("Pikachu")
      work.ev[:ATTACK] = 12
      hub = PokemonEditor_Scene.new(orig, work)
      hub.pbRefresh
      hub.move(0, 1)
      hub.move(1, 0)
      hub.move(2, 2)
      lines = SpeakCapture.lines
      attack = "#{I18n.t(:wf_ed_stat, :stat => 'StatATTACK', :total => 62, :n => 12)}, #{I18n.t(:wf_ed_changed)}"
      assert_match(/\AEDITAR A PIKACHU\. Estadísticas\. #{Regexp.escape(I18n.t(:wf_ed_stat, :stat => 'StatHP', :total => 100, :n => 0))}\. #{Regexp.escape(attack)}\./, lines[0])
      assert_equal PokeAccess::KeyHints.localize("[?]: Sets"), lines[1]
      move = PokeAccess::MoveInfo.line("Rayo", "TypeELECTRIC", nil, nil, :pp => 15, :total_pp => 15)
      assert_equal "Movimientos. #{move}. - vacío -. - vacío -. - vacío -", lines[2]
      nature = "Firme, #{I18n.t(:wf_nat_effect, :up => 'StatATTACK', :down => 'StatSPECIAL_ATTACK')}"
      assert_equal ["Naturaleza. #{nature}", "Salir sin cambiar"], lines[3..4]
    end
  end

  test "the hub says its focus again, queued, back from a sub-screen" do
    with_moves do
      hub = PokemonEditor_Scene.new(WfMon.new("Pikachu"), WfMon.new("Pikachu"))
      hub.move(2, 0)
      SpeakCapture.clear
      hub.pbShow
      assert_equal [["Confirmar cambios", false]], SpeakCapture.log
    end
  end

  test "the stat editor opens on the Pokemon, its nature and points, then says each row and each change of points" do
    stats = PokemonStatEditor_Scene.new(WfMon.new("Pikachu"))
    stats.pbRefresh
    stats.cursor_to(1)
    stats.set(10)
    lines = SpeakCapture.lines
    effect = I18n.t(:wf_nat_effect, :up => "StatATTACK", :down => "StatSPECIAL_ATTACK")
    hp = "StatHP 100, #{I18n.t(:wf_ed_points, :n => 0, :max => 32)}"
    assert_equal "EDITOR DE ESTADÍSTICAS. Pikachu. Naturaleza: Firme. #{effect}. #{hp}. " \
                 "#{I18n.t(:wf_ed_points, :n => 0, :max => 66)}. Disponibles: 66", lines[0]
    attack = "StatATTACK 60, +10, #{I18n.t(:wf_ed_points, :n => 10, :max => 32)}"
    assert_equal ["StatATTACK 50, #{I18n.t(:wf_ed_points, :n => 0, :max => 32)}", "#{attack}. Disponibles: 56"], lines[2..3]
  end

  test "the nature picker opens on the current cell and follows the keys its cursor sound plays for" do
    WfEditorScript.steps = [lambda { |_c| pressing(Input::DOWN) { pbPlayCursorSE } },
                            lambda { |_c| pressing(Input::LEFT) { pbPlayCursorSE } }]
    assert_equal :JOLLY, WFEstadisticas.pbChooseNature(:ADAMANT)
    hurana = "Huraña, #{I18n.t(:wf_nat_effect, :up => 'StatATTACK', :down => 'StatDEFENSE')}"
    assert_equal [["EDITOR DE NATURALEZA. #{hurana}", false], [PokeAccess::KeyHints.localize("[?]: Elegir [?]: Atrás"), false],
                  ["Dócil, Neutra", true]], SpeakCapture.log.values_at(0, 1, 2)
    assert_equal 3, SpeakCapture.log.length, "the empty cell the left key reaches says nothing"
  end

  test "the ability picker says the option whose description its panel draws, with its place" do
    WfEditorScript.steps = [lambda { |_p| WFEstadisticas._draw_centered_wrapped(nil, "Paraliza al contacto.") },
                            lambda { |_p| WFEstadisticas._draw_centered_wrapped(nil, "Atrae la electricidad.") }]
    with_abilities("STATIC" => "Paraliza al contacto.", "LIGHTNINGROD" => "Atrae la electricidad.") do
      assert_equal 2, WFEstadisticas.pbChooseAbility(WfMon.new("Pikachu"))
    end
    first = "EDITOR DE HABILIDAD. #{entry('Elec', 1, 2)}. Paraliza al contacto."
    assert_equal [[first, false], [PokeAccess::KeyHints.localize("[?]: Elegir [?]: Atrás"), false],
                  ["#{entry('Pararrayos', 2, 2)}. Atrae la electricidad.", true]], SpeakCapture.log
  end

  test "the move editor says its slots as the keys move its cursor, and a slot again when its move changes" do
    mon = WfMon.new("Pikachu")
    WfEditorScript.steps = [lambda { |_p| Editor.poll },
                            lambda { |_p| pressing(Input::DOWN) { pbPlayCursorSE }; Editor.poll },
                            lambda { |p| p.moves[1] = WfMove.new(:SURF); Editor.poll }]
    with_moves { WFEstadisticas.pbEditMoves(mon) }
    lines = SpeakCapture.lines
    rayo = "#{entry('Rayo', 1, 4)}. #{I18n.t(:mv_type, :t => 'TypeELECTRIC')}"
    assert_match(/\AEDITOR DE MOVIMIENTOS\. Pikachu\. #{Regexp.escape(rayo)}/, lines[0])
    assert_equal entry("- vacío -", 2, 4), lines[2]
    assert_match(/\A#{Regexp.escape(entry('Surf', 2, 4))}\. #{Regexp.escape(I18n.t(:mv_type, :t => 'TypeWATER'))}/, lines[3])
  end

  test "the move editor says the slot D marks for a swap, that mark as its cursor comes back to it, and the unmark" do
    mon = WfMon.new("Pikachu")
    WfEditorScript.steps = [lambda { |_p| Editor.poll },
                            lambda { |_p| pressing(Input::Z) { pbPlayDecisionSE }; Editor.poll },
                            lambda { |_p| pressing(Input::DOWN) { pbPlayCursorSE }; Editor.poll },
                            lambda { |_p| pressing(Input::UP) { pbPlayCursorSE }; Editor.poll },
                            lambda { |_p| pressing(Input::Z) { pbPlayCancelSE }; Editor.poll }]
    marked = nil
    with_moves do
      WFEstadisticas.pbEditMoves(mon)
      marked = Editor.slot_line(mon, 0, :summary_move, true)
    end
    assert_equal [[I18n.t(:wf_move_marked), true], [entry("- vacío -", 2, 4), true], [marked, true],
                  [I18n.t(:wf_move_unmarked), true]], SpeakCapture.log[2..-1]
    assert_match(/\A#{Regexp.escape(entry('Rayo', 1, 4))}, #{Regexp.escape(I18n.t(:wf_move_marked))}\./, marked)
  end

  test "a swap or the refusal to forget a move ends the mark silently, and a message's own sounds leave it be" do
    mon = WfMon.new("Pikachu")
    message = lambda { PokeAccess.message_enter; pressing(Input::C) { pbPlayDecisionSE }; PokeAccess.message_leave }
    swap = lambda { |p| pressing(Input::Z) { pbPlayDecisionSE }; p.moves[0], p.moves[1] = p.moves[1], p.moves[0] }
    WfEditorScript.steps = [lambda { |_p| Editor.poll },
                            lambda { |_p| pressing(Input::Z) { pbPlayDecisionSE }; message.call; Editor.poll },
                            lambda { |_p| pressing(Input::DOWN) { pbPlayCursorSE }; Editor.poll },
                            lambda { |p| swap.call(p); Editor.poll },
                            lambda { |_p| pressing(Input::Z) { pbPlayDecisionSE }; pbPlayBuzzerSE; Editor.poll },
                            lambda { |_p| pressing(Input::Z) { pbPlayDecisionSE }; Editor.poll }]
    moved = nil
    with_moves do
      WFEstadisticas.pbEditMoves(mon)
      moved = Editor.slot_line(mon, 1, :summary_move)
    end
    marked = [I18n.t(:wf_move_marked), true]
    assert_equal [marked, [entry("- vacío -", 2, 4), true], [moved, true], marked, marked], SpeakCapture.log[2..-1]
  end

  test "the learnable list says the move its panel draws with the place its counter paints, the title first" do
    surf = MoveData.new(:SURF, "Surf", 90, 100, :WATER, 1, "Una gran ola.", 15, "None")
    fly = MoveData.new(:FLY, "Vuelo", 90, 95, :FLYING, 0, "Vuela.", 15, "None")
    WfEditorScript.steps = [lambda { |p| draw_learnable(surf, p, "1 / 20") },
                            lambda { |p| draw_learnable(surf, p, "1 / 20") },
                            lambda { |p| draw_learnable(fly, p, "2 / 20") }]
    WFEstadisticas.pbChooseLearnableMove(WfMon.new("Pikachu"))
    lines = SpeakCapture.lines
    water = Regexp.escape(I18n.t(:mv_type, :t => "TypeWATER"))
    assert_match(/\AAPRENDER MOVIMIENTO\. #{Regexp.escape(entry('Surf', 1, 20))}\. #{water}/, lines[0])
    assert_match(/\A#{Regexp.escape(entry('Vuelo', 2, 20))}\. #{Regexp.escape(I18n.t(:mv_type, :t => 'TypeFLYING'))}/, lines[2])
    assert_equal 3, lines.length, "the same move drawn again says nothing"
  end

  test "the move editor's cursor waits while the learnable list it opens runs, and its slot is said again after" do
    mon = WfMon.new("Pikachu")
    slot = nil
    with_moves do
      Editor.moves(mon) do
        Editor.poll
        WfEditorScript.steps = [lambda { |_p| pressing(Input::DOWN) { pbPlayCursorSE }; Editor.poll }]
        WFEstadisticas.pbChooseLearnableMove(mon)
        SpeakCapture.clear
        Editor.poll
        slot = Editor.slot_line(mon, 0, :summary_move)
      end
    end
    assert_equal [[slot, false]], SpeakCapture.log
  end

  private

  # A list row with its place, as the verbosity in use says it.
  def entry(name, n, tot)
    PokeAccess::Verbosity.list_entry(name, n, tot)
  end

  # Runs the block with only key pressed and repeated, as the game's Input reports it.
  def pressing(key)
    meta = class << Input; self; end
    saved = [:repeat?, :trigger?].map { |m| [m, Input.method(m)] }
    [:repeat?, :trigger?].each { |m| meta.send(:define_method, m) { |k| k == key } }
    yield
  ensure
    saved.each { |m, original| meta.send(:define_method, m, original) }
  end

  # Runs the block with the move data the editor's panels read: names and types for the moves the tests use.
  def with_moves
    table = { :THUNDERBOLT => MoveData.new(:THUNDERBOLT, "Rayo", 90, 100, :ELECTRIC, 1, "Puede paralizar.", 15, "None"),
              :SURF => MoveData.new(:SURF, "Surf", 90, 100, :WATER, 1, "Una gran ola.", 15, "None") }
    meta = class << GameData::Move; self; end
    original = GameData::Move.method(:get)
    meta.send(:define_method, :get) { |id| table[id] || original.call(id) }
    yield
  ensure
    meta.send(:define_method, :get, original)
  end

  # Runs the block with the abilities' descriptions as given by id name.
  def with_abilities(descriptions)
    meta = class << GameData::Ability; self; end
    original = GameData::Ability.method(:get)
    meta.send(:define_method, :get) { |id| WfNature.new(id.to_s, descriptions[id.to_s]).tap { |a| def a.description; stat_changes; end } }
    yield
  ensure
    meta.send(:define_method, :get, original)
  end

  # One repaint of the learnable list: the side panel's move, then its counter, then the frame after.
  def draw_learnable(move, pkmn, counter)
    WFEstadisticas._draw_move_detail_panel(nil, nil, nil, move, pkmn)
    pbDrawTextPositions(nil, [["APRENDER MOVIMIENTO", 0, 0], [counter, 16, 400]])
    Editor.poll
  end
end
