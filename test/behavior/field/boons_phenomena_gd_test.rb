# Boon's Phenomena (plugins/boons_phenomena.rb): a phenomenon is said once, queued, by its kind and where it lies, as
# the game first draws it, which it does within 27 tiles across plus along; one beyond that is said only once the
# player walks within it, and a kind the plugin does not draw never is. One said that goes away is said gone once, as
# soon as the player is free, unless the player walked onto it or left its map.

# The phenomenon, down to what the reader reads: generate! places it as the game's does once it finds a tile, and
# drawAnim answers whether the game draws and sounds it there, by the game's own range. The harness loaded the plugin
# before this class existed, so its hook is evaluated again over this one.
class Phenomenon
  attr_accessor :x, :y, :type, :active, :spot

  def generate!
    return unless @spot
    @x, @y, @type = @spot
    @active = true
  end

  def drawAnim(_sound)
    ((@x - $game_player.x).abs + (@y - $game_player.y).abs) / 4 <= 6
  end
end
phen_path = File.join(Harness::ROOT, "plugins", "boons_phenomena.rb")
phen_source = Harness.source(phen_path)
phen_source.scan(/^PokeAccess::Hooks\.before_hook\("Phenomenon".*?^end\r?\n/m) do
  hook = Regexp.last_match
  eval(hook[0], TOPLEVEL_BINDING, phen_path, phen_source[0, hook.begin(0)].count("\n") + 1)
end

class BoonsPhenomenaGdTest < PokeAccessTest
  # The game's PokemonTemp, down to the phenomenon it holds (nil once one is cancelled).
  Temp = Struct.new(:phenomenon)

  def setup
    super
    @temp = $PokemonTemp
    @scene = $scene
    $PokemonTemp = Temp.new(nil)
    $scene = Scene_Map.new
    $game_player.x = 10
    $game_player.y = 10
  end

  def teardown
    $PokemonTemp = @temp
    $scene = @scene
    super
  end

  test "a phenomenon the game draws is said by its kind and its place from the player, queued, once" do
    { :PhenomenonGrass => :phen_grass, :PhenomenonWater => :phen_water, :PhenomenonCave => :phen_cave,
      :PhenomenonBird => :phen_bird }.each do |type, key|
      phn = phenomenon(7, 12, type)
      2.times { phn.drawAnim(true) }
      assert_equal [appeared(key, -3, 2), false], SpeakCapture.log.last, "for #{type}"
    end
    assert_equal 4, SpeakCapture.log.length
  end

  test "one beyond the range the game draws is said only once the player walks within it, from where they stand" do
    phn = phenomenon(26, 22, :PhenomenonGrass)
    drawn = [phn.drawAnim(false)]
    $game_player.x = 11
    drawn.push(phn.drawAnim(false))
    assert_equal [[false, true], [[appeared(:phen_grass, 15, 12), false]]], [drawn, SpeakCapture.log]
  end

  test "nothing is said for a kind the plugin does not draw" do
    phenomenon(7, 12, :PhenomenonLava).drawAnim(true)
    assert_nothing_spoken
  end

  test "one said that goes away before the player reaches it is said gone once, queued, when the player is free" do
    said(7, 12, :PhenomenonWater)
    PokeAccess::Phenomena.tick
    $PokemonTemp.phenomenon = nil
    PokeAccess::Control.hold(:spec_message) { PokeAccess::Frame.run_pollers }
    held = SpeakCapture.log.dup
    2.times { PokeAccess::Frame.run_pollers }
    assert_equal [[], [[t(:phen_gone, :kind => t(:phen_water)), false]]], [held, SpeakCapture.log]
  end

  test "one the player walked onto, its battle or item following, goes unsaid" do
    said(7, 12, :PhenomenonGrass)
    $game_player.x = 7
    $game_player.y = 12
    $PokemonTemp.phenomenon = nil
    PokeAccess::Phenomena.tick
    assert_nothing_spoken
  end

  test "one left behind on another map goes unsaid" do
    said(7, 12, :PhenomenonCave)
    $game_map.map_id = 2
    $PokemonTemp.phenomenon = nil
    PokeAccess::Phenomena.tick
    assert_nothing_spoken
  end

  test "one forgotten by a map change or a load goes unsaid" do
    said(8, 12, :PhenomenonBird)
    PokeAccess::Caches.reset_all
    $PokemonTemp.phenomenon = nil
    PokeAccess::Phenomena.tick
    assert_nothing_spoken
  end

  test "one beyond the range the game draws, never said, goes unsaid" do
    phn = phenomenon(30, 30, :PhenomenonGrass)
    $PokemonTemp.phenomenon = phn
    phn.drawAnim(true)
    $PokemonTemp.phenomenon = nil
    PokeAccess::Phenomena.tick
    assert_nothing_spoken
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A phenomenon come out at (x, y) as the given kind.
  def phenomenon(x, y, type)
    phn = Phenomenon.new
    phn.spot = [x, y, type]
    phn.generate!
    phn
  end

  # A phenomenon the game holds and has drawn near the player, its appearance said and cleared from the log.
  def said(x, y, type)
    phn = phenomenon(x, y, type)
    $PokemonTemp.phenomenon = phn
    phn.drawAnim(true)
    SpeakCapture.clear
    phn
  end

  # The appearance line for a kind dx, dy from the player.
  def appeared(key, dx, dy)
    t(:phen_appeared, :kind => t(key), :where => PokeAccess::Locator.dir_phrase(dx, dy))
  end
end
