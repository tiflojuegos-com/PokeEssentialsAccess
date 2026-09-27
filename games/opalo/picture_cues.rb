# Opalo's new-game selector, drawn as pictures: the lit difficulty, the mode by the pointer's y and the gender
# portraits, numbered the other way round from core (pantallaGenero1 is the girl); also the title's splash image.
PokeAccess::Game.define("opalo") do
  config(:gender_numbers, 1 => :ap_girl, 2 => :ap_boy)

  picture_texts(
    "MenuNuzNormalDif1Claro" => "Maestro. Los Pokemon debilitados mueren permanentemente; si pierdes un combate pierdes el reto.",
    "MenuNuzNormalDif2Claro" => "Normal. Los Pokemon debilitados mueren permanentemente; tienes 1 resurreccion por gimnasio y 2 oportunidades mas si pierdes un combate.",
    "MenuNuzNormalDif3Claro" => "Asistido. Los Pokemon debilitados mueren permanentemente; tienes 3 resurrecciones por gimnasio y 5 oportunidades mas si pierdes un combate.",
    "intro1" => "Pokémon Ópalo by Eric Lostie. Pokémon Essentials: 2011-2014 Maruno, 2007-2010 Peter O. Based on work by Flameguru. Title Screen by Luka S.J."
  )
end

module PokeAccess
  module OpaloModes
    NORMAL = "Modo Normal. Juega a Pokemon de forma tradicional, sin reglas adicionales."
    NUZ    = "Modo Nuzlocke. Los Pokemon debilitados pueden morir permanentemente. Hay varios modos de dificultad."
    @screen = nil
    @last = nil

    # Tracks the selector screen and, on the first, says the mode the pointer is on (y under 120 is Normal). Both
    # tints ("Claro", "Osc") mark the first screen, which opens with both dimmed.
    # param y the picture y position
    def self.handle(name, y)
      if name =~ /MenuNuz(Normal|Nuz)(Claro|Osc)$/
        @screen = :first
      elsif name =~ /MenuNuzNormalDif/
        @screen = :diff
      elsif name =~ /MenuNuzPuntero/ && @screen == :first
        sel = y.to_i < 120 ? NORMAL : NUZ
        return if sel == @last
        @last = sel
        PokeAccess.speak(sel, true)
      end
    end

    # Drops the selector state on a map change (Caches), so a later visit is read afresh.
    def self.reset
      @screen = nil
      @last = nil
    end
  end
end

PokeAccess::Caches.register(:opalo_modes) { PokeAccess::OpaloModes.reset }

PokeAccess::Game.define("opalo") do
  on_picture { |name, args| PokeAccess::OpaloModes.handle(name, args[3]) }
end
