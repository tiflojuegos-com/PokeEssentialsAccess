# FieldStates: two field mechanics shown only through animation, spin tiles and the Lens of Truth.

# Spinning names the player's facing, not the tile underfoot (the plugin turns and moves them in one call), then each
# redirect and the stop.
Suite.define("nav/field states: spinning names its direction and every redirect, then the stop") do
  fs = PokeAccess::FieldStates
  prev_dir = $game_player.direction
  begin
    fs.reset
    def $PokemonGlobal.spinning; @pa_spin; end
    def $PokemonGlobal.spinning=(v); @pa_spin = v; end
    $game_player.direction = 8

    $PokemonGlobal.spinning = false
    SpeakCapture.clear
    fs.spin_poll
    silent "standing still says nothing"

    $PokemonGlobal.spinning = true
    fs.spin_poll
    spoke "stepping onto a spin tile names the direction", /#{PokeAccess::I18n.t(:fs_spin_up)}/

    SpeakCapture.clear
    fs.spin_poll
    silent "and does not repeat it every frame"

    $game_player.direction = 6
    fs.spin_poll
    spoke "a redirect mid-spin names the new direction", /#{PokeAccess::I18n.t(:fs_spin_right)}/

    SpeakCapture.clear
    $PokemonGlobal.spinning = false
    fs.spin_poll
    spoke "and coming to a halt is said too", /#{PokeAccess::I18n.t(:fs_spin_stop)}/
  ensure
    fs.reset
    $game_player.direction = prev_dir
    ($PokemonGlobal.spinning = false rescue nil)
  end
end

Suite.define("nav/field states: the Lens of Truth window is announced at both ends") do
  fs = PokeAccess::FieldStates
  prev = $scene
  begin
    fs.reset
    scene = Scene_Map.new rescue Object.new
    left = 0
    scene.define_singleton_method(:eye_of_truth_time) { left }
    $scene = scene

    SpeakCapture.clear
    fs.lens_poll
    silent "with no lens running there is nothing to say"

    left = 560
    fs.lens_poll
    spoke "using the item announces that it took effect", /#{PokeAccess::I18n.t(:fs_lens_on)}/

    SpeakCapture.clear
    left = 12
    fs.lens_poll
    silent "the countdown itself is not narrated frame by frame"

    left = 0
    fs.lens_poll
    spoke "and running out is announced, which is the part with no other signal",
          /#{PokeAccess::I18n.t(:fs_lens_off)}/
  ensure
    $scene = prev
    fs.reset
  end
end
