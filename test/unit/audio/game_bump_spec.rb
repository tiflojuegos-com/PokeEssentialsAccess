# The game's own bump -- "bump" in the gen-6 era, "Player bump" from v18 on -- filtered at pbSEPlay, the one
# function every engine plays it through, so a push against a wall gives ONE bump. Pinned here is the rule
# that keeps it exactly one, never zero and never two: the game's bump is swallowed when the mod's wall cue
# is about to answer for the push (on the map with the mod on, its menu shut, no event or message holding
# the player, a direction held against an impassable tile and the setting not asking the game's back), or
# has just answered it (a cue that was heard, within its cooldown plus SAME_PUSH, towards the same wall,
# with the push still on or only just let go). Anything else plays.
#
# The name alone is not enough: sixty-two places across the fifteen games play this file and only
# Game_Player's are the wall. Relict's autosurf bumps at the water's edge, on the map and outside any menu.
# The team photo of Anil and Royal bumps at the edge of its camera and Royal's snake game on its countdown,
# both run by an event with an arrow held, where the mod's cue never plays; with anything solid ahead of the
# player (the photo turns the player to face down), the wall test alone swallowed those bumps.

# Lets a spec dictate what direction is held. Transparent while nil, so nothing else in the run sees it.
$pa_spec_dir4 = nil
class << Input
  unless method_defined?(:dir4__pa_spec_orig) || private_method_defined?(:dir4__pa_spec_orig)
    alias_method :dir4__pa_spec_orig, :dir4
    def dir4; $pa_spec_dir4 || dir4__pa_spec_orig; end
  end
end

# Runs the block in the state a wall bump happens in -- on the map, out of menus, a direction held, standing
# still, the tile ahead impassable unless the caller asks otherwise -- with a fresh sound log, and restores
# everything it touched.
def with_walk_state(blocked = true)
  cfg = PokeAccess::Config
  sp = PokeAccess::Spatial
  saved = [cfg.game_bump, cfg.sound_nav, cfg.wall_volume, $scene, $game_temp.in_menu, $game_player,
           sp.instance_variable_get(:@bump_time), sp.instance_variable_get(:@bump_heard), cfg.bump_cooldown,
           sp.instance_variable_get(:@push_seen), sp.instance_variable_get(:@bump_dir),
           sp.instance_variable_get(:@was_blocked)]
  [:@bump_time, :@bump_heard, :@push_seen, :@bump_dir].each { |iv| sp.instance_variable_set(iv, nil) }
  sp.instance_variable_set(:@was_blocked, false)
  cfg.bump_cooldown = 16
  cfg.game_bump = false
  cfg.sound_nav = :full
  cfg.wall_volume = 80
  $scene = Scene_Map.new
  $game_temp.in_menu = false
  player = Game_Player.new
  player.instance_variable_set(:@pa_blocked, blocked)
  def player.passable?(_x, _y, _d); !@pa_blocked; end
  $game_player = player
  $pa_spec_dir4 = 2
  $se_played = []
  yield cfg
ensure
  $pa_spec_dir4 = nil
  cfg.game_bump = saved[0]
  cfg.sound_nav = saved[1]
  cfg.wall_volume = saved[2]
  $scene = saved[3]
  $game_temp.in_menu = saved[4]
  $game_player = saved[5]
  PokeAccess::Spatial.instance_variable_set(:@bump_time, saved[6])
  PokeAccess::Spatial.instance_variable_set(:@bump_heard, saved[7])
  cfg.bump_cooldown = saved[8]
  PokeAccess::Spatial.instance_variable_set(:@push_seen, saved[9])
  PokeAccess::Spatial.instance_variable_set(:@bump_dir, saved[10])
  PokeAccess::Spatial.instance_variable_set(:@was_blocked, saved[11])
end

Suite.define("game bump: the walk's bump is swallowed while the mod's cue replaces it, everything else plays") do
  with_walk_state do
    pbSEPlay("Player bump")
    pbSEPlay("bump", 80, 100)
    eq "neither era's bump reaches the engine", $se_played, []
    pbSEPlay("Cursor")
    pbSEPlay("Player bump 2")
    eq "other sounds, and names that only resemble it, play", $se_played, ["Cursor", "Player bump 2"]
    file = Struct.new(:name).new("Audio/SE/Player bump.wav")
    truthy "an audio file object naming the bump counts", PokeAccess::Spatial.game_bump?(file)
    falsy "a nil parameter is not the bump", PokeAccess::Spatial.game_bump?(nil)
  end
end

