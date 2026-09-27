# Pokemon Royal profile, on La Base de Sky (modern Essentials with the DBK, LBDS and MUI plugins) and the core's v21
# readers; its Deluxe Battle Kit is read by the dbk plugin readers its manifest declares.

# Arcky's Region Map ships Quick Fly (a list of the visited places by name), so the mod's own fly jump is off here.
PokeAccess::TownMap.jump_enabled = false

# Royal's bordered confirm has the (helpwindow, msg, ...) shape of the UIHelper prompts core reads.
PokeAccess::UIHelperWrap.wrap(["pbConfirmBorde"])
