# Reminiscencia's own minigames (games/reminiscencia: hoopa.rb, pokocho.rb, logros.rb, amie.rb) over stand-ins defined
# before its files load: the Hoopa gacha's balance and shiny prize, the Pokocho maker's cues and results, the
# achievements' EV limits, Poke Recreo's opening and feeding; and the party's 1-key lead swap (party_keys.rb), whose
# module alone is evaluated, since its hooks would reach the party scene other tests share.
def pbAddPokemonRNG(pokemon, _level = nil, _seeform = true)
  PokeAccess.say_dialogue("¡Anthony ha obtenido un #{pokemon.name}!")
  true
end

class HoopaGacha
  attr_accessor :prize
  def drawMaintext; pbDrawTextPositions(nil, [["Monedas: 5", 600, 48, 1]]); :painted; end
  def startRoulette; pbAddPokemonRNG(@prize); end
end

class Poffin
  # The results table showResult paints until confirmed (text, x, y, align), the Pokocho's name last.
  RESULTS = [["RESULTADOS", 280, 90, 0], ["Tiempo", 200, 130, 0], ["60", 420, 130, 0], ["Derramado", 200, 160, 0],
             ["2 veces", 400, 160, 0], ["Quemado", 200, 190, 0], ["0 veces", 400, 190, 0], ["", 200, 250, 0],
             ["Nombre: ", 200, 330, 0]]

  def announceStart; :start; end
  def announceFinish; :done; end

  def drawTextAnnouncement(type = 0, _size = 60)
    pbDrawTextPositions(nil, [[type == 0 ? "¡Se quema! ¡Remuévelo!" : "¡Muy rápido! ¡Se desborda!", 320, 240, 2]])
  end

  def showResult(_result, _level, name)
    pbDrawTextPositions(nil, RESULTS + [[name, 290, 330, 0]])
    false
  end
end

class Logros_Scene
  def showTexts(_index)
    pbDrawTextPositions(nil, [["Primeros pasos", 90, 360, 0]])
    drawTextEx(nil, 0, 0, 400, 2, "Captura tu primer Pokémon.", nil, nil)
    drawTextEx(nil, 0, 0, 200, 4, "Máx EV total: 512\nMáx EV/stat: 252", nil, nil)
    :shown
  end
end

# Poke Recreo as the game builds it: the character kept under its picture folder's name, the berry as an item id,
# and main_loop entered last from the constructor; the eating sound's last play at the game's starting 0, input reduced
# to a count of the frames it ran, and checkEating as the game's at its end (NO_FOOD_TIME, 300), where the game says the
# friendship grew.
class PokemonAmie
  attr_reader :mouse_frames
  def initialize(chara = "Lucius", berry = 0)
    @charaName = chara
    @charaName = "PAthan" if @charaName == "Athan"
    @charaName = "Artica" if @charaName == "Ártica"
    @foodName = berry
    @sprites = { "mouth" => Struct.new(:visible).new(false) }
    @eatingTimeCheck = 0
    @eatTime = 0
    @finishedFood = false
    @mouse_frames = 0
    main_loop
  end

  def main_loop; :closed; end
  def input; @mouse_frames += 1; end

  def checkEating
    return unless @eatingTimeCheck == 300
    @finishedFood = true
    @foodmode = false
    @eatingTimeCheck = 0
    PokeAccess.say_dialogue("¡La relación con #{@charaName} mejoró!")
  end
end

