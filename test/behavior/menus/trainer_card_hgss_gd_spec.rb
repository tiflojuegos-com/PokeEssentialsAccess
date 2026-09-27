# Mr. Gela's HGSS card: each face as painted, the back interrupting; its badge icons add no second count, and the
# front starts with the stars its picture shows.

Suite.define("hgss trainer card: each face as painted, its own badge count, and the turn interrupting") do
  card = PokemonTrainerCard_Scene.new
  card.pbStartScene
  card.pbDrawTrainerCardBack
  eq "the front queued, the back interrupting, neither with an icon line", SpeakCapture.log,
     [["NOMBRE Rojo. MEDALLAS 2. Pulsa [D] para girar la tarjeta.", false],
      ["DEBUT HALL DE LA FAMA. Combates Online 4", true]]
end

Suite.define("hgss trainer card: the front starts with the stars the card's picture shows") do
  card = PokemonTrainerCard_Scene.new
  meta = (class << $player; self; end)
  meta.send(:define_method, :stars) { 2 }
  begin
    SpeakCapture.clear
    card.pbStartScene
    eq "the stars first, where the card draws them, then the card as painted", SpeakCapture.lines,
       ["#{PokeAccess::I18n.t(:stars_count, :n => 2)}. NOMBRE Rojo. MEDALLAS 2. Pulsa [D] para girar la tarjeta."]
    SpeakCapture.clear
    card.pbDrawTrainerCardBack
    eq "and the back, whose picture shows them too, says only what it paints", SpeakCapture.lines,
       ["DEBUT HALL DE LA FAMA. Combates Online 4"]
  ensure
    meta.send(:remove_method, :stars)
  end
end
