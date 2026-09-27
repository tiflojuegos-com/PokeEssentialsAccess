# Pokemon Z's speed key (games/pokemon_z/turbo.rb) through Input.update, whose innermost original stands in for Z's
# TurboNuevo stepping $GameSpeed: off the free map, as in a battle, the profile says the change; on the free map the
# core does, once; an update that moves nothing says nothing.
Suite.define("z turbo: the speed key is said in battle too, where the core stays silent") do
  t = PokeAccess::I18n
  old_scene = $scene
  had_stages = Object.const_defined?(:SPEEDUP_STAGES)
  inner = Input.method(:update__access_orig)
  presses = []
  begin
    Object.const_set(:SPEEDUP_STAGES, [1, 2, 3]) unless had_stages
    Input.define_singleton_method(:update__access_orig) do |*_a|
      step = presses.shift
      $GameSpeed = step unless step.nil?
      :updated
    end
    $game_player ||= Object.new
    $scene = Scene_Map.new
    $GameSpeed = 0
    PokeAccess::Battle.battle_started
    Input.update
    SpeakCapture.clear
    presses.push(1)
    eq "the update's own value is kept", Input.update, :updated
    eq "a press in a battle says the multiplier", SpeakCapture.lines, [t.t(:turbo_speed, :n => 2)]

    SpeakCapture.clear
    Input.update
    silent "an update that moves nothing says nothing"

    PokeAccess::Battle.battle_ended
    Input.update
    presses.push(2)
    Input.update
    eq "on the free map the core says it, and only the core", SpeakCapture.lines, [t.t(:turbo_speed, :n => 3)]

    SpeakCapture.clear
    $scene = Object.new
    presses.push(0)
    Input.update
    eq "off the map, on another scene, it is said too", SpeakCapture.lines, [t.t(:turbo_speed, :n => 1)]
  ensure
    Input.define_singleton_method(:update__access_orig, inner)
    PokeAccess::Battle.battle_ended
    $scene = old_scene
    $GameSpeed = nil
    Object.send(:remove_const, :SPEEDUP_STAGES) if !had_stages && Object.const_defined?(:SPEEDUP_STAGES)
  end
end
