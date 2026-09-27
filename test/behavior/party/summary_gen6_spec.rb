# Cycling Pokemon inside the gen-6 summary: pbUpdate points the info key at the Pokemon shown.
Suite.define("summary gen-6: info key follows the shown Pokemon") do
  scene = World.summary_scene(:pokemon => Poke.build(:name => "Bulba", :species => 1))
  scene.pbUpdate
  info = PokeAccess::Info.info_text
  match "T reads the entered Pokemon", info, /Bulba/

  scene.pokemon = Poke.build(:name => "Char", :species => 4)
  scene.pbUpdate
  info2 = PokeAccess::Info.info_text
  match "T reads the NEW Pokemon after switching", info2, /Char/
  not_spoke_label = info2.to_s.include?("Bulba")
  eq "T no longer reads the old Pokemon", not_spoke_label, false
end

# Opening reads the data sheet: pbStartScene's original draws page one, whose after-hook must not be skipped as
# nested (the reentrancy guard sits on the after path only).
Suite.define("summary gen-6: opening the summary reads the data sheet") do
  scene = World.summary_scene(:pokemon => Poke.build(:name => "Bulba", :species => 1))
  SpeakCapture.clear
  scene.pbStartScene([Poke.build(:name => "Bulba", :species => 1)], 0)
  spoke "the full data sheet is read on open", /Bulba/
end

# The gen-6 memo page is read as its painted paragraph, a game's own ways of meeting a Pokemon included.
Suite.define("summary gen-6: the memo page is read as painted, a game's own ways of meeting included") do
  scene = PokemonSummaryScene.new(Poke.build(:name => "Nox"))
  scene.instance_variable_set(:@memo_paint,
    "<c3=484848,C8C8C8>Naturaleza<c3=EC0000,C8C8C8> Firme.\n<c3=EC0000,C8C8C8>Reino de las papeleras\n" \
    "<c3=484848,C8C8C8>Reclutado a nivel 20\ntras un intenso combate.")
  SpeakCapture.clear
  scene.drawPageTwo
  line = SpeakCapture.lines.join(" ")
  truthy "the painted place is read", line.include?("Reino de las papeleras.")
  truthy "and the game's own way of meeting", line.include?("Reclutado a nivel 20. tras un intenso combate.")
  falsy "with the colour codes gone", line.include?("<c3")
end
