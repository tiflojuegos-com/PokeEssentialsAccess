# Africanvs's picture-only screens (games/africanus/pictures.rb) through PictureCues, as Game_Picture#show calls it:
# the character choice's portraits, the arm wrestling's keys and marker, the information bar, the credits and the
# Union of Amat's map.
require File.expand_path("../../../games/africanus/pictures", File.dirname(__FILE__))

AfrPicMap = Struct.new(:map_id)

Suite.define("africanus pictures: the character choice says which portrait is lit, by the question's names") do
  cues = PokeAccess::PictureCues
  cues.reset_last
  begin
    SpeakCapture.clear
    cues.on_picture("Protas", [])
    cues.on_picture("Protas1", [])
    eq "the pair shown, then Vir, the boy, lit", SpeakCapture.lines, ["Vir, chico"]
    cues.on_picture("Protas1", [])
    cues.on_picture("Protas2", [])
    eq "left held says nothing more, right lights Femina, the girl", SpeakCapture.lines, ["Vir, chico", "Femina, chica"]
  ensure
    cues.reset_last
  end
end

Suite.define("africanus pictures: the arm wrestling's key is said as the player has it bound, once per key") do
  pics = PokeAccess::AfricanusPictures
  was = PokeAccess::Config.rebinds
  pics.reset
  begin
    PokeAccess::Config.rebinds = {}
    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("Tecla1", [])
    PokeAccess::PictureCues.on_picture("Tecla1", [])
    eq "the letter the picture paints, cutting in, once while the event re-shows it", SpeakCapture.log, [["Z", true]]

    PokeAccess::Config.rebinds = { :y => 0x4B }
    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("Tecla2", [])
    eq "a button the player moved is said by its key", SpeakCapture.lines, ["K"]

    SpeakCapture.clear
    Game_Picture.new(5).erase
    PokeAccess::PictureCues.on_picture("Tecla2", [])
    eq "once the wrestling erases it, a rematch opening on the same key says it again", SpeakCapture.lines, ["K"]
  ensure
    PokeAccess::Config.rebinds = was
    pics.reset
  end
end

Suite.define("africanus pictures: the wrestling's marker ticks a full step at a time, and only while it runs") do
  pics = PokeAccess::AfricanusPictures
  ticks = []
  sc = (class << PokeAccess::Spatial; self; end)
  sc.send(:alias_method, :gauge_before_afr_spec, :gauge)
  sc.send(:define_method, :gauge) { |f, *_rest| ticks.push(f) }
  old_map = $game_map
  begin
    $game_map = AfrPicMap.new(59)
    $game_variables[92] = 232
    pics.pulse_poll
    eq "nothing while the wrestling is off", ticks, []

    $game_switches[289] = true
    pics.pulse_poll
    eq "on its start, where the marker sits", ticks.length, 1
    $game_variables[92] = 240
    pics.pulse_poll
    eq "a move short of a step stays quiet", ticks.length, 1
    $game_variables[92] = 251
    pics.pulse_poll
    eq "a full step toward the win ticks higher", [ticks.length, ticks.last > ticks.first], [2, true]

    $game_map = AfrPicMap.new(58)
    $game_variables[92] = 400
    pics.pulse_poll
    eq "the same switch on another map is not the wrestling", ticks.length, 2
  ensure
    sc.send(:alias_method, :gauge, :gauge_before_afr_spec)
    $game_map = old_map
    $game_switches[289] = false
    pics.pulse_poll
  end
end

Suite.define("africanus pictures: the information bar says its thirds, the credits their names, queued") do
  pics = PokeAccess::AfricanusPictures
  pics.reset
  begin
    SpeakCapture.clear
    3.times { PokeAccess::PictureCues.on_picture("informacion 1", []) }
    eq "the bar's painted label and its third, once while its event re-shows it", SpeakCapture.log,
       [["Información: 1 de 3", false]]
    PokeAccess::PictureCues.on_picture("informacion 2", [])
    eq "and again as it fills", SpeakCapture.lines.last, "Información: 2 de 3"

    SpeakCapture.clear
    PokeAccess::Caches.reset_all
    PokeAccess::PictureCues.on_picture("informacion 2", [])
    eq "a map entered anew says the bar it shows", SpeakCapture.lines, ["Información: 2 de 3"]

    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("Creditos3", [])
    PokeAccess::PictureCues.on_picture("CREDITOSFIN_eng", [])
    eq "each credits picture's names, waiting for the last to finish", SpeakCapture.log,
       [["Aveontrainer, Cero1533, ChaoticCherryCake, Ditto209", false], ["Game by El Camid", false]]
  ensure
    pics.reset
  end
end

# The map's places go through the game's own place tables, as its region map does: an English run names the quarry
# as english.dat does, and a point of interest is asked of the descriptions table.
Suite.define("africanus pictures: the Union's map says its seven marked places, and each cross the one it strikes out") do
  pics = PokeAccess::AfricanusPictures
  made = !MessageTypes.const_defined?(:PlaceDescriptions)
  MessageTypes.const_set(:PlaceDescriptions, 20) if made
  english = { [MessageTypes::PlaceNames, "Cantera de Slowpokes"] => "Slowpokes Quarry",
              [MessageTypes::PlaceDescriptions, "Útica"] => "Utica" }
  Object.send(:alias_method, :pbGetMessageFromHash_before_afr_spec, :pbGetMessageFromHash)
  Object.send(:define_method, :pbGetMessageFromHash) { |type, id| english[[type, id]] || id }
  pics.reset
  begin
    SpeakCapture.clear
    PokeAccess::PictureCues.on_picture("mapa con cultistas", [])
    PokeAccess::PictureCues.on_picture("Cruz1", [])
    PokeAccess::PictureCues.on_picture("Cruz7", [])
    eq "the seven marks in the order of their crosses, then each cross the event shows, all queued", SpeakCapture.log,
       [["Objetivos marcados en el mapa: Slowpokes Quarry, Iol, Tarraco, Pisae, Carales, Etna, Utica", false],
        ["Slowpokes Quarry, tachado", false], ["Utica, tachado", false]]
  ensure
    Object.send(:alias_method, :pbGetMessageFromHash, :pbGetMessageFromHash_before_afr_spec)
    Object.send(:remove_method, :pbGetMessageFromHash_before_afr_spec)
    MessageTypes.send(:remove_const, :PlaceDescriptions) if made
    pics.reset
  end
end
