# Pokémon HGSS: Sevii Islands: the profile's name and its game-wide settings.
PokeAccess::Game.define("sevii") do
  # Its Kernel.pbSurf (0199_Following Pokémon.rb) refuses while anyone walks along as a dependent event, unless the
  # following Pokemon's switch is on.
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }

  # The card cyclePics shows before the title, its text only in the picture.
  picture_texts("intro1" => "Pokémon HGSS: Sevii Islands by PurpleZaffre. a Pokémon Fan Game")
end
