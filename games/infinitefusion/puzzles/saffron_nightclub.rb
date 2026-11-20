# Saffron Nightclub's dance battle (map 114): the dancer (event 7, the Copycat girl, whose own name is the game's quest
# mark) turns through a sequence and the player copies it on the four floor tiles around the central one (event 10):
# below (11), right (12), left (13) and above (14), each adding a letter to
# variable 104, going back to the central tile between two. Variable 105 is the round: down, left, down, left; then up, left,
# down, left, down; then left, right, down, right, down. A wrong sequence is only judged at its length, and starts over from round
# one. The last round ends the quest (switch 938). The dancer's turns are told as the game shows them, at its "Got it?".
PokeAccess::Game.define("infinitefusion") do
  rounds = [
    [:down, :left, :down, :left],
    [:up, :left, :down, :left, :down],
    [:left, :right, :down, :right, :down]
  ]
  current = lambda { [[$game_variables[105].to_i, 0].max, rounds.length - 1].min }
  moves = lambda do |round|
    rounds[round].map { |facing| PokeAccess::I18n.t("ifq_face_#{facing}".to_sym) }.join(", ")
  end
  advice = lambda do
    round = current.call
    [:ifq_dance_hint, { :round => round + 1, :moves => moves.call(round) }]
  end
  shown = lambda { [:ifq_dance_shown, { :moves => moves.call(current.call) }] }

  mechanic(:state, 114) do
    auto
    name 7, :ifq_dance_copycat
    name 10, :ifq_dance_center
    name 11, :ifq_dance_tile_down
    name 12, :ifq_dance_tile_right
    name 13, :ifq_dance_tile_left
    name 14, :ifq_dance_tile_up
    solved(nil, :quiet => true) { $game_switches[938] }
    on_reach 10, { :text => /Got it/ }, shown
    active { $game_switches[932] }
    hint advice
  end
end
