# Fuchsia's gym (map 125): Koga's quiz on the Ninja Creed (event 39, in front of him) asks three questions whose
# answers are the three books of the gym (events 1 to 3); each right one adds to V181, and each one missed poisons a
# Pokemon before the battle. The books are named until Koga is beaten (S192); the assist says each right answer.
PokeAccess::Game.define("anil") do
  mechanic(:state, 125) do
    auto
    name [1, 2, 3], :anil_creed_book, :when => lambda { |_ev| !$game_switches[192] }
    right_choice 39, :takes => { :var => 181 }
  end
end
