# Lens of Truth (#EOT) tiles form a :lens locator category, present only on maps that hold one; they also show under
# :all, named with the hidden-area label.
Suite.define("locator: #EOT tiles form a navigable :lens category") do
  loc = PokeAccess::Locator
  PokeAccess::Config.hide_unreachable = false
  lens = World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => 10, :y => 8)
  obj  = World.event(:name => "EV010", :id => 6, :x => 3, :y => 3, :character_name => "object")

  truthy "the #EOT tile is recognised as a lens tile", loc.lens_tile?(lens)
  truthy "it falls in the :lens category", loc.in_category?(lens, :lens)
  falsy  "a plain object does not", loc.in_category?(obj, :lens)
  truthy "it also shows under :all", loc.in_category?(lens, :all)
  eq "it is spoken as the hidden-area label", PokeAccess::I18n.t(:loc_lens), loc.target_name(lens)

  $game_map.events[5] = lens
  truthy "the map now reports a lens tile", loc.any_lens_tile?
  truthy ":lens joins the cycled categories on this map", loc.active_categories.include?(:lens)

  $game_map.events.delete(5)
  falsy ":lens drops out on a map with none", loc.active_categories.include?(:lens)
end

# With hide_unreachable on, :lens is dropped when its only tiles are unreachable and kept when the flood was
# truncated; the flood is pinned through the pathfinder's cached set and its completeness flag.
Suite.define("locator: :lens respects hide-unreachable") do
  loc = PokeAccess::Locator
  pf = PokeAccess::Pathfinder
  far = World.event(:name => "#EOT HIDE", :id => 7, :x => 90, :y => 21)
  $game_map.events.clear
  $game_map.events[7] = far

  pin = lambda do |set, full|
    pf.instance_variable_set(:@rs, set)
    pf.instance_variable_set(:@rs_full, full)
    pf.instance_variable_set(:@rs_key, [($game_player.x rescue 0), ($game_player.y rescue 0), ($game_map.map_id rescue 0)])
  end

  pin.call({}, true)
  PokeAccess::Config.hide_unreachable = true
  falsy ":lens hidden when its only tiles are unreachable", loc.active_categories.include?(:lens)

  PokeAccess::Config.hide_unreachable = false
  truthy ":lens shown when the filter is off", loc.active_categories.include?(:lens)

  pin.call({ pf.pkey(90, 21) => true }, true)
  PokeAccess::Config.hide_unreachable = true
  truthy ":lens shown when a tile is reachable", loc.active_categories.include?(:lens)

  pin.call({}, false)
  PokeAccess::Config.hide_unreachable = true
  truthy ":lens shown when the flood was truncated", loc.active_categories.include?(:lens)

  PokeAccess::Config.hide_unreachable = false
  pf.instance_variable_set(:@rs, nil)
  pf.instance_variable_set(:@rs_full, nil)
  pf.instance_variable_set(:@rs_key, nil)
  $game_map.events.delete(7)
end

# The hidden-area step-on cue sweeps the map's events once per tile entered, not every frame (the stub table counts
# the sweeps).
Suite.define("spatial: the hidden-area cue is checked once per tile, not once per frame") do
  sp = PokeAccess::Spatial
  px = $game_player.x; py = $game_player.y
  lens = World.event(:name => "Misterio#EOT_HIDE", :id => 5, :x => px, :y => py)
  sweeps = Class.new(Hash) do
    attr_reader :hits
    def values; @hits = (@hits || 0) + 1; super; end
  end.new
  sweeps[5] = lens
  plain = $game_map.events
  $game_map.instance_variable_set(:@events, sweeps)
  begin
    sp.reset_map_state
    SpeakCapture.clear
    sp.announce_lens_tile
    eq "stepping onto the tile says the cue", SpeakCapture.lines, [PokeAccess::I18n.t(:lens_tile_here)]

    SpeakCapture.clear
    3.times { sp.announce_lens_tile }
    silent "and the frames that follow say nothing"
    eq "because the map was swept once, on arrival", sweeps.hits, 1

    $game_player.x = px + 1
    sp.announce_lens_tile
    $game_player.x = px
    SpeakCapture.clear
    sp.announce_lens_tile
    eq "coming back onto the tile says it again", SpeakCapture.lines, [PokeAccess::I18n.t(:lens_tile_here)]
    eq "one sweep per tile entered", sweeps.hits, 3
  ensure
    $game_map.instance_variable_set(:@events, plain)
    $game_player.x = px
    sp.reset_map_state
  end
end
