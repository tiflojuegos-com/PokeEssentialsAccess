# Infinite Fusion's option screens (games/infinitefusion_common/option_screens.rb): the box's help follows the value
# focused, a submenu says its title and its box's line as it opens, and a number option reads "Type N/M" as painted.

# The options scene's updateDescription, reduced to the help it leaves in the box for the value focused.
class PokemonOption_Scene
  def updateDescription(value)
    @sprites["textbox"].text = @descriptions[value]
  end
end

# The fusion's ability and nature submenu, opening as the game's options scene does: its title, its box holding
# opening (no box for nil) and its options window, each row painted.
class FusionSelectOptionsScene < PokemonOption_Scene
  TITLE = "Select your Pokémon's ability and nature"
  attr_reader :sprites

  def initialize(descriptions, title = TITLE, opening = "", options = [])
    @descriptions = descriptions
    @title = title
    @opening = opening
    @options = options
    @sprites = {}
  end

  def pbStartScene(_inloadscreen = false)
    @sprites["title"] = FakeTextWin.new(@title)
    @sprites["textbox"] = FakeTextWin.new(@opening) unless @opening.nil?
    @sprites["option"] = Window_PokemonOption.new(@options)
    @sprites["option"].refresh
    nil
  end
end

class IfOptionScreensGdTest < PokeAccessTest
  OPTIONS = PokeAccess::Options.singleton_class
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "option_screens.rb")
  HELP = ["Boosts Grass moves.", "Powers up sunny days."]

  # The game's number option, which keeps its value as an offset from optstart.
  class IFNumberOption < NumberOption
    attr_reader :optstart, :optend
    def initialize(name, optstart, optend)
      super(name, optstart, optend)
      @optstart = optstart
      @optend = optend
    end
  end

  # The game's slider, which has an optstart too but paints its value alone over the bar.
  class IFSliderOption < SliderOption
    attr_reader :optstart, :optend
    def initialize(name, optstart, optend)
      super(name, optstart, optend)
      @optstart = optstart
      @optend = optend
    end
  end

  # Evaluates the profile file once, as boot does, and answers its value_of: its hooks stay bound to the stand-ins
  # above, while the core's value_of is put back for the other tests of the process (with_if_value_of puts it in).
  def self.load_profile
    core = OPTIONS.instance_method(:value_of)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      OPTIONS.instance_method(:value_of)
    ensure
      OPTIONS.send(:define_method, :value_of, core)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  CORE_VALUE_OF = OPTIONS.instance_method(:value_of)
  IF_VALUE_OF = load_profile

  test "a submenu opens saying its title, queued, while its box is still empty" do
    FusionSelectOptionsScene.new(HELP).pbStartScene
    assert_equal [[FusionSelectOptionsScene::TITLE, false]], SpeakCapture.log
  end

  test "a submenu whose box already holds a line says the title, then that line" do
    FusionSelectOptionsScene.new(HELP, FusionSelectOptionsScene::TITLE, "Pick the nature first.").pbStartScene
    assert_equal [["Select your Pokémon's ability and nature. Pick the nature first.", false]], SpeakCapture.log
  end

  test "a submenu with no box says its title alone" do
    FusionSelectOptionsScene.new(HELP, "Autosave", nil).pbStartScene
    assert_equal [["Autosave", false]], SpeakCapture.log
  end

  test "a submenu opening with a blank title and box says nothing" do
    FusionSelectOptionsScene.new(HELP, " ", "").pbStartScene
    assert_nothing_spoken
  end

  test "a submenu's number rows keep what they paint as it opens" do
    frame = NumberOption.new("Speech Frame", 1, 4)
    scene = FusionSelectOptionsScene.new(HELP, FusionSelectOptionsScene::TITLE, "", [frame])
    scene.pbStartScene
    assert_equal "Type 1/4", PokeAccess::Options.value_label(scene.sprites["option"], 0)
  end

  test "each change of value puts that value's help on the info key" do
    scene = opened(HELP)
    scene.updateDescription(1)
    assert_equal HELP[1], PokeAccess::Info.info_text, "the first change already gives its value's help"
    scene.updateDescription(0)
    assert_equal HELP[0], PokeAccess::Info.info_text, "and each change after it"
  end

  test "a value with no help leaves the info key as it was" do
    scene = opened(["Boosts Grass moves.", ""])
    scene.updateDescription(0)
    scene.updateDescription(1)
    assert_equal "Boosts Grass moves.", PokeAccess::Info.info_text
  end

  test "the help names a key the player moved as the key used now" do
    scene = opened(["Press C to confirm the nature."])
    with_key_letters("C" => :c) do
      PokeAccess::Config.rebinds = { :c => 0x4B }
      scene.updateDescription(0)
    end
    assert_equal "Press K to confirm the nature.", PokeAccess::Info.info_text
  end

  test "a number option reads its value as drawItem paints it, counted from its optstart" do
    frame = IFNumberOption.new("Speech Frame", 1, 4)
    menu = IFNumberOption.new("Menu Frame", 0, 2)
    with_if_value_of do
      assert_equal "Type 1/4", PokeAccess::Options.value_of(frame, 0), "the first of four"
      assert_equal "Type 1/3", PokeAccess::Options.value_of(menu, 1), "an option counted from zero"
      assert_equal "Speech Frame: Type 3/4", PokeAccess::Options.row(frame, 2), "the row as painted"
    end
  end

  test "an option that is no number option of the game's keeps the core's reading" do
    { "a list of labels" => [EnumOption.new("Mode", %w[Hold Toggle]), 1],
      "a slider, which paints its value alone" => [IFSliderOption.new("Volume", 0, 100), 70],
      "a number option with no optstart" => [NumberOption.new("Speed", 1, 4), 2] }.each do |what, (option, value)|
      core = PokeAccess::Options.value_of(option, value)
      assert_equal core, with_if_value_of { PokeAccess::Options.value_of(option, value) }, what
    end
  end

  private

  # The fusion submenu opened, its box ready for the help of each value in descriptions.
  def opened(descriptions)
    scene = FusionSelectOptionsScene.new(descriptions)
    scene.pbStartScene
    scene
  end

  # Runs the block with the profile's value_of in place of the core's, put back afterwards.
  def with_if_value_of
    OPTIONS.send(:define_method, :value_of, IF_VALUE_OF)
    yield
  ensure
    OPTIONS.send(:define_method, :value_of, CORE_VALUE_OF)
  end

  # Runs the block with letters as the game's key hints (painted letter => button), put back afterwards.
  def with_key_letters(letters)
    was = PokeAccess::Config.key_hint_letters
    PokeAccess::Config.key_hint_letters = letters
    yield
  ensure
    PokeAccess::Config.key_hint_letters = was
  end
end
