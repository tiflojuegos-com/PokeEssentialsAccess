# World Frontier's records, gamedata pass: the facilities' battle recorder (games/worldfrontier/battle_history.rb),
# the battle's turn log with its key in the battle info's selection, and the credits (games/worldfrontier/credits.rb).

# The controls key its constants name lives in royal_common's controls reader, which another test evaluates.
module PokeAccess
  module RoyalControls
    class << self
      attr_accessor :key
    end
  end
end

# The recorder's texts as its config paints them.
module BattleHistoryConfig
  TITLE_TEXT = "Historial de Batallas"
  def self.text_no_battles; "No tienes combates guardados."; end
  def self.text_sort_hint; "D: Orden"; end
  def self.text_player_team; "Tu equipo"; end
  def self.text_opponent_team; "Equipo rival"; end
end

# A saved battle, as the list and its panel paint it.
WfRecord = Struct.new(:formatted_opponent, :outcome_text, :location_label, :formatted_date, :player_party,
                      :opponent_party)

# The recorder's list: the battles, the cursor and the replay coming back.
class BattleHistoryScene
  def initialize(battles); @battles = battles; @index = 0; end
  def pbRefresh; :list; end
  def pbResumeAfterPlayback; pbRefresh; :back; end
  def move(index); @index = index; pbRefresh; end
  def drop(index); @battles.delete_at(index); @index = [@index, @battles.length - 1].min; pbRefresh; end
end

# The turn log's texts, as its settings paint them.
module BattleTurnLog
  module Settings
    def self.title(turn); "Turno #{turn}"; end
    def self.current_turn_text(turn); "Turno actual: #{turn}"; end
    def self.back_text; "[X]: Atrás"; end
    def self.empty_text; "Aún no hay eventos en este combate."; end
    def self.hint_text; "[D]: Historial del combate"; end
    def self.hp_from_text(value, numeric = false, total = nil)
      numeric ? "PS: #{value}/#{total}" : "PS: #{value}%"
    end
    def self.hp_to_text(value, numeric = false, total = nil)
      numeric ? "#{value}/#{total}" : "#{value}%"
    end
  end

  # An event of the log: its pill, its line, the side it belongs to and what goes under it.
  class Event
    attr_accessor :category, :message, :side, :extras, :hp_from, :hp_to, :hp_from_raw, :hp_to_raw, :hp_total
    def initialize(category, message, side = :player, extras = []); @category = category; @message = message; @side = side; @extras = extras; end
    def player_side?; @side == :player; end
  end

  # The battle's log as the UI reads it.
  class Log
    def initialize(turns); @turns = turns; end
    def events_for(turn); @turns[turn] || []; end
    def current_turn_index; 4; end
  end

  # The log's screen: a page per turn, its rows laid out top to bottom and scrolled by pixels.
  class UI
    def initialize(log, turns); @log = log; @turns = turns; @turn_idx = 0; @scroll = 0; refresh; end
    def page(index); @turn_idx = index; @scroll = 0; refresh; end
    def scroll(px); @scroll = px; refresh; end

    private

    def current_turn; @turns[@turn_idx]; end
    def events; @log.events_for(current_turn); end
    def layout_rows; events.each_with_index.map { |ev, i| { :event => ev, :y => i * 60, :height => 50 } }; end
    def refresh; :painted; end
  end
end

# The battle info's selection, where World Frontier's log opens from.
class WfLogScene
  def initialize(toggle); @enhancedUIToggle = toggle; end
  def pbOpenBattleTurnLog; :log; end
end

# The credits' text sprite, as far as the scroll goes: where it sits on the screen.
WfCreditSprite = Struct.new(:y)

# The credits: the scrolling lines and the closing ones from creditos.txt, built into a sprite by build_text and laid
# out by line_spec, the scroll moved up by the pixels given, and the question to leave, said as the message reader
# says it.
module CreditosWF
  class Scene
    def initialize(lines, closing); @lines = lines; @closing_lines = closing; end
    def build_text; @text = WfCreditSprite.new(0); :built; end
    def line_spec(line); { :h => line.start_with?("<t>") ? 62 : 32 }; end
    def ask_to_leave; PokeAccess.say_dialogue("¿Salir de los créditos?"); @leave; end
    def run(leave_asked = nil, scrolled = 0)
      build_text
      @text.y = -scrolled
      @leave = leave_asked
      ask_to_leave unless leave_asked.nil?
      :ran
    end
  end
end

