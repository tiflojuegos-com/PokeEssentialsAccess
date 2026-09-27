# Infinite Fusion's speed-up key: in its default Hold mode each press cycles $GameSpeed, which that mode never uses,
# so nothing is said; in Toggle mode the index is the SPEEDUP_STAGES multiplier, said as in other games.
require File.expand_path("turbo_cases", File.dirname(__FILE__))

Suite.define("infinite fusion: the speed-up key says a multiplier only in Toggle mode") do
  t = PokeAccess::Turbo
  meta = (class << t; self; end)
  meta.send(:alias_method, :if_spec_current_speed, :current_speed)
  old_scene = $scene
  old_system = $PokemonSystem
  begin
    load File.expand_path("../../../games/infinitefusion_common/turbo_mode.rb", File.dirname(__FILE__))
    $scene = Scene_Map.new
    $PokemonSystem = Struct.new(:speedup).new(0)
    TurboCases.stages([1, 2, 3])
    $GameSpeed = 0
    TurboCases.reset
    SpeakCapture.clear
    t.tick
    [1, 2, 0].each { |n| $GameSpeed = n; t.tick }
    eq "in Hold mode the presses cycle an index the game ignores, and none is said", TurboCases.said, []

    $PokemonSystem.speedup = 1
    t.tick
    SpeakCapture.clear
    $GameSpeed = 1; t.tick
    $GameSpeed = 2; t.tick
    eq "in Toggle mode each press says the multiplier it sets",
       TurboCases.said, [PokeAccess::I18n.t(:turbo_speed, :n => 2), PokeAccess::I18n.t(:turbo_speed, :n => 3)]
  ensure
    meta.send(:alias_method, :current_speed, :if_spec_current_speed)
    meta.send(:remove_method, :if_spec_current_speed)
    TurboCases.stages(nil)
    $scene = old_scene
    $PokemonSystem = old_system
  end
end
