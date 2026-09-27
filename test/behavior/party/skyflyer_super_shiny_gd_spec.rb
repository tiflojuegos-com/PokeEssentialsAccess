# Skyflyer's games (anil, royal) paint a super shiny with its own purple star (Graphics/UI/shiny_ur) where any other
# shiny has the red one: the shiny word of the lists and the summary says which star is painted. Gamedata pass, whose
# anil profile imports skyflyer_common.
module SkyflyerSuperShinySpec
  # A shiny Pokemon, super shiny or not.
  def self.pk(super_shiny)
    pk = Object.new
    pk.define_singleton_method(:name) { "Pikachu" }
    pk.define_singleton_method(:shiny?) { true }
    pk.define_singleton_method(:super_shiny?) { super_shiny }
    pk
  end
end

Suite.define("skyflyer: a super shiny is said by its purple star, a plain shiny by the red one") do
  t = PokeAccess::I18n
  party = PokeAccess::Party
  eq "a plain shiny keeps the shiny word", party.shiny_word(SkyflyerSuperShinySpec.pk(false)), t.t(:pk_shiny)
  eq "a super shiny says its own star", party.shiny_word(SkyflyerSuperShinySpec.pk(true)), t.t(:pk_super_shiny)
  eq "a Pokemon that knows no such tier keeps the shiny word", party.shiny_word(Object.new), t.t(:pk_shiny)
  eq "the lists' icon marks say it as well", party.icon_mark_list(SkyflyerSuperShinySpec.pk(true)), [t.t(:pk_super_shiny)]
end

Suite.define("skyflyer: the battle box's purple star is said as the super shiny mark") do
  foe = Struct.new(:index, :name, :pokemon).new(1, "Pikachu", Object.new)
  box = Battle::Scene::PokemonDataBox.new(foe)
  box.extra = %w[shiny_ur]
  box.refresh
  eq "by the same word as the lists", PokeAccess::Battle.shown_marks(foe), [PokeAccess::I18n.t(:pk_super_shiny)]
end
