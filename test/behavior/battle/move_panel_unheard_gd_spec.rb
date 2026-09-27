# BattleScene.unheard: a move panel under the fight cursor (Deluxe Battle Kit's, Soulstones 2's edited copy) adds
# only what the fight line has not said of that move; its first line since it was shut says it all.
class PanelFightMenu < Battle::Scene::FightMenu
  attr_accessor :user
  def battler; @user; end
end

Suite.define("move panel: under a moving cursor it adds only what the fight line did not say") do
  bs = PokeAccess::BattleScene
  tackle = Struct.new(:name, :type, :pp, :total_pp, :power, :accuracy, :category).new("Placaje", :NORMAL, 35, 35, 40, 100, 0)
  ember = Struct.new(:name, :type, :pp, :total_pp, :power, :accuracy, :category).new("Ascuas", :FIRE, 25, 25, 40, 100, 1)
  user = Struct.new(:index, :moves).new(0, [tackle, ember])
  menu = PanelFightMenu.new
  menu.user = user
  extras = ["prioridad +1", "Eficaz contra Rattata"]
  line = lambda { SpeakCapture.last.to_s.split(". ") }

  SpeakCapture.clear
  bs.read_menu(menu)
  bs.unheard(user, 0, line.call[0, 5] + extras)

  menu.index = 1
  said = line.call
  truthy "moving the cursor says the fight line", said.length >= 5
  panel = said[0, 5] + extras
  eq "under the moved cursor only what the fight line did not say", bs.unheard(user, 1, panel), extras
  eq "a repaint of the same move says nothing again", bs.unheard(user, 1, panel), []
  staged = panel.map { |p| p == said[1] ? "Tipo Dragon" : p }
  eq "a mechanic staged on the same move says only what it changed", bs.unheard(user, 1, staged), ["Tipo Dragon"]

  bs.read_menu(menu)
  eq "the fight line said again for the same move starts over, and the panel adds its own again",
     bs.unheard(user, 1, panel), extras

  bs.panel_shut
  eq "the panel's first line since it was shut says it all", bs.unheard(user, 1, panel), panel
end
