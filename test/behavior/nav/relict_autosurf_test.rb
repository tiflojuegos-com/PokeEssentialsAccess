# Relict's Autosurf (games/relict/field_moves.rb): the routes plan a way by water only where walking into water starts
# surfing, a floor whose map metadata has the dungeonDisplay flag with switch 60 on, whoever walks along; elsewhere
# none, as its pbSurf and the party's Surf never surf, and the water ahead said as plain water.
class RelictAutosurfTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "relict", "field_moves.rb")
  T = PokeAccess::I18n
  # A shore two steps from the player, two tiles of water, and (7, 1) beyond them, reached by water alone.
  STRAIT = ["#########",
            "#@..~~..#",
            "#########"].freeze

  test "a map whose metadata lacks dungeonDisplay has no way by water, where the core's own rule plans one" do
    got = [false, true].map { |relict| on_floor(false, true, relict) { plan.kind } }
    assert_equal [:surf, :none], got, "without Relict's rule, then with it"
  end

  test "a dungeonDisplay floor with switch 60 on has the way by water, walked into, with a follower along" do
    on_floor(true, true) do
      $game_player.define_singleton_method(:can_ride_vehicle_with_follower?) { false }
      p = plan
      assert_equal [:surf, [6, 6], 6], [p.kind, p.route, p.launch]
      assert_equal T.t(:loc_surf_toward, :dir => T.t(:toward_right)), PokeAccess::Routes::Text.surf_hold(p.launch)
    end
  end

  test "a dungeonDisplay floor with switch 60 off has no way by water" do
    on_floor(true, false) { assert_equal :none, plan.kind }
  end

  test "water ahead is said surfable only on a dungeonDisplay floor with switch 60 on, where Autosurf starts" do
    floors = [[false, true, false], [false, true, true], [true, true, true], [true, false, true]]
    got = floors.map { |flagged, on, relict| on_floor(flagged, on, relict) { cue } }
    surf = [[T.t(:surf_ahead), false]]
    water = [[T.t(:water_ahead), false]]
    assert_equal [surf, water, surf, water], got, "the core's rule off the floor, then Relict's off it, on it, switch 60 off"
  end

  private

  # The plan to the land beyond STRAIT's water.
  def plan
    PokeAccess::Routes::Planner.plan(7, 1)
  end

  # What the surface notices say with the player on STRAIT's shore, facing its water.
  def cue
    cfg = PokeAccess::Config
    was = cfg.surface_cues
    cfg.surface_cues = true
    $game_player.x = 3
    $game_player.direction = 6
    PokeAccess::Surfaces.reset_map_state
    SpeakCapture.clear
    PokeAccess::Surfaces.surfaces
    SpeakCapture.log.dup
  ensure
    cfg.surface_cues = was
  end

  # Runs the block on STRAIT, its map's metadata flagged dungeonDisplay or not and switch 60 on or off, under Relict's
  # rules when relict; the block's value.
  def on_floor(flagged, on, relict = true)
    with_tile_world(STRAIT) do |world|
      meta = Object.new
      meta.define_singleton_method(:has_flag?) { |f| flagged && f == "dungeonDisplay" }
      world.define_singleton_method(:metadata) { meta }
      $game_switches[60] = on
      relict ? with_relict { yield } : yield
    end
  ensure
    $game_switches[60] = false
  end

  # Runs the block with Relict's field_moves.rb loaded, then puts back FieldMoves.can?, the rule on surfing with
  # someone along and the profiles it changed.
  def with_relict
    fm = PokeAccess::FieldMoves
    can = fm.method(:can?)
    company = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
    profiles = PokeAccess::Game.profiles.dup
    load PATH
    yield
  ensure
    fm.define_singleton_method(:can?, can)
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, company)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
