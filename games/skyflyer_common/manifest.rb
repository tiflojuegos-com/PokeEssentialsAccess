# Load order for what Skyflyer's games share (no .rb): the purple star (Graphics/UI/shiny_ur) that anil and royal
# paint for a super shiny in the party, the PC, the summary and the battle box, and the trainer sensor both edit.
# Imported by both, loaded before each game's own modules.
{
  :modules => %w[
    super_shiny
    trainer_sensor
  ]
}
