# Agate's gym (map 739): eight tuners (events 23 to 30) slide along their rows when pushed from the side, each push
# storing its place's note, 0 low G to 7 high G, in variables 441 to 448. Rock Climb at the strings (event 1) plays
# them, and the guitarist's riff 3 5 7 2 2 0 1 1 opens Hardy's door (switch 1022).
module PokeAccess
  module RebornAgateGym
    MAP = 739
    TUNERS = (23..30)
    FIRST_X = 14
    FIRST_VAR = 441
    NOTES = [:rbc_note_low_g, :rbc_note_a, :rbc_note_b, :rbc_note_c, :rbc_note_d, :rbc_note_e, :rbc_note_f,
             :rbc_note_high_g]
    RIFF = [3, 5, 7, 2, 2, 0, 1, 1]
    OPEN = 1022

    # A tuner's name, with the note its place on the row stands for.
    def self.label(ev)
      note = NOTES[ev.x - FIRST_X]
      return nil unless note && ev.x >= FIRST_X
      [:rbc_agate_tuner, { :n => ev.id - TUNERS.first + 1, :note => PokeAccess::I18n.t(note) }]
    end

    # With the assist, the first tuner to set off the riff, or the climb once all are set. A tuner in its place whose
    # stored note is stale, as after leaving the gym, needs a push and a push back.
    def self.hint
      TUNERS.each_with_index do |id, k|
        ev = $game_map.events[id]
        next unless ev
        want = RIFF[k]
        at = ev.x - FIRST_X
        next if at == want && $game_variables[k + FIRST_VAR].to_i == want
        note = PokeAccess::I18n.t(NOTES[want])
        return [:rbc_agate_resync, { :n => k + 1, :note => note }] if at == want
        key = want > at ? :rbc_agate_push_right : :rbc_agate_push_left
        return [key, { :n => k + 1, :count => (want - at).abs, :note => note }]
      end
      :rbc_agate_climb
    end
  end
end

PokeAccess::Game.define("reborn") do
  gym = PokeAccess::RebornAgateGym
  mechanic(:state, gym::MAP, :part => :tuners) do
    auto
    name gym::TUNERS, lambda { |ev| gym.label(ev) }
    name 1, :rbc_agate_strings
    hint lambda { gym.hint }
    active { !$game_switches[gym::OPEN] }
    solved { $game_switches[gym::OPEN] }
  end
end
