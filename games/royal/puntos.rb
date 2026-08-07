module PokeAccess
  # royal's trainer-points screen ([ROYAL] Puntos entrenador -> PokemonOptionPuntos_Scene, whose option
  # window is Window_PokemonOption_Sky, a Window_DrawableCommand of SliderOptions the generic reader skips
  # because it has @options/@values, not @commands).
  module RoyalPoints
    # "name: value" for the focused option (lowest_value + the slider value), or the closing row.
    #
    # That last row is spoken with the screen's own word. The generic :sm_exit key reads "Salir", but this
    # screen draws _INTL("Cerrar") there, so the reader was naming a button that did not exist -- a small
    # thing, except it is the row the player has to find to leave.
    def self.line(win, i)
      opts = win.instance_variable_get(:@options)
      return "Cerrar" if opts.is_a?(Array) && i && i >= opts.length
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
  # Navigation between options (index change) goes through the generic command-window reader.
  screen_reader("Window_PokemonOption_Sky") { |win, i| PokeAccess::RoyalPoints.line(win, i) }
  # Left/right value edits keep the index, so the generic reader (which dedups by index) never re-fires for
  # them; read here when the window flags value_changed (true only on the edited frame, so no spam).
  after("Window_PokemonOption_Sky", :update) do |win, _r, _a|
    next unless (win.value_changed rescue false)
    t = PokeAccess::RoyalPoints.line(win, (win.index rescue nil))
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
  # The help line under the options. core/menus/option_help binds the two scene names every game has; this
  # scene is this plugin's own, so its binding belongs here rather than in a core list. Both method names
  # for the same reason core carries both: the fork renamed it and either may be the one that exists.
  after("PokemonOptionPuntos_Scene", :pbChangeSelection, :optional => true) do |s, _r, _a|
    PokeAccess::OptionHelp.read(s)
  end
  after("PokemonOptionPuntos_Scene", :updateDescription, :optional => true) do |s, _r, _a|
    PokeAccess::OptionHelp.read(s)
  end
end