credits_was = PokeAccess::Credits.method(:raw_lines)
controls_was = PokeAccess::RoyalControls.key
%w[constants battle_history credits].each do |name|
  path = File.join(Harness::ROOT, "games", "worldfrontier", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end
WF_CREDIT_LINES = PokeAccess::Credits.method(:raw_lines)
CORE_CREDIT_LINES = credits_was
PokeAccess::Credits.define_singleton_method(:raw_lines, credits_was)
PokeAccess::RoyalControls.key = controls_was

class WorldfrontierRecordsGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  Event = BattleTurnLog::Event

  test "the recorder opens on its title and the first battle, then the sort key, and says each battle it moves to" do
    scene = BattleHistoryScene.new([record("Rojo", "Victoria"), record("Azul", "Derrota")])
    scene.pbRefresh
    scene.move(1)
    first = "Historial de Batallas. #{row('Rojo', 'Victoria', 1, 2)}"
    assert_equal [[first, false], [PokeAccess::KeyHints.localize("D: Orden"), false], [row("Azul", "Derrota", 2, 2), true]],
                 SpeakCapture.log
  end

  test "a battle says the rival and result at brief, its place and date from medium, both teams in full" do
    scene = BattleHistoryScene.new([record("Rojo", "Victoria")])
    lines = [:brief, :medium, :full].map do |level|
      PokeAccess::Config.verbosity = level
      PokeAccess::WfBattleHistory.row(scene.instance_variable_get(:@battles)[0], 0, 1)
    end
    placed = "Entrenador Rojo, Victoria, #{PokeAccess::Verbosity.position(1, 1)}. Torre Batalla. 01/10/2026 18:00"
    teams = "Tu equipo: Species#{:PIKACHU}. Equipo rival: Species#{:ONIX}"
    assert_equal ["Entrenador Rojo, Victoria", placed, "#{placed}. #{teams}"], lines
  end

  test "the recorder says the battle a deletion leaves focused, then the empty list's message" do
    scene = BattleHistoryScene.new([record("Rojo", "Victoria"), record("Azul", "Derrota")])
    scene.pbRefresh
    SpeakCapture.clear
    scene.drop(0)
    scene.drop(0)
    assert_equal [row("Azul", "Derrota", 1, 1), "No tienes combates guardados."], SpeakCapture.lines
  end

  test "back from a replay the recorder says its battle again, queued" do
    scene = BattleHistoryScene.new([record("Rojo", "Victoria")])
    scene.pbRefresh
    SpeakCapture.clear
    scene.pbResumeAfterPlayback
    assert_equal [[row("Rojo", "Victoria", 1, 1), false]], SpeakCapture.log
  end

  test "the turn log opens on its turn with every event, the current turn and the back key" do
    move = Event.new("Movimiento", "¡Pikachu usó Impactrueno!", :player, [{ :category => "Prioridad +0" }])
    log = BattleTurnLog::UI.new(BattleTurnLog::Log.new(3 => [move, hp_event]), [3])
    page = "Turno 3. Movimiento, ¡Pikachu usó Impactrueno! Prioridad +0. Reducción de PS, Onix. " \
           "#{I18n.t(:wf_log_hp, :from => 'PS: 80%', :to => '30%')}. Turno actual: 4"
    assert_equal [["#{page}. #{PokeAccess::KeyHints.localize('[X]: Atrás')}", false]], SpeakCapture.log
    assert log
  end

  test "the turn log says a whole turn it pages to, cutting in, and the event a scroll brings to the top" do
    first = Event.new("Cambio", "Rojo sacó a Pikachu.")
    log = BattleTurnLog::UI.new(BattleTurnLog::Log.new(1 => [first], 2 => [hp_event, first]), [1, 2])
    SpeakCapture.clear
    log.page(1)
    log.scroll(36)
    log.scroll(72)
    hp = "Reducción de PS, Onix. #{I18n.t(:wf_log_hp, :from => 'PS: 80%', :to => '30%')}"
    assert_equal [["Turno 2. #{hp}. Cambio, Rojo sacó a Pikachu.", true], ["Cambio, Rojo sacó a Pikachu.", true]],
                 SpeakCapture.log
  end

  test "the player's own hit points in the log are said exactly, as the log paints them" do
    ev = Event.new("Reducción de PS", "Pikachu", :player, [{ :hp_change => true }])
    ev.hp_from_raw = 50
    ev.hp_to_raw = 20
    ev.hp_total = 120
    assert_equal "Reducción de PS, Pikachu. #{I18n.t(:wf_log_hp, :from => 'PS: 50/120', :to => '20/120')}",
                 PokeAccess::WfTurnLog.event_text(ev)
  end

  test "an empty turn says the log's message" do
    BattleTurnLog::UI.new(BattleTurnLog::Log.new({}), [1])
    assert_match(/\ATurno 1\. Aún no hay eventos en este combate\. Turno actual: 4/, SpeakCapture.lines[0])
  end

  test "the battle info's selection says the log's key where World Frontier's log opens from it" do
    PokeAccess::WfTurnLog.selection_hint(WfLogScene.new(:battler))
    PokeAccess::WfTurnLog.selection_hint(WfLogScene.new(nil))
    PokeAccess::WfTurnLog.selection_hint(Object.new)
    assert_equal [[PokeAccess::KeyHints.localize("[D]: Historial del combate"), false]], SpeakCapture.log
  end

  test "the credits read their lines and the closing ones once built, without the heading marks" do
    with_credit_lines do
      CreditosWF::Scene.new(["<t>World Frontier", "Guion<s>Skyflyer", ""], ["<h>Gracias"]).run
    end
    assert_equal [["World Frontier. Guion, Skyflyer. Gracias.", false]], SpeakCapture.log
    refute PokeAccess::Credits.instance_variable_get(:@reading), "stopped once the roll ran"
  end

  test "the question to leave the credits cuts their reading, and declining reads on from the first line on screen" do
    stops = stops_during do
      with_credit_lines { CreditosWF::Scene.new(["<t>Equipo", "Guion", "Música"], ["Gracias"]).run(false, 70) }
    end
    assert_equal [["Equipo. Guion. Música. Gracias.", false], ["¿Salir de los créditos?", false],
                  ["Guion. Música. Gracias.", false]], SpeakCapture.log
    assert_equal [1, 3], stops, "cut before the question, then once the roll ran"
  end

  test "declining before any line has scrolled off reads the whole roll again" do
    with_credit_lines { CreditosWF::Scene.new(["Equipo"], []).run(false) }
    assert_equal [["Equipo.", false], ["¿Salir de los créditos?", false], ["Equipo.", false]], SpeakCapture.log
  end

  test "leaving the credits cuts their reading for the question and reads nothing after it" do
    stops = stops_during { with_credit_lines { CreditosWF::Scene.new(["Equipo"], []).run(true, 40) } }
    assert_equal [["Equipo.", false], ["¿Salir de los créditos?", false]], SpeakCapture.log
    assert_equal [1], stops, "the answer is not cut once the roll is left"
  end

  test "the core's roll keeps its own lines for any other credits scene" do
    other = Object.new
    assert_nil CORE_CREDIT_LINES.call(other)
    with_credit_lines { assert_nil PokeAccess::Credits.raw_lines(other) }
  end

  private

  # A saved battle against a rival, with one Pokemon a side.
  def record(name, outcome)
    WfRecord.new("Entrenador #{name}", outcome, "Torre Batalla", "01/10/2026 18:00", [[:PIKACHU, 0, 0, false]],
                 [[:ONIX, 0, 0, false]])
  end

  # A battle's row at full verbosity.
  def row(name, outcome, n, tot)
    head = PokeAccess::Verbosity.list_entry("Entrenador #{name}, #{outcome}", n, tot)
    "#{head}. Torre Batalla. 01/10/2026 18:00. Tu equipo: Species#{:PIKACHU}. Equipo rival: Species#{:ONIX}"
  end

  # A foe's loss of hit points, painted as percentages.
  def hp_event
    ev = Event.new("Reducción de PS", "Onix", :foe, [{ :hp_change => true }])
    ev.hp_from = 80
    ev.hp_to = 30
    ev
  end

  # The block's speech stops, each as how many lines had been spoken by then, the real stop put back after.
  def stops_during
    at = []
    original = PokeAccess.method(:stop_speech)
    PokeAccess.define_singleton_method(:stop_speech) { at.push(SpeakCapture.log.length); true }
    yield
    at
  ensure
    PokeAccess.define_singleton_method(:stop_speech, original)
  end

  # Runs the block with World Frontier's credit lines in the core's roll, put back after.
  def with_credit_lines
    was = PokeAccess::Credits.method(:raw_lines)
    PokeAccess::Credits.define_singleton_method(:raw_lines, WF_CREDIT_LINES)
    yield
  ensure
    PokeAccess::Credits.define_singleton_method(:raw_lines, was)
  end
end
