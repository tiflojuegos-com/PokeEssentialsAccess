# Pokemon Opalo v2.11 constants: its key hints and its Surf's rule on company. It names the profile, being the first
# Game.define its modules run (the next, iv_stars, is shared with Pokemon Z under its own name).
PokeAccess::Game.define("opalo") do
  # Key hints for the letters Opalo's Input maps to one button each: R and Y are anthem keys, A is bound to two.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "D" => :z

  # Its Kernel.pbSurf (189_Following.rb) refuses while anyone walks along as a dependent event, unless the following
  # Pokemon's switch is on.
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }
end

module PokeAccess
  module Config
  end
end
