# Polectron's Ocarina (Flute, pbCallFlute; Ashen Frost): a melody played with the arrows, each note painted as a key picture and
# the whole judged once it is complete. The notes are said as they land; the question of leaving and the verdict are messages.
module PokeAccess
  module Ocarina
    KEYS = [[:UP, :dir_up], [:DOWN, :dir_down], [:LEFT, :dir_left], [:RIGHT, :dir_right]]
    @playing = false
    @notes = 0

    # Runs the melody's loop, the only stretch where an arrow is a note.
    def self.playing
      @playing = true
      @notes = 0
      hint = PokeAccess::I18n.t(:oca_leave, :key => PokeAccess::KeyHints.key(:b, "X"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:oca_open), hint), false)
      yield
    ensure
      @playing = false
    end

    # Says the arrow pressed this pulse with its place in the melody, unless a message has the keys.
    def self.poll
      return unless @playing && PokeAccess.message_depth.zero?
      KEYS.each do |name, word|
        next unless Input.trigger?(Input.const_get(name))
        @notes += 1
        PokeAccess.speak(PokeAccess::I18n.t(:oca_note, :n => @notes, :dir => PokeAccess::I18n.t(word)), true)
        break
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("Flute", :pbUpdate, :optional => true) do |_scene, nxt, _args|
  PokeAccess::Ocarina.playing { nxt.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::Ocarina.poll }
