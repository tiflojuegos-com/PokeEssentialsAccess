# Reborn's painted documents, both drawn by map events over a picture of the paper: the intro's train ticket, whose
# pbTicketText writes one field per call as the stationmaster fills it in, and the Pokedex certificate BEE hands the
# champion in Agate City, whose pbDexCert writes the name and the time on it.
PokeAccess::Game.define("reborn") do
  kernel("pbTicketText", :around) do |_args, nxt|
    PokeAccess::PaintCapture.speak_around(:reb_ticket, false) { nxt.call }
  end

  kernel("pbDexCert", :around) do |_args, nxt|
    r = nil
    rows = PokeAccess::PaintCapture.laid_out(PokeAccess::PaintCapture.sample { r = nxt.call })
    text = PokeAccess::PaintCapture.text(rows)
    PokeAccess.speak(PokeAccess::I18n.t(:reb_dex_cert, :rows => text), false) unless text.empty?
    r
  end
end
