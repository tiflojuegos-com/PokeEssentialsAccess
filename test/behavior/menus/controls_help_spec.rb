# The gen-6 controls help (controls_help_gd_spec.rb covers the modern one): one screen whose paragraphs the
# constructor passes to addLabel, read as the constructor finishes.
Suite.define("controls help: the gen-6 screen reads its paragraphs as the constructor finishes") do
  SpeakCapture.clear
  ButtonEventScene.new(["ALT - Turbo", "F - Textlog", "V - Saltar diálogos"])
  eq "every paragraph, in order, as one line",
     SpeakCapture.lines, ["ALT - Turbo. F - Textlog. V - Saltar diálogos"]
  truthy "interrupting, because the player pressed a key to get here", SpeakCapture.log.last[1]

  SpeakCapture.clear
  ButtonEventScene.new([])
  silent "a screen with no paragraph says nothing"
end

# The stock gen-6 screen (Soulstones, Z, Opalo...): each paragraph beside the picture of its key, which leads it, as
# the player has the key now.
Suite.define("controls help: the gen-6 screen says each paragraph after the key its picture shows") do
  t = PokeAccess::I18n
  labels = [["Moves the main character.", 26], ["Used to confirm a choice.", 106], ["Used to exit.", 186],
            ["Hold down while walking to run.", 266], ["Press to use a registered Key Item.", 314]]
  pictures = [[36, "Graphics/Pictures/helpArrowKeys"], [118, "Graphics/Pictures/helpCkey"],
              [198, "Graphics/Pictures/helpXkey"], [260, "Graphics/Pictures/helpZkey"],
              [308, "Graphics/Pictures/helpF5key"]]
  SpeakCapture.clear
  ButtonEventScene.new(labels, pictures)
  eq "the arrows, C, X, Z and F5, each before the paragraph at its height", SpeakCapture.lines,
     ["#{t.t(:ctl_arrows)}: Moves the main character. C: Used to confirm a choice. X: Used to exit. " \
      "Z: Hold down while walking to run. F5: Press to use a registered Key Item."]

  PokeAccess::Config.rebinds = { :c => 0x56 }
  eq "a button the player moved is said on its new key",
     PokeAccess::ControlsHelp.picture_key("Graphics/Pictures/helpCkey"), PokeAccess::ConfigMenu.keyname(0x56)
  PokeAccess::Config.rebinds = {}
  eq "Soulstones' F picture is the F key", PokeAccess::ControlsHelp.picture_key("Graphics/Pictures/helpFkey"), "F"
  falsy "and the background is no key", PokeAccess::ControlsHelp.picture_key("Graphics/Pictures/helpbg")
end
