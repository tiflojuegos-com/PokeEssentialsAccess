# Soulstones 2's own blocking panels, read on the way in (ModalPanel): the tutorials (pbTutorialWindow) and the
# Achievement Points scoreboard after a boss (pbBottomRightWindow).
PokeAccess::ModalPanel.watch("pbTutorialWindow")
PokeAccess::ModalPanel.watch("pbBottomRightWindow")

# Soulstones 2 keeps RPG Maker XP's default keys, which its hints name (the EV allocator's "[S] resets EVs").
PokeAccess::Game.define("soulstones2") do
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
end
