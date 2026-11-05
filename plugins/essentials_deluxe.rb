# Essentials Deluxe's midbattle speech and its fight menu (Battle::Scene#pbUpdateNameWindow; Grueling Gold, Keishou, Ashen
# Frost, and Soulstones 2's edited copy). A scripted battle line shows who says it in a name window over the message, so
# while that window shows, its name leads the next line said.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateNameWindow, :optional => true) do |scene, _ret, _args|
  PokeAccess.lead_with_name_window(PokeAccess.sprite(scene, "nameWindow"))
end

# Its pbFightMenu takes one flag per mechanic, so the menu's second argument names none: the mechanic behind the button
# is the one this picks. Mega Evolution is what the button says with none noted.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbFightMenu_BattleMechanic, :optional => true) do |_scene, mechanic, _args|
  PokeAccess::Battle.note_special_action(mechanic == :mega ? nil : mechanic)
end

# Core leaves the button to the Deluxe Battle Kit's pbToggleSpecialActions where the kit is installed, but this plugin's
# menu, loaded after it in Grueling Gold, replaces the kit's and never calls that.
if PokeAccess::Engine.has?("Battle#pbToggleSpecialActions")
  PokeAccess::Hooks.after_hook("Battle::Scene::MenuBase", :mode=, :optional => true) do |menu, _ret, args|
    PokeAccess::BattleScene.mechanic_mode(menu, args[0])
  end
end
