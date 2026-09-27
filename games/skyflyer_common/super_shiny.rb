# Skyflyer's games paint a super shiny (Pokemon#super_shiny?) with its own purple star, shiny_ur, where any other
# shiny has the red one, so the word for the star says which of the two is painted.
PokeAccess::Game.define("skyflyer_common") do
  override("PokeAccess::Party", :shiny_word) do |_mod, original, args|
    (args[0].super_shiny? rescue false) ? PokeAccess::I18n.t(:pk_super_shiny) : original.call
  end
end

# The battle box draws the same purple star beside a super shiny's name.
PokeAccess::Battle.icon_mark(/\Ashiny_ur\z/i, :pk_super_shiny)