%w[hoopa pokocho logros amie].each do |f|
  path = File.join(Harness::ROOT, "games", "reminiscencia", "#{f}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end
party_keys_path = File.join(Harness::ROOT, "games", "reminiscencia", "party_keys.rb")
party_keys = Harness.source(party_keys_path)
party_lead = party_keys.match(/^module PokeAccess\r?\n.*?^end\r?\n/m)
eval(party_lead[0], TOPLEVEL_BINDING, party_keys_path, party_keys[0, party_lead.begin(0)].count("\n") + 1)

class ReminMinigamesTest < PokeAccessTest
  EV_LIMITS = "Máx EV total: 512. Máx EV/stat: 252"
  RESULTS_LINE = "RESULTADOS. Tiempo 60. Derramado 2 veces. Quemado 0 veces. Nombre: Pokocho dulce"

  test "the gacha's balance is said queued as it is painted" do
    assert_equal :painted, HoopaGacha.new.drawMaintext, "the gacha paints as the game's"
    assert_equal [["Monedas: 5", false]], SpeakCapture.log
  end

  test "a shiny gacha prize is said after the line that names it" do
    spin(Poke.build(:name => "Rayquaza", :shiny => true))
    assert_equal [["¡Anthony ha obtenido un Rayquaza!", false], [PokeAccess::I18n.t(:pk_shiny), false]], SpeakCapture.log
  end

  test "a plain gacha prize is the line alone" do
    spin(Poke.build(:name => "Lugia"))
    assert_equal ["¡Anthony ha obtenido un Lugia!"], SpeakCapture.lines
  end

  test "a shiny prize with no room left in the boxes is the line alone" do
    GameFunctions.with(:pbBoxesFull? => lambda { true }) { spin(Poke.build(:name => "Mew", :shiny => true)) }
    assert_equal ["¡Anthony ha obtenido un Mew!"], SpeakCapture.lines
  end

  test "a shiny Pokemon given outside the roulette adds nothing to its line" do
    pbAddPokemonRNG(Poke.build(:name => "Celebi", :shiny => true))
    spin(Poke.build(:name => "Jirachi"))
    assert_equal ["¡Anthony ha obtenido un Celebi!", "¡Anthony ha obtenido un Jirachi!"], SpeakCapture.lines
  end

  test "the Pokocho maker says its start, each warning as painted and its end, each cutting in" do
    t = PokeAccess::I18n
    maker = Poffin.new
    assert_equal :start, maker.announceStart, "the maker's own start runs"
    maker.drawTextAnnouncement(0)
    maker.drawTextAnnouncement(1)
    assert_equal :done, maker.announceFinish, "and its own end"
    assert_equal [[t.t(:rem_pokocho_start), true], ["¡Se quema! ¡Remuévelo!", true], ["¡Muy rápido! ¡Se desborda!", true],
                  [t.t(:rem_pokocho_done), true]], SpeakCapture.log
  end

  test "the Pokocho results are said row by row, queued, once while the table is repainted" do
    maker = Poffin.new
    3.times { assert_equal false, maker.showResult(nil, 1, "Pokocho dulce"), "showResult's own answer" }
    assert_equal [[RESULTS_LINE, false]], SpeakCapture.log
  end

  test "a Pokocho results table that changes is said again" do
    maker = Poffin.new
    maker.showResult(nil, 1, "Pokocho dulce")
    maker.showResult(nil, 1, "Pokocho amargo")
    assert_equal [RESULTS_LINE, RESULTS_LINE.sub("dulce", "amargo")], SpeakCapture.lines
  end

  test "the achievements' EV limits are said after the first achievement, one after the other, queued" do
    assert_equal :shown, Logros_Scene.new.showTexts(0), "the screen paints as the game's"
    assert_nothing_spoken "held until the frame's achievement reader has spoken"
    PokeAccess::ReminLogros.flush
    assert_equal [[EV_LIMITS, false]], SpeakCapture.log
  end

  test "the achievements' EV limits are said once per visit" do
    scene = Logros_Scene.new
    scene.showTexts(0)
    PokeAccess::ReminLogros.flush
    scene.showTexts(1)
    2.times { PokeAccess::ReminLogros.flush }
    Logros_Scene.new.showTexts(0)
    PokeAccess::ReminLogros.flush
    assert_equal [EV_LIMITS, EV_LIMITS], SpeakCapture.lines
  end

  test "the 1 key's lead swap names the new lead, then the member left under the cursor, queued" do
    party = [Poke.build(:name => "Anthony1"), Poke.build(:name => "Bulbi"), Poke.build(:name => "Chispa")]
    scene = World.stub_scene(:@party => party, :@activecmd => 2)
    PokeAccess::ReminPartyLead.start(scene)
    party[0], party[2] = party[2], party[0]
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_equal [[PokeAccess::I18n.t(:rem_party_lead, :name => "Chispa"), true],
                  [PokeAccess::Party.member_text(scene, party, 2), false]], SpeakCapture.log
    assert_match(/\AAnthony1\b/, SpeakCapture.lines.last, "the old lead, now under the cursor")
  end

  test "a swap is said on the refresh that shows it, and not on the refreshes around it" do
    party = [Poke.build(:name => "Anthony1"), Poke.build(:name => "Chispa")]
    scene = World.stub_scene(:@party => party, :@activecmd => 1)
    PokeAccess::ReminPartyLead.start(scene)
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_nothing_spoken "a refresh with the same lead"
    party.reverse!
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_equal [[PokeAccess::I18n.t(:rem_party_lead, :name => "Chispa"), true],
                  [PokeAccess::Party.member_text(scene, party, 1), false]], SpeakCapture.log, "the refresh that shows it"
    SpeakCapture.clear
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_nothing_spoken "the refresh after it"
  end

  test "a lead first seen on a refresh, or a party not there, is not announced" do
    party = [Poke.build(:name => "Anthony1"), Poke.build(:name => "Chispa")]
    scene = World.stub_scene(:@party => nil, :@activecmd => 1)
    PokeAccess::ReminPartyLead.start(scene)
    PokeAccess::ReminPartyLead.refreshed(scene)
    scene.instance_variable_set(:@party, party)
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_nothing_spoken
  end

  test "a refresh while the lead's slot is empty keeps the lead it knew" do
    anthony = Poke.build(:name => "Anthony1")
    chispa = Poke.build(:name => "Chispa")
    scene = World.stub_scene(:@party => [anthony, chispa], :@activecmd => 1)
    PokeAccess::ReminPartyLead.start(scene)
    scene.instance_variable_set(:@party, [nil, anthony])
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_nothing_spoken "the empty slot"
    scene.instance_variable_set(:@party, [chispa, anthony])
    PokeAccess::ReminPartyLead.refreshed(scene)
    assert_equal PokeAccess::I18n.t(:rem_party_lead, :name => "Chispa"), SpeakCapture.lines.first, "the new lead, against the old"
  end

  test "Poke Recreo says who and which berry, that it wants the mouse, and the keys that leave, cutting in" do
    berry = PokeAccess::Data.item_name(50)
    PokemonAmie.new("Athan", 50)
    assert_equal [[PokeAccess::I18n.t(:rem_amie_open, :who => "Athan, #{berry}", :c => "C", :b => "X"), true]],
                 SpeakCapture.log
  end

  test "Poke Recreo names a character kept under its picture folder's name by its own" do
    berry = PokeAccess::Data.item_name(50)
    %w[Athan Ártica Lucius].each do |who|
      SpeakCapture.clear
      PokemonAmie.new(who, 50)
      assert_equal [PokeAccess::I18n.t(:rem_amie_open, :who => "#{who}, #{berry}", :c => "C", :b => "X")],
                   SpeakCapture.lines, who
    end
  end

  test "Poke Recreo leaves out a berry with no name" do
    with_item_names(nil) { PokemonAmie.new("Lucius", 50) }
    with_item_names(" ") { PokemonAmie.new("Lucius", 50) }
    open = PokeAccess::I18n.t(:rem_amie_open, :who => "Lucius", :c => "C", :b => "X")
    assert_equal [open, open], SpeakCapture.lines
  end

  test "Poke Recreo says a moved cancel key where it is" do
    PokeAccess::Config.rebinds = { :b => 0x51 }
    PokemonAmie.new("Lucius", 50)
    berry = PokeAccess::Data.item_name(50)
    assert_equal [PokeAccess::I18n.t(:rem_amie_open, :who => "Lucius, #{berry}", :c => "C", :b => "Q")], SpeakCapture.lines
  end

  test "Poke Recreo runs the game's own input on a frame without Down" do
    scene = PokemonAmie.new("Lucius", 50)
    assert_equal 1, scene.input, "the game's input ran"
    assert_equal 0, scene.instance_variable_get(:@eatingTimeCheck), "and nothing was fed"
  end

  test "holding Down feeds the berry on the mouth instead of the game's input" do
    scene = PokemonAmie.new("Lucius", 50)
    holding_down do
      assert_nil scene.input, "the frame fed"
      assert_equal [true, true, 1, 0],
                   [PokeAccess.sprite(scene, "mouth").visible, scene.instance_variable_get(:@foodmode),
                    scene.instance_variable_get(:@eatingTimeCheck), scene.mouse_frames],
                   "the mouth open, the berry on it, one bite counted, the game's input not run"
    end
  end

  test "feeding says the berry half and nearly eaten at the game's counts, then its own message at the end" do
    t = PokeAccess::I18n
    scene = PokemonAmie.new("Lucius", 50)
    SpeakCapture.clear
    holding_down do
      99.times { scene.input }
      assert_nothing_spoken "before half"
      scene.input
      assert_equal [[t.t(:rem_amie_half), false]], SpeakCapture.log, "at 100"
      99.times { scene.input }
      assert_equal 1, SpeakCapture.log.length, "nothing more before 200"
      scene.input
      assert_equal [t.t(:rem_amie_nearly), false], SpeakCapture.log.last, "at 200"
      100.times { scene.input }
      assert_equal [t.t(:rem_amie_half), t.t(:rem_amie_nearly), "¡La relación con Lucius mejoró!"], SpeakCapture.lines
    end
  end

  test "feeding follows the game's own eating times where it has them" do
    t = PokeAccess::I18n
    scene = PokemonAmie.new("Lucius", 50)
    SpeakCapture.clear
    with_eating_times(30, 60) { holding_down { 60.times { scene.input } } }
    assert_equal [t.t(:rem_amie_half), t.t(:rem_amie_nearly)], SpeakCapture.lines
  end

  test "once the berry is eaten Down leaves the frame to the game" do
    scene = PokemonAmie.new("Rina", 50)
    holding_down do
      300.times { scene.input }
      scene.input
    end
    assert_equal 1, scene.mouse_frames
  end

  test "the eating sound plays at the game's pace, not again within four times its length" do
    with_sound_length(10.0) do
      { nil => ["NEWEat.ogg"], 0 => [], 30 => [], 45 => ["NEWEat.ogg"], 1000 => ["NEWEat.ogg"] }.each do |ago, played|
        scene = PokemonAmie.new("Lucius", 50)
        scene.instance_variable_set(:@eatTime, Time.now - ago) if ago
        holding_down do
          scene.input
          assert_equal played, $se_played, ago ? "last played #{ago} s ago" : "never played, the game's 0"
        end
      end
    end
  end

  private

  # Spins the gacha onto prize, as the roulette hands it over.
  def spin(prize)
    gacha = HoopaGacha.new
    gacha.prize = prize
    gacha.startRoulette
  end

  # Runs the block with Down held, as Input.press? reports it, and the sounds it plays kept apart in $se_played;
  # the stub's press? and the sounds played before are put back after.
  def holding_down
    saved = [Input.method(:press?), $se_played]
    $se_played = []
    Input.define_singleton_method(:press?) { |*b| b[0] == Input::DOWN }
    yield
  ensure
    Input.define_singleton_method(:press?, saved[0])
    $se_played = saved[1]
  end

  # Runs the block with every item name answering name, the real lookup put back after.
  def with_item_names(name)
    real = PokeAccess::Data.method(:item_name)
    PokeAccess::Data.define_singleton_method(:item_name) { |*_a| name }
    yield
  ensure
    PokeAccess::Data.define_singleton_method(:item_name, real)
  end

  # Runs the block with the game's own berry counts (HALF_EATEN_TIME, FULL_EATEN_TIME), taken away after.
  def with_eating_times(half, full)
    Object.const_set(:HALF_EATEN_TIME, half)
    Object.const_set(:FULL_EATEN_TIME, full)
    yield
  ensure
    Object.send(:remove_const, :HALF_EATEN_TIME)
    Object.send(:remove_const, :FULL_EATEN_TIME)
  end

  # Runs the block with the eating sound seconds long, as the game's getPlayTime measures it.
  def with_sound_length(seconds)
    GameFunctions.with(:getPlayTime => lambda { |_path| seconds }) { yield }
  end
end
