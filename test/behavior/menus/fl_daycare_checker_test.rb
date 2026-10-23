# FL's Day-Care Checker Item (plugins/fl_daycare_checker.rb) over a stand-in of its scene, painting as the script does: a
# slot's name and level text at the left or right edge, the sex sign after it, the egg a sprite with no text. The screen is
# said once as it opens, in screen order, and kept on the info key until the scene ends.
module DayCareChecker
  class Scene
    def initialize(slots = [nil, nil], egg = false)
      @slots = slots
      @egg = egg
    end

    def start_scene
      @sprites = {}
      rows = []
      @slots.each_with_index do |slot, i|
        next unless slot
        text, sign = slot
        rows.push([text, i == 0 ? 20 : 512 - 20 - (sign ? 20 : 0), 50, i == 1])
        rows.push([sign, i == 0 ? 20 + text.length * 8 + 8 : 512 - 20, 50, i == 1]) if sign
      end
      pbDrawTextPositions(nil, rows) unless rows.empty?
      @sprites["egg"] = Object.new if @egg
      :started
    end

    def end_scene
      :ended
    end
  end
end
daycare_path = File.join(Harness::ROOT, "plugins", "fl_daycare_checker.rb")
eval(Harness.source(daycare_path), TOPLEVEL_BINDING, daycare_path)

class FlDaycareCheckerTest < PokeAccessTest
  STRINGS = { "dcheck_egg" => "Hay un Huevo", "dcheck_empty" => "Sin Pokémon en la Guardería" }
  MALE = PokeAccess::Party::SIGNS[0]
  FEMALE = PokeAccess::Party::SIGNS[1]

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @saved = STRINGS.keys.map { |k| [k, table[k]] }
    STRINGS.each { |k, v| table[k] = v }
  end

  def teardown
    table = PokeAccess::I18n.table(:es)
    (@saved || []).each { |k, v| v.nil? ? table.delete(k) : table[k] = v }
    super
  end

  test "says each Pokemon as painted, name and level then sex sign, left to right, queued" do
    open_screen([["Pikachu Lv5", MALE], ["Eevee Lv3", FEMALE]])
    assert_equal [["Pikachu Lv5 #{MALE}. Eevee Lv3 #{FEMALE}", false]], SpeakCapture.log
  end

  test "says a genderless Pokemon's name and level alone" do
    open_screen([["Magnemite Lv10"], ["Ditto Lv2"]])
    assert_equal ["Magnemite Lv10. Ditto Lv2"], SpeakCapture.lines
  end

  test "says a single Pokemon at the right edge as the screen shows it" do
    open_screen([nil, ["Eevee Lv3", FEMALE]])
    assert_equal ["Eevee Lv3 #{FEMALE}"], SpeakCapture.lines
  end

  test "says the egg after the Pokemon" do
    open_screen([["Pikachu Lv5", MALE], ["Eevee Lv3", FEMALE]], true)
    assert_equal ["Pikachu Lv5 #{MALE}. Eevee Lv3 #{FEMALE}. Hay un Huevo"], SpeakCapture.lines
  end

  test "says the egg alone for a Day-Care that holds none but an egg" do
    open_screen([nil, nil], true)
    assert_equal ["Hay un Huevo"], SpeakCapture.lines
  end

  test "says the Day-Care holds nothing when the screen paints no Pokemon and no egg" do
    open_screen([nil, nil])
    assert_equal [["Sin Pokémon en la Guardería", false]], SpeakCapture.log
  end

  test "keeps a sex sign painted with no name before it as an entry of its own" do
    open_screen([[MALE]])
    assert_equal [MALE], SpeakCapture.lines
  end

  test "keeps the screen on the info key until the scene ends" do
    scene = DayCareChecker::Scene.new([["Pikachu Lv5", MALE], nil], true)
    scene.start_scene
    assert_equal "Pikachu Lv5 #{MALE}. Hay un Huevo", PokeAccess::Info.info_text
    scene.end_scene
    assert_nil PokeAccess::Info.info_text
  end

  test "hands back what the scene's own methods answer" do
    scene = DayCareChecker::Scene.new([["Pikachu Lv5", MALE], nil])
    assert_equal [:started, :ended], [scene.start_scene, scene.end_scene]
  end

  test "says the screen once for each time the scene opens" do
    open_screen([["Pikachu Lv5", MALE], nil])
    open_screen([["Pikachu Lv5", MALE], nil])
    assert_equal ["Pikachu Lv5 #{MALE}"] * 2, SpeakCapture.lines
  end

  private

  # Opens the screen over the slots, each a [text, sex sign] pair or nil for an empty one.
  def open_screen(slots, egg = false)
    DayCareChecker::Scene.new(slots, egg).start_scene
  end
end
