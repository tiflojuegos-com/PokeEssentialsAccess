# Essentials Deluxe's midbattle speech (Battle::Scene#pbUpdateNameWindow; Grueling Gold, and Soulstones 2's edited copy,
# which fills the window the same way): a scripted battle line shows who says it in a name window over the message, so
# while that window shows, its name leads the next line said.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateNameWindow, :optional => true) do |scene, _ret, _args|
  PokeAccess.lead_with_name_window(PokeAccess.sprite(scene, "nameWindow"))
end
