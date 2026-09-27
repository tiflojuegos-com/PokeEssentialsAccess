# The credits roll: the text the scene draws (get_text from v19, CREDIT on the classic scene), read once and queued
# on the roll's first frame, after the scene has filled in its placeholders.
class Scene_Credits
  CREDIT = "Mi Juego\n\n{INSERTS_PLUGIN_CREDITS_DO_NOT_REMOVE}\nGracias por jugar\n"
  def main
    CREDIT.gsub!(/\{INSERTS_PLUGIN_CREDITS_DO_NOT_REMOVE\}/, "Plugin X por:\nAna<s>Luis")
    3.times { update }
    :rolled
  end
  def update; end
end
verbose = $VERBOSE
begin
  $VERBOSE = nil
  load File.expand_path("../../../core/menus/credits.rb", File.dirname(__FILE__))
ensure
  $VERBOSE = verbose
end

Suite.define("credits: the roll is read once, on its first frame, from the finished text") do
  eq "the roll keeps its own return", Scene_Credits.new.main, :rolled
  eq "every line, the placeholder already filled, spacers dropped, the two columns joined, once",
     SpeakCapture.log, [["Mi Juego. Plugin X por: Ana, Luis. Gracias por jugar.", false]]
end

# Infinite Fusion's Hoenn build has neither get_text nor CREDIT: its scene keeps one text per region,
# CREDIT_KANTO and CREDIT_HOENN, and main picks one by Settings::KANTO.
class IFHoennCreditsStub
  CREDIT_KANTO = "Fusion Kanto\n"
  CREDIT_HOENN = "<title>Fusion Hoenn\nAna<s>Luis\n"
end

Suite.define("credits: Infinite Fusion's Hoenn build is read from the text of the region being played") do
  made = !Object.const_defined?(:Settings)
  Object.const_set(:Settings, Module.new) if made
  had = Settings.const_defined?(:KANTO)
  prev = had ? Settings::KANTO : nil
  begin
    Settings.send(:remove_const, :KANTO) if had
    Settings.const_set(:KANTO, false)
    eq "the Hoenn text, its title tag gone and its two columns joined",
       PokeAccess::Credits.lines(IFHoennCreditsStub.new), ["Fusion Hoenn", "Ana, Luis"]
    Settings.send(:remove_const, :KANTO)
    Settings.const_set(:KANTO, true)
    eq "and the Kanto one when that is the region", PokeAccess::Credits.lines(IFHoennCreditsStub.new), ["Fusion Kanto"]
  ensure
    Settings.send(:remove_const, :KANTO) if Settings.const_defined?(:KANTO)
    Settings.const_set(:KANTO, prev) if had
    Object.send(:remove_const, :Settings) if made
  end
end

# The roll is read as one long line, so its end (or skipping it) stops the reading.
Suite.define("credits: the reading stops when the roll is over") do
  stops = []
  original = PokeAccess.method(:stop_speech)
  PokeAccess.define_singleton_method(:stop_speech) { stops.push(:stop); true }
  begin
    Scene_Credits.new.main
    eq "the roll's end stops what is still being read of it", stops, [:stop]
    stops.clear
    PokeAccess::Credits.finish
    eq "and a second end has nothing to stop", stops, []
  ensure
    PokeAccess.define_singleton_method(:stop_speech, original)
  end
end