Suite.define("game bump: it plays again when asked back, when the mod's cue is off, or away from the walk") do
  with_walk_state do |cfg|
    cfg.game_bump = true
    pbSEPlay("Player bump")
    eq "the setting on lets the game's bump through", $se_played, ["Player bump"]
    cfg.game_bump = false

    $se_played = []
    cfg.sound_nav = :off
    pbSEPlay("Player bump")
    eq "sound navigation off means the mod has no bump, so the game keeps its own", $se_played, ["Player bump"]
    cfg.sound_nav = :full

    $se_played = []
    cfg.wall_volume = 0
    pbSEPlay("bump")
    eq "so does a wall volume of zero", $se_played, ["bump"]
    cfg.wall_volume = 80

    $se_played = []
    $game_temp.in_menu = true
    pbSEPlay("Player bump")
    eq "a menu borrowing the file keeps it", $se_played, ["Player bump"]
    $game_temp.in_menu = false

    $se_played = []
    PokeAccess::Spatial.instance_variable_set(:@bump_heard, true)
    PokeAccess::Spatial.instance_variable_set(:@bump_dir, $game_player.direction)
    PokeAccess::Spatial.instance_variable_set(:@bump_time, PokeAccess.clock)
    $scene = Object.new
    pbSEPlay("Player bump")
    eq "and so does any screen that is not the map, even right after a cue on it", $se_played, ["Player bump"]
  end
end

Suite.define("game bump: a bump that is not a WALL keeps sounding, because nothing of ours replaces it") do
  with_walk_state(false) do
    pbSEPlay("Player bump")
    eq "the tile ahead is walkable, so this bump is somebody else's business and it plays",
       $se_played, ["Player bump"]
  end

  with_walk_state do
    $pa_spec_dir4 = 0
    $se_played = []
    pbSEPlay("Player bump")
    eq "and with no direction held there is no walk to bump against either", $se_played, ["Player bump"]
  end
end

Suite.define("game bump: whenever the mod's own cue cannot play, the game's bump plays even against a wall") do
  with_walk_state do
    interp = $game_system.map_interpreter
    def interp.running?; true; end
    begin
      pbSEPlay("Player bump")
      eq "an event running (a team photo's camera, a minigame's countdown) keeps the game's bump",
         $se_played, ["Player bump"]
    ensure
      def interp.running?; false; end
    end

    $se_played = []
    was = $game_temp.message_window_showing
    $game_temp.message_window_showing = true
    begin
      pbSEPlay("bump")
      eq "and so does an open message: the mod's own cue stands down for both", $se_played, ["bump"]
    ensure
      $game_temp.message_window_showing = was
    end

    $se_played = []
    keys = PokeAccess::Keys
    keys.instance_variable_set(:@enabled, false)
    begin
      pbSEPlay("Player bump")
      eq "the mod switched off (Ctrl+Alt+F8) runs no cue, so the game keeps its bump", $se_played, ["Player bump"]
    ensure
      keys.instance_variable_set(:@enabled, true)
    end

    $se_played = []
    menu = PokeAccess::ConfigMenu
    menu.instance_variable_set(:@active, true)
    begin
      pbSEPlay("bump")
      eq "and the mod's own menu, while open, runs none either", $se_played, ["bump"]
    ensure
      menu.instance_variable_set(:@active, false)
    end
  end
end

Suite.define("game bump: a bump right after the mod's own cue answers the same push, even from an event") do
  with_walk_state do
    sp = PokeAccess::Spatial
    interp = $game_system.map_interpreter
    def interp.running?; true; end
    was = sp.instance_variable_get(:@bump_time)
    begin
      sp.instance_variable_set(:@bump_heard, true)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock)
      pbSEPlay("Player bump")
      eq "a touch event the push set off bumps a frame after the mod's cue: one bump, not two", $se_played, []
      sp.instance_variable_set(:@bump_time, PokeAccess.clock - 5)
      pbSEPlay("Player bump")
      eq "long after the cue it is the event's own sound, and it plays", $se_played, ["Player bump"]
      $se_played = []
      sp.instance_variable_set(:@bump_time, PokeAccess.clock)
      $pa_spec_dir4 = 0
      pbSEPlay("Player bump")
      eq "and with no arrow held there is no push for the cue to have answered", $se_played, ["Player bump"]
    ensure
      def interp.running?; false; end
      sp.instance_variable_set(:@bump_time, was)
    end
  end
end

Suite.define("game bump: a v21 bump's one-step animation is no walk, so the mod's cue answers the push at once") do
  with_walk_state do
    player = $game_player
    def player.moving?; true; end
    player.instance_variable_set(:@bumping, true)
    sp = PokeAccess::Spatial
    sp.instance_variable_set(:@was_blocked, false)
    truthy "the filter still hands the push to the mod's cue during the bump step", sp.wall_cue_takes_over?
    sp.wall_cue
    truthy "and the cue sounds then, instead of waiting the step out", !sp.instance_variable_get(:@bump_time).nil?
    player.instance_variable_set(:@bumping, false)
    falsy "a real step is still a walk the filter leaves alone", sp.wall_cue_takes_over?
  end
