# Fire Ash drops the game speed to normal inside pbFishing and restores it after: the speed announcer says neither.

# Stub of the game's pbFishing: lowers the speed, runs a frame, restores it.
def pbFishing(_has_encounter, _rod = 1)
  saved = $GameSpeed
  $GameSpeed = 1
  PokeAccess::Turbo.tick
  $GameSpeed = saved
  PokeAccess::Turbo.tick
  true
end

require File.expand_path("../../../games/fireash/fishing_speed", File.dirname(__FILE__))

Suite.define("fire ash: a cast of the rod does not say the speed it lowers and restores") do
  t = PokeAccess::Turbo
  old_scene = $scene
  $game_player ||= Object.new
  begin
    Object.const_set(:SPEED_SETTING_FILE, "Save Files/GameSpeedSetting.dat")
    $scene = Scene_Map.new
    $GameSpeed = 3
    t.tick
    SpeakCapture.clear
    eq "the fishing routine returns what the game returns", pbFishing(true), true
    t.tick
    silent "neither the drop to normal nor the restore is announced"
    $GameSpeed = 1
    t.tick
    eq "a real press afterwards is", SpeakCapture.lines, [PokeAccess::I18n.t(:turbo_speed, :n => 1)]
  ensure
    Object.send(:remove_const, :SPEED_SETTING_FILE) if Object.const_defined?(:SPEED_SETTING_FILE)
    $scene = old_scene
    $GameSpeed = nil
  end
end
