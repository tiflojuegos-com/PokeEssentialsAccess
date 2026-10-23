# Anil's online play (plugins/cable_club.rb, with the countdown of games/anil/cableclub.rb), gamedata pass: the lines
# the Cable Club scene writes straight onto its message box, the waiting dots, the team preview read once as its card
# is drawn, and the countdown under the card with the key hint Anil's copy adds.

# The team preview card: its two teams painted at once, and the countdown a timer sprite shows, refreshed each frame.
class AnilTeamPreviewStub
  def initialize; @sprites = { "timer" => Struct.new(:text).new("") }; end
  def pbDrawTeamPreviewText(_l, _r, _lp, _rp); :drawn; end
  def update; end
  def tick(text); @sprites["timer"].text = text; update; end
end

# The Cable Club scene's writers, each blocking in the game; the text field returns what was typed.
class AnilCableClubStub
  def pbShowCommands(_helptext, _commands, _cmd_if_cancel = 0); 0; end
  def pbDisplay(_text); :displayed; end
  def pbDisplayDots(_text); :dots; end
  def pbEnterText(_helptext, _starttext, _passwordbox, _maxlength, _regex_check = nil); "12345678"; end
end

# The plugin binds to both stand-ins under the scenes' names, the profile's countdown after it, taken away again so no
# other test finds the plugin.
begin
  scenes = { :TeamPreview_Scene => AnilTeamPreviewStub, :CableClub_Scene => AnilCableClubStub }
  scenes.each { |name, stub| Object.const_set(name, stub) }
  [%w[plugins cable_club.rb], %w[games anil cableclub.rb]].each do |parts|
    path = File.join(Harness::ROOT, *parts)
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  end
ensure
  scenes.each_key { |name| Object.send(:remove_const, name) if Object.const_defined?(name) }
end

class AnilTeamPreviewGdTest < PokeAccessTest
  # A party member as the card reads it.
  Mon = Struct.new(:name, :gender, :item, :mail)
  HINT = "(pulsa X para salir ya)"

  test "reads both teams as the card is drawn, in one line, queued" do
    preview("Rojo", "Azul", [Mon.new("Pikachu", 0), Mon.new("Magnemite", 2)], [Mon.new("Eevee", 1)])
    assert_equal [["#{team("Rojo", "Pikachu ♂, Magnemite")}. #{team("Azul", "Eevee ♀")}", false]], SpeakCapture.log
  end

  test "names each member with the sex sign the card paints, and none for a genderless one" do
    { 0 => "Pikachu ♂", 1 => "Pikachu ♀", 2 => "Pikachu", nil => "Pikachu" }.each do |gender, shown|
      SpeakCapture.clear
      preview("Rojo", "Azul", [Mon.new("Pikachu", gender)], [Mon.new("Eevee", 1)])
      assert_equal ["#{team("Rojo", shown)}. #{team("Azul", "Eevee ♀")}"], SpeakCapture.lines,
                   "gender #{gender.inspect}"
    end
  end

  test "says a member holds something without naming the item, a letter's own icon for mail" do
    { [:LIGHTBALL, nil] => :cc_preview_holds, [:GRASSMAIL, :letter] => :cc_preview_mail }.each do |(item, mail), key|
      SpeakCapture.clear
      preview("Rojo", "Azul", [Mon.new("Eevee", 1, item, mail)], [Mon.new("Pikachu", 0)])
      shown = PokeAccess::I18n.t(key, :name => "Eevee ♀")
      assert_equal ["#{team("Rojo", shown)}. #{team("Azul", "Pikachu ♂")}"], SpeakCapture.lines,
                   "item #{item.inspect}"
    end
  end

  test "reads a side with no party as its trainer alone" do
    preview("Rojo", "Azul", [Mon.new("Pikachu", 0)], nil)
    assert_equal ["#{team("Rojo", "Pikachu ♂")}. #{team("Azul", "")}".strip], SpeakCapture.lines
  end

  test "keeps the card's own return" do
    assert_equal :drawn, preview("Rojo", "Azul", [], [])
  end

  test "says the countdown with its hint on its first second, and nothing on the seconds after" do
    card = AnilTeamPreviewStub.new
    card.tick("<ac>00:30 #{HINT}")
    card.tick("<ac>00:29 #{HINT}")
    assert_equal [["00:30 #{HINT}", false]], SpeakCapture.log
  end

  test "says the countdown without the key that leaves while hints are off" do
    PokeAccess::Config.verbosity = :brief
    AnilTeamPreviewStub.new.tick("<ac>00:28 #{HINT}")
    assert_equal ["00:28"], SpeakCapture.lines
  end

  test "keeps a bracketed note that is no key hint while hints are off" do
    PokeAccess::Config.verbosity = :brief
    AnilTeamPreviewStub.new.tick("<ac>00:28 (ronda 2)")
    assert_equal ["00:28 (ronda 2)"], SpeakCapture.lines
  end

  test "says the timer again once its words change" do
    card = AnilTeamPreviewStub.new
    card.tick("<ac>00:01 #{HINT}")
    card.tick("<ac>Esperando al rival")
    assert_equal ["00:01 #{HINT}", "Esperando al rival"], SpeakCapture.lines
  end

  test "says nothing for a blank timer" do
    card = AnilTeamPreviewStub.new
    ["", "   "].each { |text| card.tick(text) }
    assert_nothing_spoken
  end

  test "says the line the scene writes over its commands, queued, and keeps the choice" do
    choice = AnilCableClubStub.new.pbShowCommands("¿Qué quieres hacer?", ["Combatir", "Salir"])
    assert_equal [0, [["¿Qué quieres hacer?", false]]], [choice, SpeakCapture.log]
  end

  test "says each message the scene displays, cleaned and queued" do
    ret = AnilCableClubStub.new.pbDisplay("\\c[1]Conectando con el servidor.")
    assert_equal [:displayed, [["Conectando con el servidor.", false]]], [ret, SpeakCapture.log]
  end

  test "says the waiting line once however often its dots are redrawn" do
    club = AnilCableClubStub.new
    rets = Array.new(3) { club.pbDisplayDots("Esperando al otro jugador") }
    assert_equal [[:dots] * 3, [["Esperando al otro jugador", false]]], [rets, SpeakCapture.log]
  end

  test "says the waiting line again after a message in between" do
    club = AnilCableClubStub.new
    club.pbDisplayDots("Esperando al otro jugador")
    club.pbDisplay("Conexión establecida.")
    club.pbDisplayDots("Esperando al otro jugador")
    assert_equal ["Esperando al otro jugador", "Conexión establecida.", "Esperando al otro jugador"],
                 SpeakCapture.lines
  end

  test "says the label over the room's code field and that the field is empty as it opens, queued" do
    code = AnilCableClubStub.new.pbEnterText("Código de la sala:", "", false, 8, /[0-9]/)
    shown = "Código de la sala: #{PokeAccess::I18n.t(:row_empty)}"
    assert_equal ["12345678", [[shown, false]]], [code, SpeakCapture.log]
  end

  private

  # Draws a preview card for the two trainers and their parties, answering the card's return.
  def preview(left, right, left_party, right_party)
    AnilTeamPreviewStub.new.pbDrawTeamPreviewText(left, right, left_party, right_party)
  end

  # A trainer's team as the preview says it.
  def team(trainer, members)
    PokeAccess::I18n.t(:cc_preview_team, :trainer => trainer, :team => members)
  end
end
