# Insurgence's quick save (V, Scene_Map#update): a success only shows the "save" picture, a floppy disk with a green
# tick, for 30 frames; an observer says it, so the map is not taken for a picture menu meanwhile.
PokeAccess::Game.define("insurgence") do
  on_picture { |name, _args| PokeAccess.speak(PokeAccess::I18n.t(:ins_quick_saved), true) if name == "save" }
end