end

Suite.define("game bump: a held push repeats the mod's cue every cooldown, and a game bump in between answers it") do
  with_walk_state do
    sp = PokeAccess::Spatial
    interp = $game_system.map_interpreter
    def interp.running?; true; end
    begin
      sp.instance_variable_set(:@bump_heard, true)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock - 0.3)
      pbSEPlay("Player bump")
      eq "0.3 s after the cue, inside its 0.4 s cooldown, the event's bump belongs to the same push", $se_played, []
      sp.instance_variable_set(:@bump_time, PokeAccess.clock - sp.cue_cooldown - 0.001)
      pbSEPlay("Player bump")
      eq "and so does one on the frame the cooldown lets the cue repeat, which the interpreter runs first",
         $se_played, []
    ensure
      def interp.running?; false; end
    end
  end
end

Suite.define("game bump: when the positional engine would take the cue at a master volume of zero, the game's bump plays") do
  with_walk_state do |cfg|
    a3 = PokeAccess::Audio3D
    kept = [a3.instance_variable_get(:@ready), a3.instance_variable_get(:@active), a3.instance_variable_get(:@ch)]
    master = cfg.audio3d_volume
    a3.instance_variable_set(:@ready, true)
    a3.instance_variable_set(:@active, true)
    a3.instance_variable_set(:@ch, { :wall => 0, :interact => 1 })
    cfg.audio3d_volume = 0
    begin
      pbSEPlay("Player bump")
      eq "the mod's cue would be silent, so the game keeps its bump", $se_played, ["Player bump"]
      cfg.audio3d_volume = 80
      $se_played = []
      pbSEPlay("Player bump")
      eq "at an audible master the cue takes over as usual", $se_played, []
    ensure
      a3.instance_variable_set(:@ready, kept[0])
      a3.instance_variable_set(:@active, kept[1])
      a3.instance_variable_set(:@ch, kept[2])
      cfg.audio3d_volume = master
    end
  end
end

Suite.define("game bump: the same-push window never drops below SAME_PUSH, and only a cue that was heard counts") do
  with_walk_state do |cfg|
    sp = PokeAccess::Spatial
    interp = $game_system.map_interpreter
    def interp.running?; true; end
    begin
      cfg.bump_cooldown = 0
      sp.instance_variable_set(:@bump_heard, true)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock - 0.1)
      pbSEPlay("Player bump")
      eq "with no cooldown at all a bump a tenth of a second later still answers the same push", $se_played, []
      cfg.bump_cooldown = 16
      sp.instance_variable_set(:@bump_heard, false)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock)
      pbSEPlay("Player bump")
      eq "a cue nobody heard (the positional master at zero when it played) answers nothing, so the game's plays",
         $se_played, ["Player bump"]
    ensure
      def interp.running?; false; end
    end
  end
end

Suite.define("game bump: the positional engine takes a cue only on that cue's channel, and only while active") do
  with_walk_state do |cfg|
    a3 = PokeAccess::Audio3D
    kept = [a3.instance_variable_get(:@ready), a3.instance_variable_get(:@active), a3.instance_variable_get(:@ch)]
    master = cfg.audio3d_volume
    begin
      a3.instance_variable_set(:@ready, true)
      a3.instance_variable_set(:@active, true)
      a3.instance_variable_set(:@ch, { :wall => 0 })
      truthy "a wall bump has its channel", a3.bump_ready?(false)
      falsy "a bump against something to interact with has none, so the flat cue would play", a3.bump_ready?(true)
      a3.instance_variable_set(:@active, false)
      cfg.audio3d_volume = 0
      pbSEPlay("Player bump")
      eq "an engine ready but inactive leaves the flat cue to answer, so the game's bump stays muted", $se_played, []
    ensure
      a3.instance_variable_set(:@ready, kept[0])
      a3.instance_variable_set(:@active, kept[1])
      a3.instance_variable_set(:@ch, kept[2])
      cfg.audio3d_volume = master
    end
  end
end

