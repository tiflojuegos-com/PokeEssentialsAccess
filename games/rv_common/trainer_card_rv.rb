module PokeAccess
  # The trainer card of the engine Reborn and Rejuvenation share: past what the front paints, the game's own reader says
  # the level cap its badges set (LEVELCAPS, raised by the Extended_Max_Level variable), said here after the front.
  # Bound only where the game has that reader (the global tts): Desolation keeps LEVELCAPS, but its card neither paints
  # the cap nor says it.
  module TrainerCardRV
    # The level cap the game says for the badges held, or nil where the engine keeps no LEVELCAPS or the card is not the
    # player's own.
    def self.level_cap
      return nil unless defined?(LEVELCAPS) && $Trainer
      return nil if ($game_switches[:NotPlayerCharacter] rescue false)
      cap = LEVELCAPS[$Trainer.numbadges]
      return nil unless cap
      [cap, 100 + ($game_variables[:Extended_Max_Level] rescue nil).to_i].min
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the level cap after the card's front, queued behind it.
    def self.bind
      PokeAccess::Hooks.override("PokeAccess::TrainerCard", :read_face, :tag => "rv_common") do |_mod, original, args|
        ret = original.call
        cap = args[1] ? PokeAccess::TrainerCardRV.level_cap : nil
        PokeAccess.speak(PokeAccess::I18n.t(:rv_level_cap, :n => cap), false) if cap
        ret
      end
    end
  end
end

PokeAccess::TrainerCardRV.bind if PokeAccess::DataRV.engine? && Object.private_method_defined?(:tts)
