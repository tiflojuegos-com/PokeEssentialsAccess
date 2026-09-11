# What the party panel draws as an icon and no spoken line said. Shiny had NO path anywhere in the mod:
# not the party line, not the summary, not the info key. In the eight modern games the panel marks it with
# a star; in the seven gen-6 ones nothing marks it at all, the icon just uses the alternate palette -- so a
# blind player could raise a shiny to level 100 without ever being told it was one.
#
# Held item and status are icons too and are deliberately NOT here: both are already in the info key's
# glance, and a line the player hears six times walking down the party has to stay short.
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

  eq "an ordinary member adds nothing at all", pa.icon_marks(mk.call(false, 0)), ""
  eq "a shiny says so", pa.icon_marks(mk.call(true, 0)), ", " + PokeAccess::I18n.t(:pk_shiny)
  eq "pokerus says so", pa.icon_marks(mk.call(false, 1)), ", " + PokeAccess::I18n.t(:pk_pokerus)
  eq "both, in panel order", pa.icon_marks(mk.call(true, 1)),
     ", " + PokeAccess::I18n.t(:pk_shiny) + ", " + PokeAccess::I18n.t(:pk_pokerus)
  eq "no pokemon at all is not an error", pa.icon_marks(nil), ""

  # The question has two spellings and the games are split: seven gen-6 ask isShiny?, eight modern shiny?.
  # Probing one of them left the mark unspoken in half of them, and silently, because the probe just
  # answered false.
  old_spelling = Object.new
  def old_spelling.isShiny?; true; end
  truthy "the gen-6 spelling of the question is understood", pa.shiny?(old_spelling)
  eq "and its line says so", pa.icon_marks(old_spelling), ", " + PokeAccess::I18n.t(:pk_shiny)
  neither = Object.new
  falsy "a pokemon that answers neither is not shiny", pa.shiny?(neither)

  # Only stage 1 is an infection still running: 0 was never infected and 2 is cured, and the panel draws
  # the icon for stage 1 alone.
  truthy "a pokemon still carrying it counts", pa.pokerus?(mk.call(false, 1))
  falsy "a CURED one does not, and no screen marks it either", pa.pokerus?(mk.call(false, 2))
  eq "so its line stays clean", pa.icon_marks(mk.call(false, 2)), ""
  falsy "and neither does one that never had it", pa.pokerus?(mk.call(false, 0))
  bare = Object.new
  def bare.shiny?; false; end
  falsy "a pokemon that answers nothing at all does not", pa.pokerus?(bare)
  eq "which leaves its line untouched", pa.icon_marks(bare), ""
end

# An egg hides everything about what is inside it, and the panel refuses to draw either mark on one
# (Essentials 016_UI/005_UI_Party.rb:237 and :253). shiny? still answers truthfully underneath, so saying it
# is the mod telling the player exactly what the screen is keeping from them -- the same spoiler this
# release took out of the summary, one screen over.
Suite.define("party: an egg says none of its marks, because its own screen refuses to draw them") do
  pa = PokeAccess::Party
  egg = Object.new
  def egg.shiny?; true; end
  def egg.pokerusStage; 1; end
  def egg.egg?; true; end

  truthy "the truth underneath is still shiny", pa.shiny?(egg)
  eq "and the line says nothing about it", pa.icon_marks(egg), ""
  eq "nor as a list", pa.icon_mark_list(egg), []
end

# The glance line ends in a full stop, so the marks cannot be appended as a comma clause the way the party
# line takes them: that gave "10 de 10 PS., variocolor. Macho."
Suite.define("party: the marks join the glance as their own sentence, not after its full stop") do
  pk = Poke.build(:name => "Chispa", :level => 5, :hp => 10, :totalhp => 10, :item => 0, :status => 0,
                  :gender => nil, :shiny => true)
  t = PokeAccess::Info.pokemon_info(pk).to_s
  falsy "no stop is left stranded before the mark", t =~ /\.,/
  match "and the mark is still said", t, /#{PokeAccess::I18n.t(:pk_shiny)}/
end
