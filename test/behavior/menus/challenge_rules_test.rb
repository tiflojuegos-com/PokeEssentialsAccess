# The challenge and randomizer rule editors (plugins/challenge_rules.rb): each rule with its state, the focused rule's
# description, the outer list's back after a nested list closes, and the rule summary shown before confirming.

# The rule list both plugins open (Window_CommandPokemon_Challenge, a Window_CommandPokemon in the game), which the
# screen disposes as it closes. It stands under the game's name only while the plugin's hooks bind below, and the
# name is given back: the plugin smoke suite builds a window of its own under it.
class ChallengeRuleList
  def initialize(commands); @commands = commands; @disposed = false; end
  def commands=(commands); @commands = commands; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end

# Challenge Modes' module functions: select_mode shows the chosen rules' summary (display_rules, called without a
# receiver) before its confirmation; the summary is a full-screen text window given "" and then each page.
module ChallengeModes
  module_function

  def select_mode(rules, pages)
    display_rules(pages)
    rules
  end

  def display_rules(pages)
    info = Window_AdvancedTextPokemon.new("")
    pages.each { |page| info.text = page }
  end
end

# Randomizer EX's module functions: the generation list it opens over its rule list, with a description strip of its
# own and closed with dispose, and the same summary before its confirmation.
module RandomizerConfigurator
  module_function

  def select_gens(descs)
    info = Window_AdvancedTextPokemon.new("")
    list = ChallengeRuleList.new([["Primera generación", 1], "Confirmar"])
    descs.each { |desc| info.text = desc }
    list.dispose
    {}
  end

  def select_mode(rules, pages)
    display_rules(pages)
    rules
  end

  def display_rules(pages)
    info = Window_AdvancedTextPokemon.new("")
    pages.each { |page| info.text = page }
  end
end

