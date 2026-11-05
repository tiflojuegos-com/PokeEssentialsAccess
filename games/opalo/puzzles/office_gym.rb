# Opalo's gym of the office (map 39): the boss (event 3) wants one coffee from the machine (event 2), which works only with
# the coin he gives (var 147 at 1 or more). The right coffee opens the way (switch 95); the others cost money and give the coin back.
module PokeAccess
  module OpaloOffice
    COFFEE = "PBItems::SAWSBUCKS"
    MACHINE = 2
    COIN = 147
    SERVED = 95

    # The coffee the boss wants, said at the machine while it offers its coffees and he has not been served.
    def self.wanted
      return "" if $game_switches[SERVED] || $game_variables[COIN].to_i < 1
      id = PokeAccess.const_at(COFFEE)
      id ? [:op_g1_coffee, { :item => PokeAccess::Data.item_name(id) }] : ""
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end
  end
end

PokeAccess::Game.define("opalo") do
  office = PokeAccess::OpaloOffice
  mechanic(:state, 39) do
    auto
    name office::MACHINE, :op_g1_machine
    on_use office::MACHINE, lambda { office.wanted }, :assist => true
  end
end
