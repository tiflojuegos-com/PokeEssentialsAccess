# Opalo new-game selector (event-driven pictures). The difficulty screen lights exactly one "...Dif#Claro"
# at a time, so those read directly via TEXTS. The first screen (Normal vs Nuzlocke) lights BOTH options at
# once, so there the pointer Y marks the selection (y~60 = Normal on top, y~210 = Nuzlocke below). ASCII
# only (ruby 1.8.7 / 3.1).
# The gender screen numbers its portraits the other way round from the core default: map 1's selector shows
# pantallaGenero2 for var 150 = 1, which the intro then answers with hombreArio/Mulato/Negro, and
# pantallaGenero1 for var 150 = 2, answered with mujerAria/Mulata/Negra. Read through the default table the
# mod announced each one as the other, which is worse than saying nothing.
PokeAccess::Game.define("opalo") do
  config(:gender_numbers, 1 => :ap_girl, 2 => :ap_boy)

  picture_texts(
    "MenuNuzNormalDif1Claro" => "Maestro. Los Pokemon debilitados mueren permanentemente; si pierdes un combate pierdes el reto.",
    "MenuNuzNormalDif2Claro" => "Normal. Los Pokemon debilitados mueren permanentemente; tienes 1 resurreccion por gimnasio y 2 oportunidades mas si pierdes un combate.",
    "MenuNuzNormalDif3Claro" => "Asistido. Los Pokemon debilitados mueren permanentemente; tienes 3 resurrecciones por gimnasio y 5 oportunidades mas si pierdes un combate."
  )
end

module PokeAccess
  module OpaloModes
    NORMAL = "Modo Normal. Juega a Pokemon de forma tradicional, sin reglas adicionales."
    NUZ    = "Modo Nuzlocke. Los Pokemon debilitados pueden morir permanentemente. Hay varios modos de dificultad."
    @screen = nil
    @last = nil

    # Tracks which selector screen is active and, on the first screen, reads the option the pointer is on
    # (the difficulty screen reads itself via TEXTS). param y the picture y position
    #
    # Both tints arm the first screen. The opening shows the two options dimmed ("Osc") and only lights one
    # ("Claro") once the player moves, so waiting for a lit one lost the opening read and the first move
    # with it -- on the very first screen of a new game.
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

    # Drops the selector state. The module outlives the screen, so without this a later visit whose
    # pointer opens on the option heard last would stay silent; any map change means the selector is gone.
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
