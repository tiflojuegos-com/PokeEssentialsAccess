# Pokemon Golden Crown: the profile's name and its game-wide settings.
PokeAccess::Game.define("goldencrown") do
  # Its pbSurf (Following Pokemon EX's copy of the stock one) refuses while anyone walks along as a dependent event;
  # the plugin's own pbHasDependentEvents? already leaves the following Pokemon out.
  surf_company(:dependents)
end
