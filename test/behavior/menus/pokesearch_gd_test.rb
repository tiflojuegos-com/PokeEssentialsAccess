# Voltseon's PokeSearch (plugins/pokesearch.rb): the panel's title and focused place as it opens, each place as the
# cursor moves (an item slot with the item in it and the text painted under it, the Pokemon slot with the species
# chosen, the two buttons), and the slot again back from the bag or the species list.

# The panel, down to what the reader hooks: drawPresent and the three slot choosers change what the real ones change.
# The harness loaded the plugin before this class existed, so its hooks are evaluated again over this one.
class PokeSearch_Scene
  Window = Struct.new(:text)
  attr_accessor :choice

  def initialize
    @index_hor = 1
    @index_ver = 0
    @sprites = { "berry_text" => Window.new("Add a berry to this slot in order to gain a secondary effect."),
                 "repel_text" => Window.new("Add a repel to this slot in order to increase the encounter odds.") }
  end

  def pbStartScene; :started; end
  def drawPresent; :drawn; end

  def selectBerry
    return :cancelled unless @choice
    @current_berry = @choice
    @sprites["berry_text"].text = "Oran Berries slightly increase the IVs of encounters."
    :chosen
  end

  def selectMon
    @current_mon = @choice
    :chosen
  end

  def selectRepel; :cancelled; end
end
search_path = File.join(Harness::ROOT, "plugins", "pokesearch.rb")
search_source = Harness.source(search_path)
search_source.scan(/^(?:PokeAccess::Hooks\.after_hook\("PokeSearch_Scene"|\[:selectBerry).*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, search_path, search_source[0, hook.begin(0)].count("\n") + 1)
end

class PokeSearchGdTest < PokeAccessTest
  test "the panel opens with its title and the place the cursor starts on, queued" do
    PokeSearch_Scene.new.pbStartScene
    assert_equal [[t(:psrch_title), false], ["#{t(:psrch_pokemon)}: #{t(:psrch_empty)}", false]], SpeakCapture.log
  end

  test "each place is said as the cursor reaches it: an item slot with the text under it, then the buttons" do
    scene = opened
    [[0, 0], [0, 1], [1, 1], [1, 1]].each do |hor, ver|
      scene.instance_variable_set(:@index_hor, hor)
      scene.instance_variable_set(:@index_ver, ver)
      scene.drawPresent
    end
    berry = PokeAccess.sentences(["#{t(:psrch_berry)}: #{t(:psrch_empty)}",
                                  "Add a berry to this slot in order to gain a secondary effect."])
    assert_equal [[berry, true], [t(:psrch_search), true], [t(:psrch_cancel), true]], SpeakCapture.log
  end

  test "back from the bag or the species list, the slot is said again with what it now holds, or as it was" do
    scene = opened
    scene.instance_variable_set(:@index_hor, 0)
    scene.drawPresent
    SpeakCapture.clear
    scene.selectBerry
    scene.choice = :ORANBERRY
    scene.selectBerry
    scene.instance_variable_set(:@index_hor, 1)
    scene.choice = :PIKACHU
    scene.selectMon
    empty = PokeAccess.sentences(["#{t(:psrch_berry)}: #{t(:psrch_empty)}",
                                  "Add a berry to this slot in order to gain a secondary effect."])
    oran = PokeAccess.sentences(["#{t(:psrch_berry)}: ItemORANBERRY",
                                 "Oran Berries slightly increase the IVs of encounters."])
    assert_equal [[empty, true], [oran, true], ["#{t(:psrch_pokemon)}: SpeciesPIKACHU", true]], SpeakCapture.log
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A panel that has opened, its opening said and cleared.
  def opened
    scene = PokeSearch_Scene.new
    scene.pbStartScene
    SpeakCapture.clear
    scene
  end
end
