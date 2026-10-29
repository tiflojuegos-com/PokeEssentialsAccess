# The Bug-Catching Contest's comparison, stock in every era (PokeBattle_Scene and Battle::Scene#pbShowHelp, called
# only by the contest battle's pbStorePokemon): catching a second Pokemon shows the one in stock and the new one, name,
# level and max HP, in a help window over the battle before the game asks whether to switch; said as it shows, queued
# between the catch's line and that question.
PokeAccess::Engine.scene_classes("PokeBattle_Scene", "Battle::Scene").each do |cn|
  PokeAccess::Hooks.before_hook(cn, :pbShowHelp, :optional => true) do |_scene, args|
    PokeAccess.say_info_box(args[0])
  end
end