Suite.define("game bump: a touch event's bump the frame after the arrow is let go still answers that push") do
  with_walk_state do
    sp = PokeAccess::Spatial
    interp = $game_system.map_interpreter
    def interp.running?; true; end
    begin
      sp.instance_variable_set(:@bump_heard, true)
      sp.instance_variable_set(:@bump_dir, $game_player.direction)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock - 0.075)
      sp.instance_variable_set(:@push_seen, PokeAccess.clock - 0.025)
      $pa_spec_dir4 = 0
      pbSEPlay("Player bump")
      eq "let go a frame ago, the event's bump is still the push's second answer", $se_played, []
      sp.instance_variable_set(:@push_seen, PokeAccess.clock - 1.0)
      pbSEPlay("Player bump")
      eq "long after the release it is a sound of its own, and it plays", $se_played, ["Player bump"]
    ensure
      def interp.running?; false; end
    end
  end
end

Suite.define("game bump: turning to another wall with the arrow still down answers the new wall at once") do
  with_walk_state do
    sp = PokeAccess::Spatial
    player = $game_player
    player.direction = 2
    sp.wall_cue
    eq "the wall below is cued", sp.instance_variable_get(:@bump_dir), 2
    player.direction = 4
    $pa_spec_dir4 = 4
    sp.wall_cue
    eq "and the wall to the left at once, without waiting out the first cue's cooldown",
       sp.instance_variable_get(:@bump_dir), 4

    interp = $game_system.map_interpreter
    def interp.running?; true; end
    begin
      sp.instance_variable_set(:@bump_dir, 2)
      sp.instance_variable_set(:@bump_time, PokeAccess.clock)
      pbSEPlay("Player bump")
      eq "a bump towards another wall than the cue's is not that push's second answer", $se_played, ["Player bump"]
    ensure
      def interp.running?; false; end
    end
  end
end

Suite.define("game bump: a cue the positional engine played at a master volume of zero is marked unheard") do
  with_walk_state do |cfg|
    a3 = PokeAccess::Audio3D
    kept = [a3.instance_variable_get(:@ready), a3.instance_variable_get(:@active), a3.instance_variable_get(:@ch)]
    master = cfg.audio3d_volume
    interp = $game_system.map_interpreter
    begin
      a3.instance_variable_set(:@ready, true)
      a3.instance_variable_set(:@active, true)
      a3.instance_variable_set(:@ch, { :wall => 0, :interact => 1 })
      cfg.audio3d_volume = 0
      PokeAccess::Spatial.wall_cue
      falsy "the engine took the cue at master zero, so nobody heard it",
            PokeAccess::Spatial.instance_variable_get(:@bump_heard)
      def interp.running?; true; end
      pbSEPlay("Player bump")
      eq "and the event's bump right after it plays: the only one the player hears", $se_played, ["Player bump"]
      cfg.audio3d_volume = 80
      PokeAccess::Spatial.instance_variable_set(:@bump_time, nil)
      PokeAccess::Spatial.instance_variable_set(:@was_blocked, false)
      PokeAccess::Spatial.wall_cue
      truthy "at an audible master the same engine cue is heard", PokeAccess::Spatial.instance_variable_get(:@bump_heard)
      $se_played = []
      pbSEPlay("Player bump")
      eq "and then the event's bump is the push's second answer", $se_played, []
    ensure
      def interp.running?; false; end
      a3.instance_variable_set(:@ready, kept[0])
      a3.instance_variable_set(:@active, kept[1])
      a3.instance_variable_set(:@ch, kept[2])
      cfg.audio3d_volume = master
    end
  end
end

Suite.define("game bump: against something to interact with, the filter asks about the channel that cue will use") do
  with_walk_state do |cfg|
    a3 = PokeAccess::Audio3D
    kept = [a3.instance_variable_get(:@ready), a3.instance_variable_get(:@active), a3.instance_variable_get(:@ch)]
    master = cfg.audio3d_volume
    fx, fy = PokeAccess::Spatial.front_tile
    ev = TestEvent.new(901, "npc", fx, fy)
    ev.instance_variable_set(:@trigger, 0)
    ev.instance_variable_set(:@list, [Struct.new(:code).new(PokeAccess::Locator::EXAMINE_CODES.first)])
    events = $game_map.events
    events[901] = ev
    begin
      truthy "the tile ahead holds something to interact with", PokeAccess::Spatial.interact_ahead?
      a3.instance_variable_set(:@ready, true)
      a3.instance_variable_set(:@active, true)
      a3.instance_variable_set(:@ch, { :wall => 0 })
      cfg.audio3d_volume = 0
      pbSEPlay("Player bump")
      eq "with no interact channel the flat cue answers and is heard, so the game's bump stays muted", $se_played, []
    ensure
      events.delete(901)
      a3.instance_variable_set(:@ready, kept[0])
      a3.instance_variable_set(:@active, kept[1])
      a3.instance_variable_set(:@ch, kept[2])
      cfg.audio3d_volume = master
    end
  end
end
