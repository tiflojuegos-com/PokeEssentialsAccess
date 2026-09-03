module PokeAccess
  # Anil's new-game flow uses event-scripted picture menus (no window, no text); the focused option shows
  # a "...Sel" picture. The spoken names come from the CONFIRMATION pages of Map104's event 2, not from
  # the filenames: MenuCompSel arms switch 110 ("Modo Completo"), MenuRandSel switch 111 ("Modo Radical").
end

PokeAccess::Game.define("anil") do
  picture_texts(
    "MenuClasSel" => :ev_mode_classic,
    "MenuCompSel" => :ev_mode_complete,
    "MenuRandSel" => :ev_mode_radical
  )
end
