# Peridot Gym (map 78): four Voltorb (events 26, 28, 29 and 30) follow the player once talked to, setting variable 54 to
# 1, 3, 5 or 7; the action button on the bottom row of a closed gate with one following blows it and adds one. The gates
# open at 2, 4, 6 and 8. On map 37 three spriteless tiles press a secret switch, 2242, that opens every gate.
module PokeAccess
  module RebornPeridotGym
    VOLTORBS = [26, 28, 29, 30]
    GATES = { 20 => [2, 7, 6], 15 => [23, 17, 11], 11 => [24, 18, 12], 7 => [25, 19, 13] }
    OPENS = { 20 => 2, 15 => 4, 11 => 6, 7 => 8 }
    SECRET = [154, 161, 165]
    SECRET_SWITCH = 2242

    # Variable 54: odd while a Voltorb follows, gates blown so far times two.
    def self.count; $game_variables[54].to_i; end

    # True while a Voltorb follows the player.
    def self.following?; count % 2 == 1; end

    # True once every gate is open, by the Voltorb or the secret switch.
    def self.open?; count >= 8 || $game_switches[SECRET_SWITCH]; end

    # True for a gate tile of the bottom row whose gate is still closed.
    def self.closed?(ev)
      row = GATES.keys.find { |r| GATES[r].include?(ev.id) }
      !row.nil? && count < OPENS[row] && !$game_switches[SECRET_SWITCH]
    end

    # With the assist, what to do next: blow the nearest closed gate with the Voltorb that follows, or fetch the next.
    def self.hint
      return nil if open?
      following? ? :rba_pg_hint_gate : :rba_pg_hint_voltorb
    end
  end
end

PokeAccess::Game.define("reborn") do
  gym = PokeAccess::RebornPeridotGym
  mechanic(:state, 78) do
    auto
    name gym::VOLTORBS, :rba_pg_voltorb
    name gym::GATES.values.flatten, :rba_pg_gate, :grouped => true, :when => lambda { |ev| gym.closed?(ev) }
    watch :var => 54, :say => lambda { gym.following? ? :rba_pg_following : nil }
    hint lambda { gym.hint }
    active { !gym.open? }
    solved { gym.open? }
  end
  mechanic(:state, 37, :part => :rba_peridot_secret) do
    auto
    name gym::SECRET, :rba_pg_secret, :assist => true, :grouped => true,
                      :when => lambda { |_ev| !$game_switches[gym::SECRET_SWITCH] && !gym.open? }
    right_choice gym::SECRET, :takes => { :switch => gym::SECRET_SWITCH }
  end
end
