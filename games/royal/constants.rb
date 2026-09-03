# Pokemon Royal profile: built on La Base de Sky (modern Essentials + DBK/LBDS/MUI plugins). Everything
# generic is covered by core (the v21 readers apply); this profile adds royal's own new-game selectors
# (selectors.rb). Combat uses the Deluxe Battle Kit, read by plugins/dbk_battle.rb and
# plugins/dbk_enhanced_ui.rb (declared in manifest.rb).

# Arcky's Region Map already ships Quick Fly: a button opens a list of the places you have VISITED, by
# name, and picking one places the cursor there (000_RegionMap_Main). Hearing where you are going
# before you go beats jumping blind in a direction, so the mod's own jump stands aside here -- adding it
# would put two ways to do the same thing on one screen, and the worse one would be ours.
PokeAccess::TownMap.jump_enabled = false

# Royal's bordered confirm has the (helpwindow, msg, ...) shape of the UIHelper prompts core reads.
PokeAccess::UIHelperWrap.wrap(["pbConfirmBorde"])
