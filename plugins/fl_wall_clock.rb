module PokeAccess
  # FL's Wall Clock (WallClockScene): an analog clock, two hands and an AM/PM sign with no text; the time its hands
  # show is said as it opens and kept on the info key while it stays open.
  module WallClock
    # The time an update of the hands shows, as hours and minutes.
    def self.time_text(time)
      return nil unless time.respond_to?(:hour) && time.respond_to?(:min)
      format("%02d:%02d", time.hour, time.min)
    end

    # Each update of the hands (on opening, then every few seconds): said the first time, on the info key always.
    def self.updated(scene, time)
      t = time_text(time)
      return unless t
      first = PokeAccess::Cursor.changed?(scene, :wall_clock_open, true)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false) if first
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("WallClockScene", :update_clock, :optional => true) do |scene, _r, args|
  PokeAccess::WallClock.updated(scene, args[0])
end
