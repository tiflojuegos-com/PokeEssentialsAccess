# Edas' pause menu (0206_MenuPole, Menu2): each icon carries its word in the picture, said as painted, and the debt it
# paints beside the money joins the trainer line, which the info key says there and on the map.
module PokeAccess
  module EdasPause
    ICON_WORDS = { "bag" => "Bolsa", "pokeball" => "Equipo", "save" => "Guardar", "options" => "Opciones",
                   "misiones" => "Misiones", "reloj" => "Reloj Arcano" }

    # The debt as the menu paints it, or nil where it paints none: switch 68 on, switch 137 off and money still short.
    def self.debt(trainer)
      return nil unless $game_switches[68] && !$game_switches[137]
      left = ($PokemonGlobal.deuda rescue 0).to_i - trainer.money.to_i
      left > 0 ? _INTL("Deuda: #{left}$") : nil
    end
  end
end

PokeAccess::Game.define("edas") do
  override("PokeAccess::Menu2Pause", :label) do |_mod, original, args|
    PokeAccess::EdasPause::ICON_WORDS[args[0][0].to_s] || original.call
  end
  trainer_part(:debt) { |trainer| PokeAccess::EdasPause.debt(trainer) }
  # The Time Orb's night (switch 100, 0113_PField_Time_) holds whatever the clock says.
  override("PokeAccess::Battle", :time_of_day) { |_mod, original, _args| $game_switches[100] ? :tod_night : original.call }
end
