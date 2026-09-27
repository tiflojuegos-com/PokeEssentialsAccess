# The party panel's icon-only marks (shiny, pokerus) are spoken; held item and status stay out, being on the glance
# already. shiny? reads either spelling (isShiny?, shiny?); pokerus counts only at stage 1, the one the panel draws.
Suite.define("party: the icon-only marks of a member are spoken, and an ordinary one stays short") do
  mk = lambda do |shiny, stage|
    o = Object.new
    o.instance_variable_set(:@s, shiny)
    o.instance_variable_set(:@r, stage)
    def o.shiny?; @s; end
    def o.pokerusStage; @r; end
    def o.egg?; false; end
    o
  end
  pa = PokeAccess::Party
  shiny = PokeAccess::I18n.t(:pk_shiny)
  rus = PokeAccess::I18n.t(:pk_pokerus)

  eq "an ordinary member adds nothing at all", pa.icon_mark_list(mk.call(false, 0)), []
  eq "a shiny says so", pa.icon_mark_list(mk.call(true, 0)), [shiny]
  eq "pokerus says so", pa.icon_mark_list(mk.call(false, 1)), [rus]
  eq "both, in panel order", pa.icon_mark_list(mk.call(true, 1)), [shiny, rus]
  eq "no pokemon at all is not an error", pa.icon_mark_list(nil), []

  old_spelling = Object.new
  def old_spelling.isShiny?; true; end
  truthy "the gen-6 spelling of the question is understood", pa.shiny?(old_spelling)
  eq "and its marks say so", pa.icon_mark_list(old_spelling), [shiny]
  neither = Object.new
  falsy "a pokemon that answers neither is not shiny", pa.shiny?(neither)

  truthy "a pokemon still carrying it counts", pa.pokerus?(mk.call(false, 1))
  falsy "a CURED one does not, and no screen marks it either", pa.pokerus?(mk.call(false, 2))
  eq "so its marks stay empty", pa.icon_mark_list(mk.call(false, 2)), []
  falsy "and neither does one that never had it", pa.pokerus?(mk.call(false, 0))
  bare = Object.new
  def bare.shiny?; false; end
  falsy "a pokemon that answers nothing at all does not", pa.pokerus?(bare)
  eq "which leaves its marks empty", pa.icon_mark_list(bare), []
end

# An egg says none of its marks, as the panel draws none on it, though shiny? still answers true underneath.
Suite.define("party: an egg says none of its marks, because its own screen refuses to draw them") do
  pa = PokeAccess::Party
  egg = Object.new
  def egg.shiny?; true; end
  def egg.pokerusStage; 1; end
  def egg.egg?; true; end

  truthy "the truth underneath is still shiny", pa.shiny?(egg)
  eq "and its marks say nothing about it", pa.icon_mark_list(egg), []
end

# The marks join the glance as a sentence of their own, not as a comma clause after its full stop.
Suite.define("party: the marks join the glance as their own sentence, not after its full stop") do
  pk = Poke.build(:name => "Chispa", :level => 5, :hp => 10, :totalhp => 10, :item => 0, :status => 0,
                  :gender => nil, :shiny => true)
  t = PokeAccess::Info.pokemon_info(pk).to_s
  falsy "no stop is left stranded before the mark", t =~ /\.,/
  match "and the mark is still said", t, /#{PokeAccess::I18n.t(:pk_shiny)}/
end
