# Royal's two rhythm-ish minigames. They looked alike from outside but are not the same problem, and reading
# the code changed the approach for one of them.
#
# JumpMinigame (the skipping rope) is NOT a timing game: setButton rolls a SEQUENCE of directions into
# @button and you have to reproduce it, with @pos tracking how far you are. That is ordinary information, so
# it is spoken -- the whole sequence when a new one is dealt, and nothing per keypress (the game already
# plays its own hit/miss sound, and narrating each step would run behind the player).
#
# JuegoRitmo (the curry rhythm game) IS timing: notes travel toward a selector. Rather than guess the exact
# hit geometry, the reader announces the DIRECTION of the note that is coming next, once per note. Combined
# with the game's own music the player can anticipate the beat, and it never claims a precision the reader
# cannot actually verify from the sprite positions.
module PokeAccess
  module RoyalRhythm
    DIRS = [:roy_up, :roy_down, :roy_left, :roy_right]

    # The spoken name of a direction index, or the raw value when a game uses something else.
    def self.dir_name(v)
      key = DIRS[v.to_i]
      key ? PokeAccess::I18n.t(key) : v.to_s
    end

    # Speaks the whole rope sequence when a new one is dealt.
    def self.sequence(scene)
      seq = PokeAccess.ivar(scene, :@button)
      return unless seq.is_a?(Array) && !seq.empty?
      sig = seq.join(",")
      return if PokeAccess.ivar(scene, :@pa_seq) == sig
      scene.instance_variable_set(:@pa_seq, sig)
      PokeAccess.speak(seq.map { |d| dir_name(d) }.join(", "), true)
    rescue StandardError
      nil
    end

    # Announces the next note's direction once per note, so the beat can be anticipated by ear.
    def self.next_note(scene)
      notes = PokeAccess.ivar(scene, :@notes)
      return unless notes.is_a?(Array)
      nxt = notes.first
      return if nxt.nil?
      v = (nxt.note rescue nil)
      return if v.nil?
      sig = [notes.length, v]
      return if PokeAccess.ivar(scene, :@pa_note) == sig
      scene.instance_variable_set(:@pa_note, sig)
      PokeAccess.speak(dir_name(v), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  after("JumpMinigame::Play", :setButton) { |s, _r, _a| PokeAccess::RoyalRhythm.sequence(s) }
  after("JuegoRitmo_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::RoyalRhythm.next_note(s) }
end
