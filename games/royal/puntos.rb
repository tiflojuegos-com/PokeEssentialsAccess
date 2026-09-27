module PokeAccess
  # Royal's trainer-points screen (PokemonOptionPuntos_Scene), whose slider window Window_PokemonOption_Sky has
  # @options rather than the @commands the generic reader reads.
  module RoyalPoints
    # "name: value" for the focused option (lowest_value + slider value), or the closing row as painted, "Cerrar".
    def self.line(win, i)
      opts = win.instance_variable_get(:@options)
      return (_INTL("Cerrar") rescue "Cerrar") if opts.is_a?(Array) && i && i >= opts.length
      return nil unless opts.is_a?(Array) && i && opts[i]
      o = opts[i]
      name = (o.name rescue "").to_s
      v = PokeAccess::Options.value_of(o, (win[i] rescue 0))
      name.empty? ? v.to_s : "#{name}: #{v}"
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  # The focused option on each index change.
  screen_reader("Window_PokemonOption_Sky") { |win, i| PokeAccess::RoyalPoints.line(win, i) }
  # A value edit keeps the index, so it is read here, on the frame the window flags value_changed.
  after("Window_PokemonOption_Sky", :update) do |win, _r, _a|
    next unless (win.value_changed rescue false)
    t = PokeAccess::RoyalPoints.line(win, (win.index rescue nil))
    PokeAccess.speak(t, true)
  end
  # The help line under the options, bound on both method names as in core (the fork renamed it).
  after("PokemonOptionPuntos_Scene", :pbChangeSelection, :optional => true) do |s, _r, _a|
    PokeAccess::OptionHelp.read(s)
  end
  after("PokemonOptionPuntos_Scene", :updateDescription, :optional => true) do |s, _r, _a|
    PokeAccess::OptionHelp.read(s)
  end
end

# The points total the screen rewrites after every slider edit (actualizarPuntosTotales).
PokeAccess::InfoWindow.watch("PokemonOptionPuntos_Scene", "puntos_totales", :royal_points_total)
