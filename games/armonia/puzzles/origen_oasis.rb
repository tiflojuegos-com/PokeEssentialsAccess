# The old man's pots at Oasis Origen (map 24, event 1): three Padwig pots (events 2 to 4) shuffled by move routes written in his
# page, with no chance in them. The middle one, event 2, goes left, right, right, left and left, and ends on the left. Its path is
# said as the shuffle starts, right after the page's eleventh message; with the assist, the option that wins rather than sends
# the player away.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 24) do
    auto
    on_reach 1, { :text => 10 }, :arm_oasis_shuffle
    right_choice 1, :takes => { :self => "C" }, :avoids => :transfer
  end
end
