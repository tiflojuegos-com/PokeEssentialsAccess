# Pokemon Opalo v2.11 constants: only its key hints. It names the profile, being the first Game.define its
# modules run (the next, iv_stars, is shared with Pokemon Z under its own name).
PokeAccess::Game.define("opalo") do
  # Key hints for the letters Opalo's Input maps to one button each: R and Y are anthem keys, A is bound to two.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "D" => :z
end

module PokeAccess
  module Config
  end
end
