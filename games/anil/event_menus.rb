module PokeAccess
  # Anil's new-game flow uses event-scripted picture menus (no window, no text); the focused option shows
  # a "...Sel" picture. The spoken names come from the CONFIRMATION pages of Map104's event 2, not from
  # the filenames: MenuCompSel arms switch 110 ("Modo Completo"), MenuRandSel switch 111 ("Modo Radical").
end

# The new-game character slider (map 1, event 4) swaps ONE picture between three portraits as the player
# moves, and calls pbChangePlayer only on confirm -- so the picture name is the only signal while choosing,
# and the generic reader cannot supply it: Appearance.on_picture is gated on $PokemonGlobal.playerID, which
# this game (v21-shaped, character_ID) does not keep, and its number => gender table is a guess that this
# game would not fit anyway. Named here instead, which is what picture_texts is for.
#
# The third portrait is the character Yellow, not a gender: its trainer type is POKEMONTRAINER_Yellow and
# picking it jumps straight past the "what do you look like" question the other two ask. Spoken by the name
# the game gives it, the same in every language.
PokeAccess::Game.define("anil") do
  picture_texts(
    "introGirl" => :ap_girl,
    "introBoy" => :ap_boy,
    "introYellow" => "Yellow",
    "MenuClasSel" => :ev_mode_classic,
    "MenuCompSel" => :ev_mode_complete,
    "MenuRandSel" => :ev_mode_radical
  )
end
