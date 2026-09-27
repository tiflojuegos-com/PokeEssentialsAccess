# Infinite Fusion's option screens: the box's help follows the value focused from the first change, a submenu says
# its title and its line as it opens, and a number option reads "Type N/M" as it is painted. The base scene's
# updateDescription (per value where an option has one description each) and the fusion's ability and nature
# submenu, reduced to what they leave, are defined before the profile file binds to them.
class PokemonOption_Scene
  def updateDescription(value)
    @sprites["textbox"].text = @descriptions[value]
  end
end

class FusionSelectOptionsScene < PokemonOption_Scene
  attr_reader :sprites
  def initialize(descriptions)
    @descriptions = descriptions
    @sprites = {}
  end
  def pbStartScene(_inloadscreen = false)
    @sprites["title"] = FakeTextWin.new("Select your Pokémon's ability and nature")
    @sprites["textbox"] = FakeTextWin.new("")
    nil
  end
end

# An IF number option, which keeps its value as an offset from optstart as the game's does.
class IFSpecNumberOption < NumberOption
  attr_reader :optstart, :optend
  def initialize(name, optstart, optend)
    super(name, optstart, optend)
    @optstart = optstart
    @optend = optend
  end
end

Suite.define("infinite fusion: option help per value, submenu titles, and number options as painted") do
  opts = PokeAccess::Options
  meta = (class << opts; self; end)
  meta.send(:alias_method, :if_spec_value_of, :value_of)
  begin
    load File.expand_path("../../../games/infinitefusion_common/option_screens.rb", File.dirname(__FILE__))
    scene = FusionSelectOptionsScene.new(["Boosts Grass moves.", "Powers up sunny days."])
    SpeakCapture.clear
    scene.pbStartScene
    eq "the fusion's screen opens saying its title (its box still empty)", SpeakCapture.lines,
       ["Select your Pokémon's ability and nature"]

    PokeAccess::Info.set_info(nil, nil)
    scene.updateDescription(1)
    eq "the first change on the same row already puts that value's help on the info key",
       PokeAccess::Info.info_text, "Powers up sunny days."
    scene.updateDescription(0)
    eq "and each change after it, on the same row", PokeAccess::Info.info_text, "Boosts Grass moves."

    frame = IFSpecNumberOption.new("Speech Frame", 1, 4)
    eq "a number option reads as drawItem paints it", opts.value_of(frame, 0), "Type 1/4"
    eq "its offset counted from optstart", opts.row(frame, 2), "Speech Frame: Type 3/4"
    eq "an option of another kind keeps the core's reading", opts.value_of(EnumOption.new("Mode", ["Hold", "Toggle"]), 1),
       "Toggle"
  ensure
    meta.send(:alias_method, :value_of, :if_spec_value_of)
    meta.send(:remove_method, :if_spec_value_of)
  end
end
