# Sevii's own paint over stock screens (games/sevii/screens.rb), over stand-ins shaped as Sevii's: the Pokegear's
# clock, the old Day-Care Checker of FL its Day-Care app opens, and the back hint its region map backgrounds draw.

# Sevii's Pokegear: the stock one with its clock, painted from main after the buttons and again on every frame,
# answering true when it repainted; times holds the clock each call finds, the last one kept.
class SeviiPokegearStandIn < Scene_Pokegear
  attr_accessor :times
  def build; super; updateDateIfNecessary; end
  def update; updateDateIfNecessary; super; end
  def updateDateIfNecessary
    now = (@times.length > 1 ? @times.shift : @times[0]) if @times
    return false if now.nil? || now == @dateString
    @dateString = now
    pbDrawTextPositions(nil, [[now, 256, -2, 2]])
    true
  end
end

# FL's old Day-Care Checker: startScene paints each Pokemon's line and shows the egg's picture while one waits.
class DayCareCheckerScene
  def initialize(rows, egg = false); @rows = rows; @egg = egg; end
  def startScene
    @sprites = {}
    @sprites["egg"] = Object.new if @egg
    pbDrawTextPositions(nil, @rows) unless @rows.empty?
    :started
  end
  def endScene; :ended; end
end

# Sevii's region map, with the loop its opening hands over to.
class SeviiRegionMapStandIn < PokemonRegionMapScene
  def pbMapScene(_mode = 0); :closed; end
end

class SeviiScreensTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "screens.rb")

  test "the Pokegear says its clock, without the seconds, as it opens, behind the focused option" do
    open_gear(["03:27:15 PM"])
    assert_equal [["Map", true], ["03:27 PM", false]], SpeakCapture.log
  end

  test "the Pokegear's clock keeps the info key on the time shown as it ticks, and says nothing more" do
    open_gear(["03:27:15 PM", "03:27:16 PM", "03:28:00 PM"])
    assert_equal [["Map", "03:27 PM"], "03:28 PM"], [SpeakCapture.lines, PokeAccess::Info.info_text]
  end

  test "the Day-Care Checker says each Pokemon as painted, left to right, then the egg, and keeps it on the info key" do
    self.class.bind
    rows = [["Ditto Lv. 30   ", 496, 44, true], ["Pikachu Lv. 12  ♂", 32, 44, false]]
    assert_equal :started, DayCareCheckerScene.new(rows, true).startScene, "the scene keeps its own answer"
    parts = [PokeAccess.clean("Pikachu Lv. 12  ♂"), PokeAccess.clean("Ditto Lv. 30   "), t(:dcheck_egg)]
    line = PokeAccess.sentences(parts)
    assert_equal [[[line, false]], line], [SpeakCapture.log, PokeAccess::Info.info_text]
  end

  test "the Day-Care Checker takes its line off the info key as it closes" do
    self.class.bind
    scene = DayCareCheckerScene.new([["Pikachu Lv. 12  ♂", 32, 44, false]])
    scene.startScene
    assert_equal :ended, scene.endScene
    assert_equal "", PokeAccess::Info.info_text.to_s
  end

  test "the region map says the back hint its background paints, with the key B is on, as its loop starts" do
    self.class.bind
    assert_equal :closed, SeviiRegionMapStandIn.new.pbMapScene
    assert_equal [[t(:sv_map_back, :key => "X"), false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Opens Sevii's Pokegear as main does, then runs its update for each later clock in times.
  def open_gear(times)
    self.class.bind
    gear = SeviiPokegearStandIn.new(["Map", "Storage"])
    gear.times = times.dup
    gear.build
    (times.length - 1).times { gear.update }
  end

  # Evaluates screens.rb once, its Pokegear and region map hooks bound to the stand-ins set for the moment under the
  # game's names, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    stand_in(:Scene_Pokegear => SeviiPokegearStandIn, :PokemonRegionMapScene => SeviiRegionMapStandIn) do
      profiles = PokeAccess::Game.profiles.dup
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
      PokeAccess::Game.instance_variable_set(:@profiles, profiles)
      PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    end
  end

  # Runs the block with each class under its game name in place of the one there, put back after.
  def self.stand_in(swaps)
    priors = swaps.keys.map { |n| [n, Object.send(:remove_const, n)] }
    swaps.each { |n, k| Object.const_set(n, k) }
    yield
  ensure
    swaps.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) }
  end
end
