# The challenge / randomizer rule editor: each rule's state from its toggle number, said through the mod's i18n; the
# descriptions of nested lists and the rule summary, driven through the game's own windows and module functions. The
# plugin's hooks on the rule list and its summary wiring are evaluated again over the stand-ins below, which did not
# exist when the harness loaded it; its text window hook bound then, on the stubs' Window_AdvancedTextPokemon, whose
# constructor gives the text through text= as the game's does.

class FakeRuleWindow
  def initialize(cmds, keys = nil); @commands = cmds; @text_key = keys; end
end

# The rule list both plugins open (Window_CommandPokemon_Challenge, a Window_CommandPokemon in the game), which the
# screen disposes as it closes. It stands under the game's name while the hooks bind, and the name is given back: the
# plugin smoke suite builds a window of its own under it.
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

challenge_rules = File.join(Harness::ROOT, "plugins", "challenge_rules.rb")
challenge_src = File.read(challenge_rules)
challenge_held = Object.const_defined?(:Window_CommandPokemon_Challenge) ? Window_CommandPokemon_Challenge : nil
begin
  Object.send(:remove_const, :Window_CommandPokemon_Challenge) if challenge_held
  Object.const_set(:Window_CommandPokemon_Challenge, ChallengeRuleList)
  eval(challenge_src.scan(/^PokeAccess::Hooks\.\w+\("Window_CommandPokemon_Challenge".*?^end\r?\n/m).join +
       challenge_src.scan(/^%w\[.*wire_summary.*\n/).join, TOPLEVEL_BINDING, challenge_rules)
ensure
  Object.send(:remove_const, :Window_CommandPokemon_Challenge)
  Object.const_set(:Window_CommandPokemon_Challenge, challenge_held) if challenge_held
end

Suite.define("challenge rules: the toggle is spoken, from either shape of the command list") do
  cr = PokeAccess::ChallengeRules
  on  = PokeAccess::I18n.t(:val_on)
  off = PokeAccess::I18n.t(:val_off)

  paired =FakeRuleWindow.new([["Nuzlocke", 1], ["Nivel máximo", 0], ["Confirmar", nil]])
  eq "an enabled rule", cr.text(paired, 0), "Nuzlocke, #{on}"
  eq "a disabled one", cr.text(paired, 1), "Nivel máximo, #{off}"
  eq "and the trailing option has no state to speak", cr.text(paired, 2), "Confirmar"

  split =FakeRuleWindow.new(["Nuzlocke", "Nivel máximo", "Confirmar"], [1, 0, nil])
  eq "the split shape reads the same", cr.text(split, 0), "Nuzlocke, #{on}"
  eq "for the disabled rule too", cr.text(split, 1), "Nivel máximo, #{off}"
  eq "and the trailing option stays plain", cr.text(split, 2), "Confirmar"

  eq "an index past the list says nothing", cr.text(split, 9), nil
end

# A question pbMessage asks with the list open (in the description strip's window class) is the dialogue reader's.
Suite.define("challenge rules: a question asked with the list open is said once") do
  strip = Window_AdvancedTextPokemon.new("")
  list = ChallengeRuleList.new([["Nuzlocke", 0], "Confirmar"])
  begin
    SpeakCapture.clear
    strip.text = "Pierdes la partida si se debilita todo el equipo."
    spoke "the focused rule's description is read as its strip is given it", /debilita todo el equipo/
    SpeakCapture.clear
    PokeAccess.message_enter
    begin
      Window_AdvancedTextPokemon.new("Borrar la seleccion actual de modificadores?")
    ensure
      PokeAccess.message_leave
    end
    silent "the question is the dialogue reader's alone"
  ensure
    list.dispose
    PokeAccess::ChallengeRules.reset
  end
end

# A rule's description is one of the descriptions the verbosity leaves to full; the info key has it at any level.
Suite.define("challenge rules: a rule's description waits for full, and the info key keeps it") do
  strip = Window_AdvancedTextPokemon.new("")
  list = ChallengeRuleList.new([["Nuzlocke", 0], ["Modo vidas", 0], "Confirmar"])
  PokeAccess::Config.verbosity = :medium
  begin
    SpeakCapture.clear
    strip.text = "Pierdes la partida si se debilita todo el equipo."
    silent "medium: the description is not read"
    eq "and the info key has it", PokeAccess::Info.info_text, "Pierdes la partida si se debilita todo el equipo."
    Window_AdvancedTextPokemon.new("Elige con cuántas vidas quieres jugar (entre 1 y 100 como máximo).")
    eq "a question in a window of its own (how many lives) is said at any level", SpeakCapture.lines,
       ["Elige con cuántas vidas quieres jugar (entre 1 y 100 como máximo)."]
    SpeakCapture.clear
    strip.text = "Pierdes vidas al debilitarse."
    silent "while the strip goes on waiting for full"
  ensure
    PokeAccess::Config.verbosity = :full
    list.dispose
    PokeAccess::ChallengeRules.reset
  end
end

# The randomizer's generation list opens over its rule list and closes back onto it with dispose: the outer list's
# descriptions are read again, and the info key has the outer list's last one as soon as the inner list closes.
Suite.define("challenge rules: back from the generation list, the outer list's descriptions are read again") do
  strip = Window_AdvancedTextPokemon.new("")
  list = ChallengeRuleList.new([["Pokémon aleatorios", 1], ["Generaciones", nil], "Confirmar"])
  begin
    SpeakCapture.clear
    strip.text = "Los Pokémon salvajes serán aleatorios."
    eq "the outer list's description", SpeakCapture.lines, ["Los Pokémon salvajes serán aleatorios."]

    SpeakCapture.clear
    eq "the generation list keeps its own return", RandomizerConfigurator.select_gens(["Pokémon de la primera generación."]), {}
    eq "the generation list's own description, in its own strip", SpeakCapture.lines, ["Pokémon de la primera generación."]
    eq "as the generation list closes, the info key has the outer description back", PokeAccess::Info.info_text,
       "Los Pokémon salvajes serán aleatorios."

    SpeakCapture.clear
    strip.text = "Los movimientos serán aleatorios."
    eq "and the outer list's next description is read", SpeakCapture.lines, ["Los movimientos serán aleatorios."]

    list.dispose
    SpeakCapture.clear
    Window_AdvancedTextPokemon.new("Texto de otra pantalla.")
    silent "with every list closed, a text window is no description"
  ensure
    list.dispose
    PokeAccess::ChallengeRules.reset
  end
end

# The rule summary both plugins show before their confirmation (display_rules, which select_mode calls without a
# receiver): each page its full-screen window is given is said whole and cleaned, and nothing outside it.
Suite.define("challenge rules: the rule summary's pages are said as its window is given them, only while it is up") do
  pages = ["- Si un Pokémon se debilita, se considera muerto.\n- Tendrás 3 vidas, si las pierdes perderás el desafío.",
           "- El desafío comienza después de que hayas obtenido tu primera Poké Ball."]
  SpeakCapture.clear
  eq "the selection keeps its own return", ChallengeModes.select_mode([:PERMAFAINT], pages), [:PERMAFAINT]
  eq "each page as it is set, its bullets read as sentences, the window's first, empty text saying nothing",
     SpeakCapture.log,
     [["Si un Pokémon se debilita, se considera muerto. Tendrás 3 vidas, si las pierdes perderás el desafío.", true],
      ["El desafío comienza después de que hayas obtenido tu primera Poké Ball.", true]]
  eq "and the info key lets the last page go when it closes", PokeAccess::Info.info_text, nil

  SpeakCapture.clear
  RandomizerConfigurator.select_mode({ :GENS => [1] }, ["- Los Pokémon salvajes serán aleatorios."])
  eq "the randomizer's summary is said the same way", SpeakCapture.log, [["Los Pokémon salvajes serán aleatorios.", true]]

  SpeakCapture.clear
  Window_AdvancedTextPokemon.new("Borrar la seleccion actual de modificadores?")
  silent "outside the summary, with no rule list open, a text window says nothing"
end
