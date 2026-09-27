module PokeAccess
  # Insurgence's custom move (CUSTOMMOVE, the Move Master's): its data says "Custom Move" and type ???, but the screens
  # paint the name the player gave it ($game_variables[100]) and the type chosen for it ($game_variables[98]).
  module InsurgenceCustomMove
    ID = 579

    # The Move Master's type list, in the order $game_variables[98] counts it.
    TYPES = [:NORMAL, :GRASS, :FIRE, :WATER, :POISON, :FIGHTING, :DARK, :PSYCHIC, :GHOST, :ICE, :GROUND, :ROCK,
             :FLYING, :BUG, :ELECTRIC, :DRAGON, :STEEL, :FAIRY]

    # The name and type name painted for a move: the player's own for the custom move, else those given.
    def self.painted(m, name, type_name)
      return [name, type_name] unless PokeAccess::MoveInfo.id_of(m) == ID
      given = ($game_variables[100] rescue nil)
      name = given if given.is_a?(String) && !given.empty?
      [name, chosen_type_name(($game_variables[98] rescue nil))]
    end

    # The name of the type a choice index gives the move, Normal for an index off the list as pbType has it; nil
    # where the type cannot be named.
    def self.chosen_type_name(choice)
      sym = (choice.is_a?(Integer) && choice >= 0) ? TYPES[choice] : nil
      id = (PBTypes.const_get(sym || :NORMAL) rescue nil)
      id.nil? ? nil : PokeAccess::Data.type_name(id)
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::MoveInfo", :painted) { |_m, _original, args| PokeAccess::InsurgenceCustomMove.painted(*args) }
end
