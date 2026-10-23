# Africanvs's picture-only screens (games/africanus/pictures.rb) as Game_Picture#show and #erase drive them: the
# character choice's portraits, the arm wrestling's keys and marker, the information bar, the credits and the Union
# of Amat's map. The profile file is evaluated once over the engine stubs, as the loader does.
path = File.join(Harness::ROOT, "games", "africanus", "pictures.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class AfricanusPicturesTest < PokeAccessTest
  # What the English run's place tables answer: the quarry renamed, Iol left blank and Utica's description; nil (the
  # name as townmap.txt has it) for every other place.
  PLACE_ANSWERS = { [:names, "Cantera de Slowpokes"] => "Slowpokes Quarry", [:names, "Iol"] => "",
                    [:descriptions, "Útica"] => "Utica" }

  test "says which portrait the character choice lights, by the names its question gives them, once each" do
    PokeAccess::PictureCues.reset_last
    %w[Protas Protas1 Protas1 Protas2].each { |name| show(name) }
    assert_equal [[t(:afr_vir), true], [t(:afr_femina), true]], SpeakCapture.log
  ensure
    PokeAccess::PictureCues.reset_last
  end

  test "says each arm wrestling key as its picture paints it, cutting in" do
    %w[Tecla1 Tecla2 Tecla3 Tecla4 Tecla5].each { |name| show(name) }
    assert_equal [["Z", true], ["S", true], ["A", true], ["Q", true], ["C", true]], SpeakCapture.log
  end

  test "says a key once while the wrestling's event shows it again" do
    3.times { show("Tecla1") }
    assert_equal ["Z"], SpeakCapture.lines
  end

  test "says a key the player moved by the key it is bound to now" do
    PokeAccess::Config.rebinds = { :y => 0x4B }
    show("Tecla2")
    assert_equal ["K"], SpeakCapture.lines
  end

  test "says the same key again once the wrestling erases it" do
    show("Tecla2")
    Game_Picture.new(5).erase
    show("Tecla2")
    assert_equal %w[S S], SpeakCapture.lines
  end

  test "says nothing for a picture it has no line for, and the one before stays said" do
    %w[Tecla1 Fondo Tecla1].each { |name| show(name) }
    assert_equal ["Z"], SpeakCapture.lines
  end

  test "sounds the wrestling's marker empty at the losing line and full at the win" do
    ticks = wrestling do |marker|
      marker.call(70)
      marker.call(425)
    end
    assert_equal [0.0, 1.0], ticks
  end

  test "ticks again only once the marker has moved a twentieth of the span, toward the win or the loss" do
    counts = []
    wrestling do |marker|
      [70, 87, 88, 71, 70].each { |v| counts.push(marker.call(v).length) }
    end
    assert_equal [1, 1, 2, 2, 3], counts, "ticks after the marker sits at 70, 87, 88, 71 and 70"
  end

  test "ticks nothing while the wrestling's switch is off" do
    ticks = wrestling(59, false) { |marker| marker.call(232) }
    assert_equal [], ticks
  end

  test "ticks nothing for the wrestling's switch on another map" do
    ticks = wrestling(58) { |marker| marker.call(232) }
    assert_equal [], ticks
  end

  test "ticks a wrestling started anew from where its marker sits" do
    ticks = wrestling do |marker|
      marker.call(232)
      $game_switches[289] = false
      PokeAccess::AfricanusPictures.pulse_poll
      $game_switches[289] = true
      marker.call(232)
    end
    assert_equal 2, ticks.length
  end

  test "says the information bar's label and its third, queued, once while its event shows it again" do
    3.times { show("informacion 1") }
    assert_equal [[t(:afr_info_bar, :label => "Información", :n => 1, :total => 3), false]], SpeakCapture.log
  end

  test "says the information bar again as it fills" do
    show("informacion 1")
    show("informacion 2")
    assert_equal [t(:afr_info_bar, :label => "Información", :n => 1, :total => 3),
                  t(:afr_info_bar, :label => "Información", :n => 2, :total => 3)], SpeakCapture.lines
  end

  test "says the information bar it shows again on a map entered anew" do
    show("informacion 2")
    PokeAccess::Caches.reset_all
    show("informacion 2")
    assert_equal [t(:afr_info_bar, :label => "Información", :n => 2, :total => 3)] * 2, SpeakCapture.lines
  end

  test "says each credits picture's names, queued" do
    show("Creditos3")
    show("CREDITOSFIN_eng")
    assert_equal [["Aveontrainer, Cero1533, ChaoticCherryCake, Ditto209", false], ["Game by El Camid", false]],
                 SpeakCapture.log
  end

  test "says the seven places the Union's map marks, by the game's place tables, queued" do
    with_place_tables(PLACE_ANSWERS) { show("mapa con cultistas") }
    assert_equal [[t(:afr_cult_map, :places => "Slowpokes Quarry, Iol, Tarraco, Pisae, Carales, Etna, Utica"), false]],
                 SpeakCapture.log
  end

  test "says the place each cross strikes out, queued" do
    with_place_tables(PLACE_ANSWERS) do
      show("Cruz1")
      show("Cruz7")
    end
    assert_equal [[t(:afr_cult_cross, :place => "Slowpokes Quarry"), false],
                  [t(:afr_cult_cross, :place => "Utica"), false]], SpeakCapture.log
  end

  test "names a point of interest as townmap.txt spells it where the game has no descriptions table" do
    without_descriptions_table { show("Cruz7") }
    assert_equal [t(:afr_cult_cross, :place => "Útica")], SpeakCapture.lines
  end

  private

  # The mod's line for key in the running language.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Shows a picture as an event does.
  def show(name)
    Game_Picture.new(5).show(name)
  end

  # Runs the block on the given map with the wrestling's switch as given, the gauge recorded; the block gets a lambda
  # that puts the marker at a value and polls a frame, answering the ticks so far. Answers every tick, and stops the
  # wrestling after.
  def wrestling(map = 59, on = true)
    ticks = []
    meta = PokeAccess::Sound.singleton_class
    meta.send(:alias_method, :gauge_unheard, :gauge)
    meta.send(:define_method, :gauge) { |fraction| ticks.push(fraction) }
    PokeAccess::AfricanusPictures.pulse_poll
    $game_map.map_id = map
    $game_switches[289] = on
    yield(lambda do |v|
      $game_variables[92] = v
      PokeAccess::AfricanusPictures.pulse_poll
      ticks
    end)
    ticks
  ensure
    meta.send(:alias_method, :gauge, :gauge_unheard)
    meta.send(:remove_method, :gauge_unheard)
    $game_switches[289] = false
    PokeAccess::AfricanusPictures.pulse_poll
  end

  # Runs the block with the game's PlaceNames and PlaceDescriptions tables answering answers, keyed by :names or
  # :descriptions and the raw name.
  def with_place_tables(answers)
    made = !MessageTypes.const_defined?(:PlaceDescriptions)
    MessageTypes.const_set(:PlaceDescriptions, 20) if made
    tables = { MessageTypes::PlaceNames => :names, MessageTypes::PlaceDescriptions => :descriptions }
    Object.send(:alias_method, :pa_place_tables, :pbGetMessageFromHash)
    Object.send(:define_method, :pbGetMessageFromHash) { |type, id| answers[[tables[type], id]] }
    yield
  ensure
    Object.send(:alias_method, :pbGetMessageFromHash, :pa_place_tables)
    Object.send(:remove_method, :pa_place_tables)
    MessageTypes.send(:remove_const, :PlaceDescriptions) if made
  end

  # Runs the block with MessageTypes lacking PlaceDescriptions, as the gen-6 engine's does.
  def without_descriptions_table
    was = MessageTypes.const_defined?(:PlaceDescriptions) ? MessageTypes::PlaceDescriptions : nil
    MessageTypes.send(:remove_const, :PlaceDescriptions) if was
    yield
  ensure
    MessageTypes.const_set(:PlaceDescriptions, was) if was
  end
end
