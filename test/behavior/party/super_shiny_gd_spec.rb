# Skyflyer's games (anil, royal) paint a super shiny with its own purple star: the shiny word says which star is
# painted, in the lists (skyflyer_common, which this pass's anil profile imports) and in Royal's DBK battler panel,
# the one copy of that panel that draws the purple star too.
load File.expand_path("../../../games/royal/super_shiny.rb", File.dirname(__FILE__))

# A Pokemon for the shiny checks: shiny, super shiny or not.
def super_shiny_spec_pk(super_shiny)
  pk = Object.new
  pk.define_singleton_method(:name) { "Pikachu" }
  pk.define_singleton_method(:shiny?) { true }
  pk.define_singleton_method(:super_shiny?) { super_shiny }
  pk
end

Suite.define("skyflyer: a super shiny is said by its own star, in the lists and in Royal's battle panel") do
  t = PokeAccess::I18n
  plain = super_shiny_spec_pk(false)
  super_one = super_shiny_spec_pk(true)
  eq "a shiny keeps the shiny word", PokeAccess::Party.shiny_word(plain), t.t(:pk_shiny)
  eq "a super shiny says its purple star", PokeAccess::Party.shiny_word(super_one), t.t(:pk_super_shiny)
  eq "a Pokemon that knows no such tier keeps the shiny word", PokeAccess::Party.shiny_word(Object.new), t.t(:pk_shiny)
  eq "the lists' marks say it as well", PokeAccess::Party.icon_mark_list(super_one), [t.t(:pk_super_shiny)]
  battler = Object.new
  battler.define_singleton_method(:pokemon) { super_one }
  eq "Royal's battler panel says the star it draws", PokeAccess::DBKBattlerInfo.identity_parts(battler),
     ["Pikachu", t.t(:pk_super_shiny)]
  eq "and a plain shiny's red one", PokeAccess::DBKBattlerInfo.shiny_word(plain), t.t(:pk_shiny)
end
