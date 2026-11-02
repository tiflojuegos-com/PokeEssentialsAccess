# Pokémon HGSS: Sevii Islands: the profile's name and its game-wide settings.
PokeAccess::Game.define("sevii") do
  # Its Kernel.pbSurf (0199_Following Pokémon.rb) refuses while anyone walks along as a dependent event, unless the
  # following Pokemon's switch is on.
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }

  # The card cyclePics shows before the title, its text only in the picture.
  picture_texts("intro1" => "Pokémon HGSS: Sevii Islands by PurpleZaffre. a Pokémon Fan Game")

  # Its speed-up runs while Shift is held (0194_Speed Up.rb), which is the mod's modifier: it goes on Alt.
  remap_extra(:sv_speed, 0x10, :sv_key_shift)
  key_defaults(:sv_speed => "Alt")
end
