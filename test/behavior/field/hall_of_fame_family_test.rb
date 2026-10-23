# The hall of fame's reader on the gen-6 spelling (the modern one and the clones: hall_of_fame_family_gd_test.rb): a
# member panel is read as painted, once per member, queued in the entry and interrupting in the PC viewer, with what
# only its sprite shows; the viewer's record header leads once per record and the member's place follows; the banner
# is the screen's own; the closing trainer box leads the congratulation, read by pages or whole.

# The PC viewer as Sevii's 0155 paints a member: four rows at the bottom, then the record's header at the top, its
# label and number apart; the scene keeps the record's team and the member's place in it.
class SeviiHall_Scene
  def initialize(team, index); @hallEntry = team; @battlerIndex = index; end
  def writePokemonData(pk, hall = -1)
    rows = [["No. 025", 32, 304], ["#{pk.name}/Pikachu", 320, 304], ["Lv. #{pk.level}", 64, 336], ["IDNo.31289", 320, 336]]
    rows += [["Hall of Fame No.", 152, 0], [hall.to_s, 360, 0]] if hall > -1
    pbDrawTextPositions(nil, rows)
    hall
  end
  def pbStartSceneEntry(*a); end
end

class HallOfFameFamilyTest < PokeAccessTest
  # Sevii's viewer bound once for the process, as a profile binds a clone.
  BOUND = PokeAccess::HallOfFame.bind("SeviiHall_Scene")

  # A message window that pages, its message drawn whole.
  class PagedWindow
    def initialize(text); @textchars = text.split(//); @curchar = @textchars.length; end
    def pausing?; false; end
    def busy?; false; end
  end

  test "in the PC viewer the record's header leads, label and number together, and the member's place follows" do
    team = [member("Chispa"), member("Lumbre")]
    SeviiHall_Scene.new(team, 1).writePokemonData(team[1], 3)
    assert_equal [["Hall of Fame No. 3. No. 025, Lumbre/Pikachu, Lv. 50, IDNo.31289, #{place(2, 2)}", true]],
                 SpeakCapture.log
  end

  test "browsing one record says its header once, and another record says its own" do
    team = [member("Chispa"), member("Lumbre")]
    scene = SeviiHall_Scene.new(team, 0)
    scene.writePokemonData(team[0], 3)
    SpeakCapture.clear
    scene.instance_variable_set(:@battlerIndex, 1)
    scene.writePokemonData(team[1], 3)
    assert_equal [["No. 025, Lumbre/Pikachu, Lv. 50, IDNo.31289, #{place(2, 2)}", true]], SpeakCapture.log, "same record"
    SpeakCapture.clear
    older = [member("Nube")]
    scene.instance_variable_set(:@hallEntry, older)
    scene.instance_variable_set(:@battlerIndex, 0)
    scene.writePokemonData(older[0], 2)
    assert_equal [["Hall of Fame No. 2. No. 025, Nube/Pikachu, Lv. 50, IDNo.31289, #{place(1, 1)}", true]],
                 SpeakCapture.log, "an older record"
  end

  test "what only the sprite shows follows the panel: the form's name, the first form's too, and the shiny word" do
    unown = Poke.build(:name => "Unown", :species => 201, :level => 30, :form => 0, :shiny => true)
    names = lambda { |type, id| type == MessageTypes::FormNames && id == 201 ? "Anger,Bear" : "msg#{id}" }
    GameFunctions.with(:pbGetMessage => names) { HallOfFameScene.new.writePokemonData(unown, -1) }
    assert_equal [["No. 025, Unown Nv. 30, IDNo.12345, Anger, #{PokeAccess::I18n.t(:pk_shiny)}", false]], SpeakCapture.log
  end

  test "a form named by marks alone, as Unown's last two are, is said by the mark's name" do
    unown = Poke.build(:name => "Unown", :species => 201, :level => 30, :form => 1)
    names = lambda { |type, id| type == MessageTypes::FormNames && id == 201 ? "?????,!!!!!" : "msg#{id}" }
    GameFunctions.with(:pbGetMessage => names) { HallOfFameScene.new.writePokemonData(unown, -1) }
    assert_equal [["No. 025, Unown Nv. 30, IDNo.12345, #{PokeAccess::I18n.t(:unown_exclaim)}", false]], SpeakCapture.log
  end

  test "with the dialogue read by pages, the trainer box leads the congratulation's page, so the page cannot cut it" do
    PokeAccess::Config.dialogue_pages = true
    win = PagedWindow.new("¡Enhorabuena!")
    PokeAccess::HallOfFame.arm_box
    Window_AdvancedTextPokemon.new("Name<r>Tester<br>IDNo.<r>12345<br>")
    PokeAccess::DialoguePages.open(win, "¡Enhorabuena!", true)
    PokeAccess::DialoguePages.poll
    PokeAccess::DialoguePages.close(win)
    PokeAccess::HallOfFame.disarm_box
    assert_equal [["Name Tester, IDNo. 12345: ¡Enhorabuena!", true]], SpeakCapture.log
  end

  test "a member panel is read as painted, dex number and trainer id included, queued in the entry" do
    HallOfFameScene.new.writePokemonData(Poke.build(:name => "Chispa", :level => 50), -1)
    assert_equal [["No. 025, Chispa Nv. 50, IDNo.12345", false]], SpeakCapture.log
  end

  test "the same member drawn again says nothing" do
    scene = HallOfFameScene.new
    chispa = Poke.build(:name => "Chispa", :level => 50)
    scene.writePokemonData(chispa, -1)
    SpeakCapture.clear
    scene.writePokemonData(chispa, -1)
    assert_nothing_spoken
  end

  test "another member whose panel reads the same is read too" do
    scene = HallOfFameScene.new
    scene.writePokemonData(Poke.build(:name => "Chispa", :level => 50), -1)
    SpeakCapture.clear
    scene.writePokemonData(Poke.build(:name => "Chispa", :level => 50), -1)
    assert_equal [["No. 025, Chispa Nv. 50, IDNo.12345", false]], SpeakCapture.log
  end

  test "in the PC viewer a member panel interrupts, as browsing redraws member by member" do
    HallOfFameScene.new.writePokemonData(Poke.build(:name => "Otro", :level => 12), 3)
    assert_equal [["No. 025, Otro Nv. 12, IDNo.12345", true]], SpeakCapture.log
  end

  test "the banner is the one the screen painted, queued" do
    HallOfFameScene.new.writeWelcome
    assert_equal [["Bienvenido al Salon de la Fama", false]], SpeakCapture.log
  end

  test "the banner painted again on the same screen says nothing" do
    scene = HallOfFameScene.new
    scene.writeWelcome
    SpeakCapture.clear
    scene.writeWelcome
    assert_nothing_spoken
  end

  test "the closing trainer box is read row by row, label and value apart, leading the congratulation" do
    HallOfFameScene.new.writeTrainerData
    assert_equal [["Name Tester, IDNo. 12345, Time 01:23, Pokédex 10/20: ¡Enhorabuena por tu victoria!", false]],
                 SpeakCapture.log
  end

  test "a text window built outside the closing box is left to its own readers" do
    Window_AdvancedTextPokemon.new("Name<r>Otro<br>")
    assert_nothing_spoken
  end

  private

  # A hall member as Sevii's viewer paints it: nickname and level 50, of the usual colours.
  def member(name)
    Poke.build(:name => name, :species => 25, :level => 50)
  end

  # The member's place in its team as the viewer says it.
  def place(n, total)
    PokeAccess::Verbosity.position(n, total)
  end
end
