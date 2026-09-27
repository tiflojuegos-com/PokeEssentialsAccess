# Awakening's talisman screen (EquipScreen) through its profile hooks: the focused talisman stays on the info key
# while the screen is up and leaves it when the screen ends. The other classes the file hooks are stood in too.
class EquipScreen
  def update_description; :described; end
  def main_loop; :looped; end
  def open_lore_window; :opened; end
  def update_lore_window; :scrolled; end
  def pbEndScreen; :ended; end
  def unlocked?(_s); true; end
end

class BallSelectorInterface
  def update_display; :shown; end
end

class Glosario_Personajes
  def mover_cursor(_d); :moved; end
  def dibujar_lista; :drawn; end
  def mostrar_texto(_n, _p = 0); :shown; end
end

load File.expand_path("../../../games/awakening/fates_screens.rb", File.dirname(__FILE__))

Suite.define("awakening talismans: the focused one stays on the info key until the screen ends") do
  scene = EquipScreen.new
  scene.instance_variable_set(:@talismans, [{ :id => 7, :name => "Talismán del Sol", :symbol => :sol,
                                              :description => "Da fuerza." }])
  scene.instance_variable_set(:@selected_index, 0)
  eq "the description hook keeps the game's own return value", scene.update_description, :described
  eq "the talisman is on the info key", PokeAccess::Info.info_text, "Talismán del Sol. Da fuerza."
  eq "ending the screen keeps its own return value", scene.pbEndScreen, :ended
  falsy "and takes the talisman off the info key", PokeAccess::Info.info_text.to_s.include?("Talismán")
end
