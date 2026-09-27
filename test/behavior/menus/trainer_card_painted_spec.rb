# The trainer card read as it paints itself: each card writes its own rows, and its badges are icons, counted as
# it draws them, which in a game of several regions is the region's own count, not the global one.

Suite.define("trainer card: its rows as painted, then the badges its icons show") do
  t = PokeAccess::I18n
  PokemonTrainerCardScene.new(2).pbStartScene
  eq "the rows in reading order, the badge icons after them, queued", SpeakCapture.log,
     [[["Nombre Rojo N° ID 01234", "Dinero $3000", t.t(:tr_badges, :n => 2)].join(". "), false]]
  SpeakCapture.clear
  PokemonTrainerCardScene.new(0).pbStartScene
  eq "no badges drawn, no badge line", SpeakCapture.lines, ["Nombre Rojo N° ID 01234. Dinero $3000"]
end