challenge_path = File.join(Harness::ROOT, "plugins", "challenge_rules.rb")
challenge_src = Harness.source(challenge_path)
challenge_held = Object.const_defined?(:Window_CommandPokemon_Challenge) ? Window_CommandPokemon_Challenge : nil
begin
  Object.send(:remove_const, :Window_CommandPokemon_Challenge) if challenge_held
  Object.const_set(:Window_CommandPokemon_Challenge, ChallengeRuleList)
  [/^PokeAccess::Hooks\.\w+\("Window_CommandPokemon_Challenge".*?^end\r?\n/m, /^%w\[.*wire_summary.*\n/].each do |part|
    challenge_src.scan(part) do
      eval($~[0], TOPLEVEL_BINDING, challenge_path, challenge_src[0, $~.begin(0)].count("\n") + 1)
    end
  end
ensure
  Object.send(:remove_const, :Window_CommandPokemon_Challenge)
  Object.const_set(:Window_CommandPokemon_Challenge, challenge_held) if challenge_held
end

class ChallengeRulesTest < PokeAccessTest
  # A rule window as the reader reads it: rows as [name, toggle] pairs, or names with their toggles in @text_key.
  class RuleWindow
    def initialize(cmds, keys = nil); @commands = cmds; @text_key = keys; end
  end

  DESC = "Pierdes la partida si se debilita todo el equipo."
  LIVES = "Elige con cuántas vidas quieres jugar (entre 1 y 100 como máximo)."
  QUESTION = "Borrar la seleccion actual de modificadores?"

  test "a rule kept as a name and toggle pair says its state, a plain option just its name" do
    win = RuleWindow.new([["Nuzlocke", 1], ["Nivel máximo", 0], ["Confirmar", nil]])
    { 0 => "Nuzlocke, #{on}", 1 => "Nivel máximo, #{off}", 2 => "Confirmar" }.each do |i, row|
      assert_equal row, PokeAccess::ChallengeRules.text(win, i), "row #{i}"
    end
  end

  test "a rule whose toggle is kept apart, in @text_key, says its state the same" do
    win = RuleWindow.new(["Nuzlocke", "Nivel máximo", "Confirmar"], [1, 0, nil])
    { 0 => "Nuzlocke, #{on}", 1 => "Nivel máximo, #{off}", 2 => "Confirmar" }.each do |i, row|
      assert_equal row, PokeAccess::ChallengeRules.text(win, i), "row #{i}"
    end
  end

  test "a row past the list, a missing list or a row whose name is not text says nothing" do
    { "past the list" => [RuleWindow.new([["Nuzlocke", 1]]), 9], "no list" => [RuleWindow.new(nil), 0],
      "a toggled name that is no text" => [RuleWindow.new([[:NUZLOCKE, 1]]), 0],
      "a plain row that is no text" => [RuleWindow.new([[nil, nil]]), 0] }.each do |what, (win, i)|
      assert_nil PokeAccess::ChallengeRules.text(win, i), what
    end
  end

  test "the focused rule's description is said as its strip is given it, queued after the rule" do
    rule_list do |strip|
      strip.text = DESC
      assert_equal [[DESC, false]], SpeakCapture.log
    end
  end

  test "the same description given again is not said again" do
    rule_list do |strip|
      strip.text = DESC
      SpeakCapture.clear
      strip.text = DESC
      assert_nothing_spoken
    end
  end

  test "the info key keeps the focused rule's description" do
    rule_list do |strip|
      strip.text = DESC
      assert_equal DESC, PokeAccess::Info.info_text
    end
  end

  test "at medium a description is left to the info key" do
    PokeAccess::Config.verbosity = :medium
    rule_list do |strip|
      strip.text = DESC
      assert_nothing_spoken
      assert_equal DESC, PokeAccess::Info.info_text
    end
  end

  test "with help reading off a description is left to the info key" do
    PokeAccess::Config.read_help = false
    rule_list do |strip|
      strip.text = DESC
      assert_nothing_spoken
      assert_equal DESC, PokeAccess::Info.info_text
    end
  end

  test "a text in another window while the list is open is said at any level, cutting in" do
    PokeAccess::Config.verbosity = :medium
    rule_list do |strip|
      strip.text = DESC
      Window_AdvancedTextPokemon.new(LIVES)
      strip.text = "Pierdes vidas al debilitarse."
      assert_equal [[LIVES, true]], SpeakCapture.log
    end
  end

  test "a blank text says nothing and leaves the info key alone" do
    rule_list do |strip|
      strip.text = DESC
      SpeakCapture.clear
      strip.text = " \\c[2] "
      assert_nothing_spoken
      assert_equal DESC, PokeAccess::Info.info_text
    end
  end

  test "a question asked over the list in a message is the dialogue reader's alone" do
    rule_list do |strip|
      strip.text = DESC
      SpeakCapture.clear
      in_message { Window_AdvancedTextPokemon.new(QUESTION) }
      assert_nothing_spoken
    end
  end

  test "a list opened under a message reads its descriptions, and leaves a question over it to the dialogue reader" do
    in_message do
      rule_list do |strip|
        strip.text = DESC
        in_message { Window_AdvancedTextPokemon.new(QUESTION) }
        assert_equal [[DESC, false]], SpeakCapture.log
      end
    end
  end

  test "back from the generation list, the outer list's descriptions are read again" do
    rule_list([["Pokémon aleatorios", 1], ["Generaciones", nil], "Confirmar"]) do |strip|
      strip.text = "Los Pokémon salvajes serán aleatorios."
      SpeakCapture.clear
      RandomizerConfigurator.select_gens(["Pokémon de la primera generación."])
      assert_equal [["Pokémon de la primera generación.", false]], SpeakCapture.log, "the inner list's own description"
      assert_equal "Los Pokémon salvajes serán aleatorios.", PokeAccess::Info.info_text,
                   "as the inner list closes, the info key has the outer description back"
      SpeakCapture.clear
      strip.text = "Los movimientos serán aleatorios."
      assert_equal [["Los movimientos serán aleatorios.", false]], SpeakCapture.log, "the outer list's next description"
    end
  end

  test "back onto an outer list that has shown no description, the info key is left as it was" do
    rule_list([["Pokémon aleatorios", 1], ["Generaciones", nil], "Confirmar"]) do
      RandomizerConfigurator.select_gens(["Pokémon de la primera generación."])
      assert_equal "Pokémon de la primera generación.", PokeAccess::Info.info_text
    end
  end

  test "with every list closed, a text window is no description" do
    rule_list { |strip| strip.text = DESC }
    SpeakCapture.clear
    PokeAccess::Info.set_info(nil, nil)
    Window_AdvancedTextPokemon.new("Texto de otra pantalla.")
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text
  end

  test "a list that cannot say whether it is open counts as closed" do
    shut = Object.new
    def shut.disposed?; raise "the window is gone"; end
    PokeAccess::ChallengeRules.arm(shut)
    Window_AdvancedTextPokemon.new(DESC)
    assert_nothing_spoken
  end

  test "closing a list keeps what the game's dispose returns" do
    assert_equal true, ChallengeRuleList.new(["Confirmar"]).dispose
  end

  test "a toggle rebuilding the list clears its row's dedup, so the command reader reads the row again" do
    list = ChallengeRuleList.new([["Nuzlocke", 0], "Confirmar"])
    PokeAccess::Cursor.store(list, :cmd_focus, [0, nil, "Nuzlocke"])
    list.commands = [["Nuzlocke", 1], "Confirmar"]
    assert_nil PokeAccess::Cursor.current(list, :cmd_focus)
  ensure
    list.dispose if list
  end

  test "a toggle rebuilding the list leaves the info key on the last text shown over it" do
    rule_list do |strip, list|
      strip.text = DESC
      Window_AdvancedTextPokemon.new(LIVES)
      list.commands = [["Nuzlocke", 0], ["Modo vidas", 1], "Confirmar"]
      assert_equal LIVES, PokeAccess::Info.info_text
    end
  end

  test "each page the summary's window is given is said whole, its bullets as sentences, cutting in" do
    pages = ["- Si un Pokémon se debilita, se considera muerto.\n" \
             "- Tendrás 3 vidas, si las pierdes perderás el desafío.",
             "- El desafío comienza después de que hayas obtenido tu primera Poké Ball."]
    ChallengeModes.select_mode([:PERMAFAINT], pages)
    first = "Si un Pokémon se debilita, se considera muerto. Tendrás 3 vidas, si las pierdes perderás el desafío."
    second = "El desafío comienza después de que hayas obtenido tu primera Poké Ball."
    assert_equal [[first, true], [second, true]], SpeakCapture.log
  end

  test "the randomizer's summary is said the same way" do
    page = "- Los Pokémon salvajes serán aleatorios.\r\n\r\n- Sin objetos."
    RandomizerConfigurator.select_mode({ :GENS => [1] }, [page])
    assert_equal [["Los Pokémon salvajes serán aleatorios. Sin objetos.", true]], SpeakCapture.log
  end

  test "the summary keeps what the game's display_rules returns" do
    pages = ["- Sin objetos."]
    assert_same pages, ChallengeModes.display_rules(pages)
  end

  test "the info key has the summary's last page while it is up, and lets it go as it closes" do
    in_summary do
      Window_AdvancedTextPokemon.new("- Sin objetos.")
      assert_equal "Sin objetos.", PokeAccess::Info.info_text, "while it is up"
    end
    assert_nil PokeAccess::Info.info_text, "once it closes"
  end

  test "a summary shown from inside another keeps the info key's page until the outer one closes" do
    in_summary do
      ChallengeModes.display_rules(["- Sin objetos."])
      assert_equal "Sin objetos.", PokeAccess::Info.info_text, "the inner one closed"
    end
    assert_nil PokeAccess::Info.info_text, "the outer one closed"
  end

  test "a summary page of blank bullets says nothing" do
    in_summary { Window_AdvancedTextPokemon.new("-\n- \\c[1]\n") }
    assert_nothing_spoken
  end

  test "outside the summary, with no rule list open, a text window says nothing" do
    ChallengeModes.select_mode([:PERMAFAINT], ["- Sin objetos."])
    SpeakCapture.clear
    Window_AdvancedTextPokemon.new(QUESTION)
    assert_nothing_spoken
  end

  private

  def on; PokeAccess::I18n.t(:val_on); end
  def off; PokeAccess::I18n.t(:val_off); end

  # Runs the block with a description strip and, opened after it, a rule list of rows, both handed to the block; the
  # list is closed after.
  def rule_list(rows = [["Nuzlocke", 0], ["Modo vidas", 0], "Confirmar"])
    strip = Window_AdvancedTextPokemon.new("")
    list = ChallengeRuleList.new(rows)
    yield strip, list
  ensure
    list.dispose if list
  end

  # Runs the block with a rule summary up, as display_rules marks it, closed after.
  def in_summary
    PokeAccess::ChallengeRules.summary_open
    yield
  ensure
    PokeAccess::ChallengeRules.summary_close
  end

  # Runs the block inside one more message the game shows.
  def in_message
    PokeAccess.message_enter
    yield
  ensure
    PokeAccess.message_leave
  end
end
