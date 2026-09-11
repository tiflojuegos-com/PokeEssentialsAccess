# Realidea's pause menu (0186_Modular_Menu.rb, a Neo-style sprite menu) paints a strip nobody read: the
# clock, and two key hints beside their icons -- "Guardar" by the Z key, always, and "Teletr." by the Q key
# only when the game lets the player teleport from here, a condition it decides itself and shows by
# drawing the icon. The strip is painted once in pbStartScene; pbShowMenu slides it in after the focused
# entry has been read, so it is said there, queued, once per menu.
module PokeAccess
  module ReaPauseOverlay
    # The strip as one line: the clock, and the keys whose icons are up right now.
    def self.text(scene)
      parts = []
      t = (pbGetTimeNow.strftime("%I:%M %p") rescue nil)
      parts.push("Hora #{t}") if t && !t.to_s.empty?
      parts.push("Z guarda")
      parts.push("Q teletransporta") if PokeAccess.sprite(scene, "Q")
      parts.join(". ")
    end
  end
end

PokeAccess::Game.define("realidea") do
  before("PokemonMenu_Scene", :pbStartScene, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :rea_overlay) }
  after("PokemonMenu_Scene", :pbShowMenu, :optional => true) do |scene, _r, _a|
    if PokeAccess::Cursor.changed?(scene, :rea_overlay, true)
      PokeAccess.speak(PokeAccess::ReaPauseOverlay.text(scene), false)
    end
  end
end
