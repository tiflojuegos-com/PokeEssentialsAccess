# Load order for what Sky's base (La Base de Sky) and Skyflyer's games share (no .rb): the purple star
# (Graphics/UI/shiny_ur) Anil, Royal and World Frontier paint for a super shiny, the trainer sensor, the damage
# numbers, the animated species picture and the relearner's machine labels of Sky's base. Imported by Anil, Royal,
# World Frontier and Revival, loaded before each game's own modules; a module whose screen a game lacks binds nothing.
{
  :modules => %w[
    super_shiny
    trainer_sensor
    damage_numbers
    animated_pokemon
    relearner_labels
  ]
}
