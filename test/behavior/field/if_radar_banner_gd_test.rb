# Infinite Fusion's Poke Radar banner (games/infinitefusion_common/radar_banner.rb): a new banner names the route's
# seen species, counts the silhouettes, and the radar's rare ones apart; then the light says whether a rare one can
# appear. The game's two functions, reduced to what they leave behind, come before the profile file binds to them.

# The banner as the game builds it: the route's species seen and unseen, and the radar's rare ones.
class IFSpecRadarUI
  def initialize(seen, unseen, rare)
    @seen_pokemon = seen
    @unseen_pokemon = unseen
    @rare_pokemon = rare
  end
end

# The banner, built only while none is up (a chain going on keeps the one it has); its rare ones Pikachu and Mew.
def displayPokeradarBanner(seen = [], unseen = [], include_rare = false)
  return if $PokemonTemp.pokeradar_ui
  $PokemonTemp.pokeradar_ui = IFSpecRadarUI.new(seen, unseen, include_rare ? [:PIKACHU, :MEW] : [])
end

def playPokeradarLightAnimation(rare_allowed = false); rare_allowed; end

radar_path = File.join(Harness::ROOT, "games", "infinitefusion_common", "radar_banner.rb")
eval(Harness.source(radar_path), TOPLEVEL_BINDING, radar_path)

class IfRadarBannerGdTest < PokeAccessTest
  test "a new banner names the seen species and counts the silhouettes, the rare ones apart, interrupting" do
    on_route([:MEW]) { displayPokeradarBanner([:PIDGEY, :RATTATA], [:ODDISH, :ABRA], true) }
    assert_equal [["#{t(:if_radar_seen, :list => 'SpeciesPIDGEY, SpeciesRATTATA')}. #{t(:if_radar_unseen, :n => 2)}. " \
                   "#{t(:if_radar_rare, :list => 'SpeciesPIKACHU')}. #{t(:if_radar_rare_unseen, :n => 1)}", true]],
                 SpeakCapture.log
  end

  test "a route all seen, with no rare ones, names just its species" do
    on_route([]) { displayPokeradarBanner([:PIDGEY], [], false) }
    assert_equal [[t(:if_radar_seen, :list => "SpeciesPIDGEY"), true]], SpeakCapture.log
  end

  test "a banner already up, as the chain goes on, is not said again" do
    on_route([:MEW]) do
      displayPokeradarBanner([:PIDGEY], [], false)
      SpeakCapture.clear
      displayPokeradarBanner([:RATTATA], [], true)
    end
    assert_nothing_spoken
  end

  test "a banner with nothing on it says nothing" do
    on_route([]) { displayPokeradarBanner([], [], false) }
    assert_nothing_spoken
  end

  test "with no Pokedex to ask, every rare one counts as unseen" do
    on_route(nil) { displayPokeradarBanner([], [], true) }
    assert_equal [[t(:if_radar_rare_unseen, :n => 2), true]], SpeakCapture.log
  end

  test "the light says green when a rare one can appear and red when not, queued" do
    { true => :if_radar_rare_on, false => :if_radar_rare_off }.each do |rare_allowed, key|
      SpeakCapture.clear
      on_route([]) { playPokeradarLightAnimation(rare_allowed) }
      assert_equal [[t(key), false]], SpeakCapture.log, "rare allowed: #{rare_allowed}"
    end
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block on a route with no banner up and a Pokedex that has seen every species but those in unseen (no
  # Pokedex at all for nil), the game's globals put back after.
  def on_route(unseen)
    temp = $PokemonTemp
    trainer = $Trainer
    $PokemonTemp = Struct.new(:pokeradar_ui).new(nil)
    $Trainer = unseen && Object.new
    $Trainer.define_singleton_method(:seen?) { |species| !unseen.include?(species) } if unseen
    yield
  ensure
    $PokemonTemp = temp
    $Trainer = trainer
  end
end
