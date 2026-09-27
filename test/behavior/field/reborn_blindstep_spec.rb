# Reborn's Blindstep mode (games/reborn/blindstep.rb): its footsteps, wall echoes and event cue are the mod's own three
# sets, so with both sounding the mod names, once per session, the options that mute either.
require File.expand_path("../../../games/reborn/blindstep", File.dirname(__FILE__))

module RebornBlindstepSpec
  Settings = Struct.new(:accessibilityVolume, :footstepVolume, :wallVolume, :eventVolume)
end

Suite.define("reborn: Blindstep's sounds and the mod's are named once when both play") do
  b = PokeAccess::RebornBlindstep
  had = $Settings
  $game_switches[:Blindstep] = true
  $Settings = RebornBlindstepSpec::Settings.new(100, 100, 100, 75)
  begin
    b.forget
    SpeakCapture.clear
    b.warn_once
    eq "both sets playing: the notice, queued", SpeakCapture.log, [[PokeAccess::I18n.t(:reb_blindstep_overlap), false]]
    SpeakCapture.clear
    b.warn_once
    silent "and only once per session"

    b.forget
    $Settings = RebornBlindstepSpec::Settings.new(100, 0, 0, 0)
    b.warn_once
    silent "Blindstep with its three sets at zero plays nothing to clash with"

    $Settings = RebornBlindstepSpec::Settings.new(100, 100, 100, 75)
    PokeAccess::Config.sound_nav = :off
    b.warn_once
    silent "the mod's sounds off: nothing to clash with either"

    PokeAccess::Config.sound_nav = :full
    $game_switches[:Blindstep] = false
    b.warn_once
    silent "and without the password there is no Blindstep"
  ensure
    $Settings = had
    b.forget
  end
end
