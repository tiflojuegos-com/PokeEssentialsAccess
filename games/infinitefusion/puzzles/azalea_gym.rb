# Azalea Gym (map 337): eight silent webs, each adding its own letter to the entered code (var 5); the code to match is var
# 136, a prefix of var 138 shuffled on entering: 3 letters, then 5 once a thick web is cut. Two completed rounds (var 135 at 2)
# open the way to Kurt. The game only chimes on a hit, so the letters, the totals and the order are the assist's. The events'
# names repeat letters, so the webs are named by the letter their own page writes.
PokeAccess::Game.define("infinitefusion") do
  letters = { 9 => "A", 14 => "B", 10 => "C", 15 => "D", 13 => "E", 16 => "F", 19 => "G", 17 => "H" }
  code = lambda { $game_variables[136].to_s }
  round = lambda { |size| lambda { code.call.length == size } }
  web = lambda do |letter|
    lambda { |_ev| PokeAccess::Puzzles.assist? ? [:if_jo_web, { :letter => letter }] : :if_jo_web_plain }
  end
  order = lambda { [:if_jo_azalea_order, { :order => code.call.split("").join(", ") }] }

  seen = 0
  entered = lambda do
    typed = $game_variables[5].to_s
    seen = [$game_variables[137].to_i, typed.length].min if code.call[0, typed.length] == typed
    seen
  end
  progress = lambda do |size|
    { :value => entered, :of => size, :label => :if_jo_webs, :announce => true, :reset => true, :assist => true }
  end

  mechanic(:state, 337) do
    auto
    letters.each { |id, letter| name id, web.call(letter) }
    arrival_hint :if_jo_azalea_rule
    solved { $game_variables[135].to_i >= 2 || $game_switches[39] }
    phase round.call(3), :quiet => true, :hint => order, :progress => progress.call(3)
    phase round.call(5), :hint => order, :progress => progress.call(5)
  end
end
