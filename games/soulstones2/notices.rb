# Two more modal panels of the shape core/menus/modal_panel.rb describes, both this game's own: the eight
# once-only tutorials (pbTutorialWindow) and the Achievement Points scoreboard after a boss
# (pbBottomRightWindow). Neither goes through pbMessage, and both block, so they are read on the way in.
PokeAccess::ModalPanel.watch("pbTutorialWindow")
PokeAccess::ModalPanel.watch("pbBottomRightWindow")
