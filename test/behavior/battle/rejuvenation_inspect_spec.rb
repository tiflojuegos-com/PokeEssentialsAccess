# Rejuvenation's Inspect report (games/rejuvenation/inspect.rb): the type and status rows it paints as icons are said
# with the types' names and the status's word, in the list and in the report on the info key, and Ctrl's team preview
# runs as a relayed screen of the game's own reader. The profile file is loaded once.
module RejuvInspectSpec
  TYPES = { :getTypeName => lambda { |t| { :FIRE => "Fire", :FLYING => "Flying" }[t].to_s } }
  Box = Struct.new(:text)

  def self.load_profile
    return if @loaded
    load File.expand_path("../../../games/rejuvenation/inspect.rb", File.dirname(__FILE__))
    @loaded = true
  end
end

class Window_AdvancedCommandPokemon_NoPageScroll < Window_AdvancedCommandPokemon; end

# The game's team preview: it hands tts the team; here it notes whether it ran as a relayed screen.
def ttsPartyPreview(_pkmnindex)
  $rj_inspect_relayed = PokeAccess::OwnVoiceRV.relaying?
end

Suite.define("rejuvenation inspect: the rows painted as icons say their types and statuses") do
  RejuvInspectSpec.load_profile
  t = PokeAccess::I18n
  GameFunctions.with(RejuvInspectSpec::TYPES) do
    rows = ["Typing: <icon=typeFIRE> <icon=typeFLYING>", "Next <img=Graphics/Pictures/Party/statusPOISON> Dmg: 6.3%",
            "<img=Graphics/Pictures/Party/statusSLEEP> Turns: 2", "Speed:  40  +1"]
    win = Window_AdvancedCommandPokemon_NoPageScroll.new(rows)
    eq "the types, named as a list", PokeAccess::Menus.focused_text(win), "Typing: Fire, Flying"
    win.index = 1
    eq "a status icon as the status's word", PokeAccess::Menus.focused_text(win), "Next #{t.t(:st_poison)} Dmg: 6.3%"
    win.index = 2
    eq "at the start of a row too", PokeAccess::Menus.focused_text(win), "#{t.t(:st_sleep)} Turns: 2"
    win.index = 3
    eq "a row with no icon as painted", PokeAccess::Menus.focused_text(win), "Speed: 40 +1"
    eq "the info key's whole report words them too", PokeAccess::InspectRV.report_text(RejuvInspectSpec::Box.new("Inspecting Talonflame:"), rows[0, 2]),
       "Inspecting Talonflame: Typing: Fire, Flying. Next #{t.t(:st_poison)} Dmg: 6.3%"
  end
end

Suite.define("rejuvenation inspect: Ctrl's team preview is the game's own line, relayed") do
  RejuvInspectSpec.load_profile
  v = PokeAccess::OwnVoiceRV
  was = v.instance_variable_get(:@active)
  begin
    v.instance_variable_set(:@active, true)
    $rj_inspect_relayed = nil
    ttsPartyPreview(1)
    truthy "the preview runs as a relayed screen, so what it hands tts is said", $rj_inspect_relayed
  ensure
    v.instance_variable_set(:@active, was)
  end
end
