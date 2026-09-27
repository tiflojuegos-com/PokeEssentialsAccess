# Pokemon Z 2.18 profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("pokemon_z") do
  # Per-game button relabels for the remap menu (Z maps X/Y/Z to its field actions); added to the core
  # defaults, never replacing them.
  button_labels :x => "Pokevial", :y => "PokeRider", :z => "DexNav"

  # Z keeps RPG Maker XP's default keys, so its hints paint those letters (the pause panel's "[A] Curar").
  key_hints PokeAccess::KeyHints::RGSS_LETTERS

  # The gym's beam barriers ("rayos" sprites), said as beams with the zap cue; rayosLegend is the legendary
  # encounters' graphic, not a barrier.
  hazard(/rayos(?!Legend)/i, :loc_beam)

  # The light in the Reflection Chambers, the portal back to the Luminalia palace, takes the teleporter cue.
  teleporter(/\Aluz\z/i)

  # Z's two statuses past the vanilla five (PBStatuses ids), capitalised here; the game writes them lowercase.
  names(:status_names, 6 => "Caduco", 7 => "Hemorragia")

  # Z surfs on a mount, never with a Pokemon's move: Kernel.pbSurf asks for the Montura Surf in the bag.
  field_move_item(:SURF, :SURFMONTURA)
end
