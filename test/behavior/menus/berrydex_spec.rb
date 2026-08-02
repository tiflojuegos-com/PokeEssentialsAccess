# The berry dex plugin. Its list window is the same code in both copies, but the DETAIL screen is not: one
# ships four pages behind pbShowBattlePage?/pbShowMutationsPage?, the other only two and has neither
# predicate. Rescuing a missing predicate into "true" would invent two sections the second game does not
# have, so the section list is built from what the scene actually answers to.
require File.expand_path("../../../plugins/berrydex", File.dirname(__FILE__))

class FakeBerryWindow
  def initialize(cmds); @commands = cmds; end
end

class FakeBerryDexFull
  def pbShowBattlePage?; true; end
  def pbShowMutationsPage?; true; end
end

class FakeBerryDexBattleOnly
  def pbShowBattlePage?; true; end
  def pbShowMutationsPage?; false; end
end

Suite.define("berrydex: sections come from the pages this copy can actually show") do
  bd = PokeAccess::BerryDex
  info   = PokeAccess::I18n.t(:bdx_page_info)
  plant  = PokeAccess::I18n.t(:bdx_page_plant)
  battle = PokeAccess::I18n.t(:bdx_page_battle)
  mut    = PokeAccess::I18n.t(:bdx_page_mut)

  eq "the four-page copy lists all four", bd.sections(FakeBerryDexFull.new), [info, plant, battle, mut]
  eq "a berry with no mutations page drops it", bd.sections(FakeBerryDexBattleOnly.new), [info, plant, battle]
  eq "the two-page copy, which has neither predicate, lists exactly two",
     bd.sections(Object.new), [info, plant]

  eq "an absent predicate is not a yes", bd.shows?(Object.new, :pbShowBattlePage?), false

  win = FakeBerryWindow.new([[:ORANBERRY, "Baya Aranja", 1], [:SITRUSBERRY, "Baya Zidra", 2]])
  eq "an unregistered berry is announced by number, not by the row of dashes the screen paints",
     bd.entry_text(win, 1), PokeAccess::I18n.t(:bdx_unknown, :num => 2)
  eq "and an index past the list says nothing", bd.entry_text(win, 9), nil
end
