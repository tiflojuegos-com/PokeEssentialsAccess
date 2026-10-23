# Reborn's Blindstep mode (the "blindstep" password, switch 2226) plays its own footsteps, wall echoes and a cue for the
# event ahead (Scripts/Reborn/Blindstep.rb), the same three the mod's positional audio plays: with both sounding, the
# mod says once per session which options mute either set.
module PokeAccess
  module RebornBlindstep
    # True while Blindstep is on and still sounds: its master volume and one of its three sets above zero.
    def self.game_sounding?
      return false unless ($game_switches[:Blindstep] rescue false)
      s = $Settings
      return false if (s.accessibilityVolume rescue 0).to_i <= 0
      [(s.footstepVolume rescue 0), (s.wallVolume rescue 0), (s.eventVolume rescue 0)].any? { |v| v.to_i > 0 }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True while the mod's own footsteps, walls or event guide sound: steps and walls at their families' volume, which
    # is 0 with the family switched off in Sounds on.
    def self.mod_sounding?
      c = PokeAccess::Config
      return false if c.sound_nav == :off || c.audio3d_volume.to_i <= 0
      mixer = PokeAccess::Sound::Mixer
      [mixer.volume(:step), mixer.volume(:wall), c.event_volume].any? { |v| v.to_i > 0 }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # Says it once per session, and only when both sets would really play.
    def self.warn_once
      return if @warned
      return unless game_sounding? && mod_sounding?
      @warned = true
      PokeAccess.speak(PokeAccess::I18n.t(:reb_blindstep_overlap), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Forgets the notice, so a spec can drive it again.
    def self.forget; @warned = false; end
  end
end

# After the first map's name, so the notice follows it.
PokeAccess::Events.on(:map_named) { PokeAccess::RebornBlindstep.warn_once }

# With Blindstep on, the game leaves every random walker where it stands (Game_Character#update: move_type 1 moves
# unless the switch is on), so the routes take one for the wall it is instead of waiting for it to step aside.
PokeAccess::Hooks.override(PokeAccess::World::Events, :mover?, :tag => "reborn_blindstep") do |_mod, original, args|
  page = args[0].page
  next false if page && (page.move_type rescue 0) == 1 && ($game_switches[:Blindstep] rescue false)
  original.call
end
