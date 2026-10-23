# Driving the guides (PokeAccess::Guide) as the map frame does, from the specs.

# Drives the guide and the cane a frame at a time, for the guide tests.
module GuideHelpers
  # Points the cane alone at target with nothing remembered, so the next frame plans and chimes.
  def guide_aim(loc, target)
    PokeAccess::Guide.stop
    loc.instance_variable_set(:@target, target)
    PokeAccess::Guide.switch(:cane, true)
  end

  # Points the step guide alone at target with nothing remembered, so the next frame plans and speaks.
  def steps_aim(loc, target)
    PokeAccess::Guide.stop
    loc.instance_variable_set(:@target, target)
    PokeAccess::Guide.switch(:steps, true)
  end

  # One map frame of the guides.
  def guide_frame
    World.next_frame
    PokeAccess::Guide.tick
  end

  # Puts the player on a tile, runs one map frame of the guides and returns what they said.
  def walk_to(_loc, x, y)
    $game_player.x = x
    $game_player.y = y
    SpeakCapture.clear
    guide_frame
    SpeakCapture.lines
  end

  # Backdates the cane's last chime to secs ago, standing in for frames passing without sleeping.
  def guide_rewind(_loc, secs)
    PokeAccess::Guide.instance_variable_set(:@chime_at, PokeAccess.clock - secs)
  end

  # Runs the block with the guides off before and after, the selection put back and the test grid dropped after, and
  # with a $Trainer, since the guides are silent while Control is held (no trainer reads as character selection).
  def with_guide_state
    loc = PokeAccess::Locator
    prev = loc.instance_variable_get(:@target)
    had_trainer = $Trainer
    $Trainer = Object.new
    def $Trainer.name; "Rojo"; end
    PokeAccess::Guide.stop
    assert PokeAccess::Control.free?, "the player is not stuck on the character-selection screen"
    yield loc
  ensure
    $Trainer = had_trainer
    PokeAccess::Guide.stop
    loc.instance_variable_set(:@target, prev)
    $game_map.clear_ledges
    $game_map.clear_grid
  end

  # Yields a log of [file, volume, pitch] for every Audio.se_play, where each cue lands under test (no 3D engine).
  def with_cue_log
    log = []
    orig = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
    yield log
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end

  # The basename of a logged cue (the path is prefixed with the sounds folder).
  def cue_name(entry)
    entry[0].to_s.split("/").last
  end
end
