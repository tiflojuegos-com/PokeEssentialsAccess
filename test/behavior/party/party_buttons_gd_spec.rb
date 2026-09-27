# The v19-v21 party screen, whose choose loop moves the cursor with selected= and never pbSelect: the buttons
# (Cancel; Confirm on the entry screen), the help line, the opening question and pbSelect's own moves.

def party_buttons_party
  [Poke.build(:name => "Bulba", :level => 12, :hp => 22, :totalhp => 22, :gender => 0),
   Poke.build(:name => "Charm", :level => 10, :hp => 20, :totalhp => 20, :gender => 1)]
end

Suite.define("v21 party: the cursor reaching the buttons names them, once per move") do
  scene = PokemonParty_Scene.new(party_buttons_party)
  cancel = Settings::MAX_PARTY_SIZE

  scene.move_cursor(1)
  SpeakCapture.clear
  scene.move_cursor(cancel)
  eq "moving onto the lone button says Cancel", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_cancel)]

  SpeakCapture.clear
  scene.move_cursor(cancel)
  silent "marking the same button again says nothing"

  SpeakCapture.clear
  scene.move_cursor(1)
  scene.move_cursor(cancel)
  spoke_once "coming back to it from a member says it again", /\A#{PokeAccess::I18n.t(:pc_cancel)}\z/
end

Suite.define("v21 party: in choose-entry mode Confirm and Cancel are told apart") do
  scene = PokemonParty_Scene.new(party_buttons_party, true)
  confirm = Settings::MAX_PARTY_SIZE

  scene.move_cursor(1)
  SpeakCapture.clear
  scene.move_cursor(confirm)
  eq "the first button of the row is Confirm", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_confirm)]

  SpeakCapture.clear
  scene.move_cursor(confirm + 1)
  eq "the one after it is Cancel", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_cancel)]
end

Suite.define("v21 party: the entry screen's jump to Confirm is said once") do
  scene = PokemonParty_Scene.new(party_buttons_party, true)
  scene.move_cursor(0)
  SpeakCapture.clear
  scene.pbSelect(Settings::MAX_PARTY_SIZE)
  eq "pbSelect onto Confirm says it exactly once", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_confirm)]

  SpeakCapture.clear
  scene.move_cursor(Settings::MAX_PARTY_SIZE)
  silent "the loop re-marking the button pbSelect already announced stays quiet"
end

# The help line under the party is the only sign that the panels changed purpose: read when it changes, not when a
# loop sets it again, and not while the screen keeps it out of sight.
Suite.define("v21 party: the help line is read when it changes, and only then") do
  scene = PokemonParty_Scene.new(party_buttons_party)
  scene.pbSetHelpText("Choose a Pokemon.")
  eq "the opening prompt is read, queued", SpeakCapture.log, [["Choose a Pokemon.", false]]

  SpeakCapture.clear
  scene.pbSetHelpText("Choose a Pokemon.")
  silent "setting it again, as a loop does every pass, says nothing"

  SpeakCapture.clear
  scene.pbSetHelpText("Move to where?")
  eq "a new purpose is said", SpeakCapture.lines, ["Move to where?"]

  hidden = PokemonParty_Scene.new(party_buttons_party)
  hidden.instance_variable_get(:@sprites)["helpwindow"] = Struct.new(:visible, :y).new(true, 1000)
  SpeakCapture.clear
  hidden.pbSetHelpText("Escoge un Pokemon.")
  silent "a help line the screen keeps out of sight is not said"
end

# pbStartScene sets the help line, then marks the first member: that member is queued behind the question.
Suite.define("v21 party: the opening question is heard, and the first member after it") do
  party = party_buttons_party
  scene = PokemonParty_Scene.new(party)
  panel = scene.instance_variable_get(:@sprites)["pokemon0"]
  scene.on_start = lambda do
    scene.pbSetHelpText("Use on which Pokemon?")
    panel.selected = true
  end
  SpeakCapture.clear
  scene.pbStartScene(party, "Use on which Pokemon?")
  log = SpeakCapture.log
  eq "the question first, queued", log[0], ["Use on which Pokemon?", false]
  eq "then the member, queued behind it", log[1][1], false
  eq "and nothing else", log.length, 2

  SpeakCapture.clear
  panel.selected = false
  scene.instance_variable_get(:@sprites)["pokemon1"].selected = true
  eq "a cursor move after the opening interrupts as before", SpeakCapture.log.map { |l| l[1] }, [true]
end

# The loops that send the cursor back to a member do it with pbSelect -- Softboiled returning to its user after
# the heal, a cancelled item swap returning to the holder -- and the guard around pbSelect mutes the panel hook.
Suite.define("v21 party: pbSelect sending the cursor back to a member says that member") do
  a = Poke.build(:name => "Chansey")
  b = Poke.build(:name => "Pikachu")
  scene = PokemonParty_Scene.new([a, b])
  scene.move_cursor(1)
  SpeakCapture.clear
  scene.pbSelect(0)
  match "the member the cursor lands on is said", SpeakCapture.lines.join(" "), /Chansey/
  SpeakCapture.clear
  scene.move_cursor(0)
  silent "and the loop re-marking the same panel stays quiet"
end

# Where the classic scene reports the cursor itself (Awakening, a gen-6 fork with the modern class name), the
# member or button is said as the list takes its choice, so pbSelect stands down or Confirm is said twice.
Suite.define("v21 party: pbSelect stands down, buttons included, where the scene reports the cursor itself") do
  ui = PokeAccess::UIV21
  scene = PokemonParty_Scene.new(party_buttons_party)
  ui.instance_variable_set(:@scene_reports, true)
  begin
    SpeakCapture.clear
    scene.pbSelect(6)
    silent "the button the entry screen lands on is left to the reader that says it with the choice"
  ensure
    ui.instance_variable_set(:@scene_reports, nil)
  end
end
