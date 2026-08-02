# Internal warps (destination is the current map: staircases, within-map transfers) used to be spoken as
# "exit to <this very map>", useless for orientation, and stepping on one was silent because the map id never
# changes. Now they are named "passage to the <dir>" and stepping one announces "you moved to the <dir>".
def mk_warp(id, x, y, dmap, dx, dy)
  pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, dmap, dx, dy])])
  TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [pg], :active_page => pg)
end

Suite.define("locator: internal warps are named as a passage with a direction") do
  loc = PokeAccess::Locator
  def $game_map.width; 98; end
  def $game_map.height; 35; end
  mid = $game_map.map_id

  inner = mk_warp(11, 21, 5, mid, 89, 14)  # destination on the same map, to the east
  outer = mk_warp(7, 69, 3, 999, 70, 10)   # destination on another map

  eq "same-map warp reads as a passage with cardinal", PokeAccess::I18n.t(:loc_passage_dir, :dir => PokeAccess::I18n.t(:dir_e)), loc.target_name(inner)
  match "other-map warp still reads as an exit", loc.target_name(outer), /salida a/
  eq "centre point has no cardinal", nil, loc.cardinal_of(49, 17)
end

Suite.define("locator: stepping an internal warp announces the teleport") do
  loc = PokeAccess::Locator
  def $game_map.width; 98; end
  def $game_map.height; 35; end
  setp = lambda { |x, y| $game_player.instance_variable_set(:@x, x); $game_player.instance_variable_set(:@y, y) }

  setp.call(21, 5); loc.announce_internal_teleport  # seed position
  SpeakCapture.clear
  setp.call(22, 5); loc.announce_internal_teleport
  silent "walking one tile is not a teleport"

  SpeakCapture.clear
  setp.call(89, 14); loc.announce_internal_teleport
  spoke "a same-map jump announces the move", /te has movido al este/
end

# A ledge hop moves the player two tiles in a single frame with no forced move route -- the same shape as an
# internal warp -- but jumping? is true on that frame. It must NOT be spoken as a teleport, and the locator's
# selection must survive the hop (no clear_targets / rebuild churn that would drop the focused target).
Suite.define("locator: a ledge hop is not announced as a teleport and keeps the selection") do
  loc = PokeAccess::Locator
  def $game_map.width; 98; end
  def $game_map.height; 35; end
  setp = lambda { |x, y| $game_player.instance_variable_set(:@x, x); $game_player.instance_variable_set(:@y, y) }
  focus = World.event(:kind => :npc, :id => 3, :x => 80, :y => 14)
  loc.instance_variable_set(:@targets, [focus]); loc.instance_variable_set(:@target, focus); loc.instance_variable_set(:@ti, 0)

  setp.call(89, 12); loc.announce_internal_teleport  # seed position
  SpeakCapture.clear
  $game_player.jumping = true
  setp.call(89, 14); loc.announce_internal_teleport  # two-tile hop straight down, mid-jump
  silent "a two-tile ledge hop is not announced as a teleport"
  truthy "the selected target survives the hop", loc.instance_variable_get(:@target).equal?(focus)
  falsy "the target list is not blanked by the hop", loc.instance_variable_get(:@targets).empty?
  $game_player.jumping = false
end

# The jumping? guard must be specific to hops, not a blanket suppressor: a genuine within-map teleport (a big
# delta, not mid-jump) is still spoken and still resets the target list for the new spot.
Suite.define("locator: a genuine teleport still announces even next to the ledge case") do
  loc = PokeAccess::Locator
  def $game_map.width; 98; end
  def $game_map.height; 35; end
  setp = lambda { |x, y| $game_player.instance_variable_set(:@x, x); $game_player.instance_variable_set(:@y, y) }

  $game_player.jumping = false
  setp.call(5, 5); loc.announce_internal_teleport  # seed position
  SpeakCapture.clear
  setp.call(89, 14); loc.announce_internal_teleport  # large same-map jump, not mid-jump
  spoke "a real teleport is still announced", /te has movido/
end
