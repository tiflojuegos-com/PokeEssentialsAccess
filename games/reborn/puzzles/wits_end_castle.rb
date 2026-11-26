# Castle at Wit's End (map 698): Trainer(n) knights watch the halls, and a guarded spot passed or a knight leaving its
# post drops an impasse (events 9 to 11, 42, 43, 75, 76, 92). The doors lead on by variable 362: below 1 from Lin's room
# by (24, 25), then 46 and 47, 52 and 53; from 1 by (30, 31), then 48 and 49, 50 and 51; both end in HALL.
module PokeAccess
  module RebornWitsEnd
    MAP = 698
    WAYS = { false => [24, 25, 46, 47, 52, 53], true => [30, 31, 48, 49, 50, 51] }
    LOCKED = { false => [28, 29, 30, 31, 64, 65], true => [24, 25, 26, 27, 28, 29, 62, 63] }
    IMPASSES = [9, 10, 11, 42, 43, 75, 76, 92, 97, 98]
    JUMP = 79
    HALL = [31, 40, 82, 87]

    # True on the way the right doors open: variable 362 from 1.
    def self.right?; $game_variables[362].to_i >= 1; end

    # True in the hall Lin's knight watches, the last of both ways.
    def self.in_hall?
      $game_player.x.between?(HALL[0], HALL[1]) && $game_player.y.between?(HALL[2], HALL[3])
    end

    # A door's name: shut, or with the assist on the way on; nil leaves it its own.
    def self.door(ev)
      return :rbc_castle_door_locked if LOCKED[right?].include?(ev.id)
      return :rbc_castle_door_way if PokeAccess::Puzzles.assist? && WAYS[right?].include?(ev.id)
      nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  castle = PokeAccess::RebornWitsEnd
  watchers(castle::MAP)
  mechanic(:state, castle::MAP, :part => :doors) do
    auto
    name([castle::WAYS, castle::LOCKED].map { |h| h.values }.flatten.uniq, lambda { |ev| castle.door(ev) },
         :grouped => true)
    name castle::IMPASSES, :rbc_castle_impasse
    name castle::JUMP, :rbc_castle_jump
    hint lambda { castle.right? ? :rbc_castle_hint_right : :rbc_castle_hint_left }
    active { PokeAccess::Puzzles.assist? && !castle.in_hall? }
  end
end
