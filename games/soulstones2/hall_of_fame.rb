# Soulstones 2's hall of fame viewer on the PC: Action switches between the summary (writeWelcome) and the member
# panel (writePokemonData), both read by core, which says each once. A switch of view frees the slot of the view it
# goes to, so coming back to one reads it again. Each viewing is a new scene, so the view starts unset.
PokeAccess::Game.define("soulstones2") do
  before("HallOfFame_Scene", :writeWelcome, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :hof_welcome) if PokeAccess::Cursor.changed?(scene, :ss2_hof_view, :summary)
  end

  before("HallOfFame_Scene", :writePokemonData, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :hof_pk) if PokeAccess::Cursor.changed?(scene, :ss2_hof_view, :panel)
  end
end
