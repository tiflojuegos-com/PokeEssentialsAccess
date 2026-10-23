module PokeAccess
  module Sound
    # The flat channel (Audio.se_play): the sounds that never go through the positional engine, and the ones that stand
    # in for it while it is down, as files already panned (_l, _c, _r), at a pitch the engine takes (50 to 150).
    module Flat
      # Plays a file of the mod's sounds (no extension) at a 0-100 volume and a pitch; nothing at volume 0 or less.
      def self.play(file, vol, pitch = 100)
        return if vol.nil? || vol <= 0
        Audio.se_play("#{PokeAccess::Paths::SOUNDS}/#{file}", vol, pitch) rescue nil
      end

      # Stops what the flat channel plays.
      def self.stop
        Audio.se_stop rescue nil
      end
    end
  end
end
