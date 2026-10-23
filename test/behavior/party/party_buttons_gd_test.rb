# The v19-v21 party screen, whose choose loop moves the cursor by selected= (pbSelect only jumps): the member or button
# it lands on (Cancel, or Confirm on the entry screen), the help line, the opening question and the Box Link key line.
class PartyButtonsGdTest < PokeAccessTest
  BUTTON = Settings::MAX_PARTY_SIZE
  MALE = " \xE2\x99\x82"
  FEMALE = " \xE2\x99\x80"

  test "names the lone button Cancel as the cursor reaches it" do
    scene = party_scene
    scene.move_cursor(1)
    SpeakCapture.clear
    scene.move_cursor(BUTTON)
    assert_equal [[word(:pc_cancel), true]], SpeakCapture.log
  end

  test "says nothing when the loop marks the same button again" do
    scene = party_scene
    scene.move_cursor(BUTTON)
    SpeakCapture.clear
    scene.move_cursor(BUTTON)
    assert_nothing_spoken
  end

  test "names the button again when the cursor comes back to it from a member" do
    scene = party_scene
    scene.move_cursor(BUTTON)
    scene.move_cursor(1)
    SpeakCapture.clear
    scene.move_cursor(BUTTON)
    assert_equal [[word(:pc_cancel), true]], SpeakCapture.log
  end

  test "tells the entry screen's Confirm from its Cancel" do
    { BUTTON => word(:pc_confirm), BUTTON + 1 => word(:pc_cancel) }.each do |idx, want|
      scene = party_scene(true)
      scene.move_cursor(1)
      SpeakCapture.clear
      scene.move_cursor(idx)
      assert_equal [[want, true]], SpeakCapture.log, "the button at #{idx}"
    end
  end

  test "says a button by the word it was built with" do
    scene = party_scene
    sprites(scene)["pokemon#{BUTTON}"] = PokemonPartyCancelSprite.new("SALIR")
    SpeakCapture.clear
    scene.move_cursor(BUTTON)
    assert_equal [["SALIR", true]], SpeakCapture.log
  end

  test "names a button built with no word by what its class is" do
    { PokemonPartyCancelSprite => word(:pc_cancel), PokemonPartyCancelSprite2 => word(:pc_cancel),
      PokemonPartyConfirmSprite => word(:pc_confirm), PokemonPartyConfirmCancelSprite => word(:pc_cancel) }.each do |cls, want|
      assert_equal want, PokeAccess::Party.button_label(cls.new), cls.name
    end
  end

  test "gives no button word for a sprite that is no button" do
    assert_nil PokeAccess::Party.button_label(PokemonPartyPanel.new(Poke.build))
  end

  test "says the entry screen's jump to Confirm once" do
    scene = party_scene(true)
    scene.move_cursor(0)
    SpeakCapture.clear
    scene.pbSelect(BUTTON)
    assert_equal [[word(:pc_confirm), true]], SpeakCapture.log
  end

  test "keeps quiet when the loop marks the button pbSelect just said" do
    scene = party_scene(true)
    scene.pbSelect(BUTTON)
    SpeakCapture.clear
    scene.move_cursor(BUTTON)
    assert_nothing_spoken
  end

  test "says the member pbSelect sends the cursor back to" do
    scene = party_scene
    scene.move_cursor(1)
    SpeakCapture.clear
    scene.pbSelect(0)
    assert_equal [[bulba_line, true]], SpeakCapture.log
  end

  test "keeps quiet when the loop marks the member pbSelect just said" do
    scene = party_scene
    scene.pbSelect(0)
    SpeakCapture.clear
    scene.move_cursor(0)
    assert_nothing_spoken
  end

  test "says pokerus in a member's empty state slot, which an ailment or fainting takes first" do
    { "pokerus alone" => [bulba(:pokerusStage => 1), "#{bulba_line}, #{word(:pk_pokerus)}"],
      "pokerus under an ailment" => [bulba(:pokerusStage => 1, :status => :POISON),
                                     "#{bulba_line}, #{GameData::Status.get(:POISON).name}"],
      "pokerus on a fainted member" => [bulba(:pokerusStage => 1, :hp => 0), "#{bulba_line(0)}, #{word(:pk_fainted)}"],
      "pokerus cured" => [bulba(:pokerusStage => 2), bulba_line] }.each do |what, (pk, want)|
      SpeakCapture.clear
      land_on(pk)
      assert_equal [want], SpeakCapture.lines, what
    end
  end

  test "says an egg's panel as an egg" do
    egg = bulba
    egg.define_singleton_method(:egg?) { true }
    land_on(egg)
    assert_equal [[word(:pty_egg), true]], SpeakCapture.log
  end

  test "keeps the whole line of the member it says for the info key, whatever the reading's level" do
    PokeAccess::Config.verbosity = :brief
    land_on(bulba)
    assert_equal [word(:pty_member_nolv, :name => "Bulba", :sex => "", :hp => 22, :tot => 22)], SpeakCapture.lines,
                 "said at the brief level"
    assert_equal bulba_line, PokeAccess::Info.row_text, "kept whole"
  end

  test "reads each new help line, queued" do
    scene = party_scene
    scene.pbSetHelpText("Choose a Pokemon.")
    scene.pbSetHelpText("Move to where?")
    assert_equal [["Choose a Pokemon.", false], ["Move to where?", false]], SpeakCapture.log
  end

  test "says nothing when the loop sets the same help line again" do
    scene = party_scene
    scene.pbSetHelpText("Choose a Pokemon.")
    SpeakCapture.clear
    scene.pbSetHelpText("Choose a Pokemon.")
    assert_nothing_spoken
  end

  test "keeps quiet about a help line its window hides or moves off screen" do
    { "a hidden window" => help_window(false, 0), "a window on the screen's bottom edge" => help_window(true, Graphics.height),
      "a window far below the screen" => help_window(true, 1000) }.each do |what, win|
      help_on(win)
      assert_nothing_spoken what
    end
  end

  test "reads a help line whose window stands on screen" do
    { "a window on the screen's last row" => help_window(true, Graphics.height - 1),
      "a window that cannot say whether it shows" => Struct.new(:y).new(100) }.each do |what, win|
      help_on(win)
      assert_equal ["Escoge un Pokemon."], SpeakCapture.lines, what
    end
  end

  test "queues the first member behind the opening question" do
    scene = party_scene
    panel = sprites(scene)["pokemon0"]
    scene.on_start = lambda do
      scene.pbSetHelpText("Use on which Pokemon?")
      panel.selected = true
    end
    SpeakCapture.clear
    scene.pbStartScene(party, "Use on which Pokemon?")
    assert_equal [["Use on which Pokemon?", false], [bulba_line, false]], SpeakCapture.log
  end

  test "interrupts with every cursor move after the opening" do
    scene = party_scene
    scene.on_start = lambda { scene.move_cursor(0) }
    scene.pbStartScene
    SpeakCapture.clear
    scene.move_cursor(1)
    assert_equal [[word(:pty_member, :name => "Charm, Species1", :sex => FEMALE, :level => 10, :hp => 20, :tot => 20), true]],
                 SpeakCapture.log
  end

  test "says the Box Link key line after the opening, while key hints are said" do
    open_with_box_link
    assert_equal [["[D]: Cajas del PC", false]], SpeakCapture.log
  end

  test "leaves the Box Link key line out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    open_with_box_link
    assert_nothing_spoken
  end

  test "stands down, members and buttons alike, where the scene reports the cursor itself" do
    { "the loop marking a member" => lambda { |s| s.move_cursor(1) },
      "the loop marking the button" => lambda { |s| s.move_cursor(BUTTON) },
      "pbSelect onto a member" => lambda { |s| s.pbSelect(1) },
      "pbSelect onto the button" => lambda { |s| s.pbSelect(BUTTON) } }.each do |what, act|
      scene = party_scene
      SpeakCapture.clear
      with_scene_reports { act.call(scene) }
      assert_nothing_spoken what
    end
  end

  private

  # The text of i18n key with args.
  def word(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Bulba, the first member: male, level 12, 22 HP of 22. opts :hp and :status set its own; any other name answers
  # its value.
  def bulba(opts = {})
    pk = Poke.build(:name => "Bulba", :level => 12, :hp => opts.fetch(:hp, 22), :totalhp => 22, :gender => 0,
                    :status => opts.fetch(:status, 0))
    opts.each { |name, v| pk.define_singleton_method(name) { v } unless [:hp, :status].include?(name) }
    pk
  end

  # Bulba's line as its panel says it in full, with hp left, the species its icon shows after the nickname.
  def bulba_line(hp = 22)
    word(:pty_member, :name => "Bulba, Species1", :sex => MALE, :level => 12, :hp => hp, :tot => 22)
  end

  # The two members of the party.
  def party
    [bulba, Poke.build(:name => "Charm", :level => 10, :hp => 20, :totalhp => 20, :gender => 1)]
  end

  # A party screen on the two members; entry for the entry screen, whose buttons are Confirm and Cancel.
  def party_scene(entry = false)
    PokemonParty_Scene.new(party, entry)
  end

  # The scene's sprites by name.
  def sprites(scene)
    scene.instance_variable_get(:@sprites)
  end

  # The cursor landing on a panel of pk, as the choose loop marks it.
  def land_on(pk)
    PokemonPartyPanel.new(pk).selected = true
  end

  # A help window, shown or not, standing at y.
  def help_window(visible, y)
    Struct.new(:visible, :y).new(visible, y)
  end

  # A help line set on a party screen whose help window is win; the speech starts empty.
  def help_on(win)
    scene = party_scene
    sprites(scene)["helpwindow"] = win
    SpeakCapture.clear
    scene.pbSetHelpText("Escoge un Pokemon.")
  end

  # Opens a party screen that writes its Box Link key line; the speech starts empty.
  def open_with_box_link
    scene = party_scene
    sprites(scene)["storagetext"] = Struct.new(:text).new("[D]: Cajas del PC")
    SpeakCapture.clear
    scene.pbStartScene
  end

  # Runs the block as on a game whose classic party scene reports the cursor itself (Awakening).
  def with_scene_reports
    ui = PokeAccess::UIV21
    was = ui.instance_variable_get(:@scene_reports)
    ui.instance_variable_set(:@scene_reports, true)
    yield
  ensure
    ui.instance_variable_set(:@scene_reports, was)
  end
end
