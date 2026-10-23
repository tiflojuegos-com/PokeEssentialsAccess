# Realidea's levers: those of its Palancas2 sheet told apart by their colour, one per row (the Lab's switches 171 to
# 174 follow the same order), and "actualizar", which its mappers leave on doors, chests and levers, as no name.
module PokeAccess
  module RealideaLevers
    # The sheet whose rows are the levers' colours.
    SHEET = "Palancas2"
    # The colour of each row of the sheet, by the facing that draws it.
    COLOURS = { 2 => :rea_lever_green, 4 => :rea_lever_yellow, 6 => :rea_lever_red, 8 => :rea_lever_lilac }

    # A Palancas2 lever's line, its colour and whether it is pulled; nil for any other event.
    def self.name(ev)
      return nil unless (ev.character_name.to_s rescue "") == SHEET && PokeAccess::Locator.lever?(ev)
      key = COLOURS[(ev.instance_variable_get(:@event).pages[0].graphic.direction rescue nil)]
      key ? PokeAccess::I18n.t(key) + PokeAccess::Locator.lever_state_suffix(ev) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  # "actualizar" is a placeholder, as EV### is.
  override("PokeAccess::Locator", :placeholder_name?) do |_mod, original, args|
    args[0].to_s =~ /\Aactualizar\z/i ? true : original.call
  end

  # The Palancas2 levers say their colour.
  event_name { |ev| PokeAccess::RealideaLevers.name(ev) }
end
