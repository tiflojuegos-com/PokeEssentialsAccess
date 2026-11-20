# Moonlit Forest's dream of counting sheep (map 824): entering the meadow draws the Mareep (variable 278, 12 to 16, events 13
# to 28 each drawn from its place in the count, two of them shiny and so Flaaffy coloured) and the Flaaffy (variable 284, 2 to 6,
# events 33 to 35 and 44 to 46). Event 36 asks for the Mareep, then event 32 for the Mareep and the Flaaffy; a wrong number
# draws both again. The answers are the variables.
PokeAccess::Game.define("infinitefusion") do
  wanted = lambda do |ev|
    flaaffy = ev.id == 32 && $game_self_switches[[824, 32, "A"]]
    value = $game_variables[flaaffy ? 284 : 278].to_i
    value > 0 ? [:puzzle_answer, { :a => value.to_s }] : ""
  end

  species = lambda { |number| PokeAccess::Data.species_name(number) rescue nil }

  mechanic(:state, 824) do
    auto
    name(/^179/, lambda { |_ev| species.call(179) })
    name(/^180/, lambda { |_ev| species.call(180) })
    on_use [32, 36], wanted, :assist => true
    solved(nil, :quiet => true) { $game_switches[1030] }
  end
end
