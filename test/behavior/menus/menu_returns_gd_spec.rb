# Back on the options screen from a submenu, or on the Pokegear from an app, the focused row is said again; a submenu
# row is its name alone, and the last row the word the screen paints there.

Suite.define("options: the last row says the word the screen paints, a submenu row its name alone") do
  win = Window_PokemonOption.new([ButtonOption.new("System & Audio"), EnumOption.new("Text Speed", ["Slow", "Fast"])], "Confirm")
  win.refresh
  win.index = 2
  eq "the painted word of the last row", PokeAccess::Menus.focused_text(win), "Confirm"
  eq "a button row, no constant 0 after it", PokeAccess::Options.row(ButtonOption.new("Gameplay"), 0), "Gameplay"
  eq "a valued row keeps its value", PokeAccess::Options.row(EnumOption.new("Text Speed", ["Slow", "Fast"]), 1), "Text Speed: Fast"
  bare = Window_PokemonOption.new([])
  eq "a row not painted yet answers nothing, so the reader asks again", PokeAccess::Options.exit_label(bare), nil
  PokeAccess::Options.exit_label(bare)
  eq "and one still unpainted after that takes the generic word", PokeAccess::Options.exit_label(bare), PokeAccess::I18n.t(:sm_exit)
end

Suite.define("options: back from a submenu the focused row is said again") do
  win = Window_PokemonOption.new([ButtonOption.new("System & Audio"), ButtonOption.new("Gameplay")])
  win.update
  eq "the opening row", SpeakCapture.lines, ["System & Audio"]
  SpeakCapture.clear
  win.update
  eq "silent while nothing moves", SpeakCapture.lines, []
  PokemonOption_Scene.new.pbEndScene
  win.update
  win.update
  eq "the submenu closed: the row once more", SpeakCapture.lines, ["System & Audio"]
end

Suite.define("pokegear: back from an app the focused option is said again") do
  gear = PokemonPokegear_Scene.new(["Map", "Phone"])
  gear.pbStartScene
  gear.pbScene
  eq "the opening says the option once", SpeakCapture.lines, ["Map"]
  SpeakCapture.clear
  gear.pbScene
  eq "the loop entered again after an app says it again", SpeakCapture.lines, ["Map"]
end
