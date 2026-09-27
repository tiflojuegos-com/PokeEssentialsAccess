# Pokemon Z's ball key (Atajo Ball: the S panel its command menu draws in wild battles, which throws a ball without
# the bag by moving the cursor to a fifth command): a hint when the menu opens, and the ball when the key is pressed.
# The ball named is the one the battle throws, which the panel's icon ranks otherwise.
module PokeAccess
  module ZBallKey
    # The balls the key throws, the first one in the bag taken, in the battle's order.
    THROW_ORDER = [:ULTRABALLCASERA, :SUPERBALLCASERA, :POKEBALLCASERA, :ULTRABALL, :GREATBALL, :POKEBALL]

    # The command the key moves the cursor to before the menu returns it.
    INDEX = 4

    # The name of the ball the key would throw now, or nil with none in the bag.
    def self.ball_name
      THROW_ORDER.each do |sym|
        next unless ($PokemonBag.pbHasItem?(sym) rescue false)
        name = (PokeAccess::Data.item_id(sym) || [])[1]
        return name.to_s unless name.nil? || name.to_s.strip.empty?
      end
      nil
    end

    # Whether the command menu draws the key's panel, which it makes only for a wild battle.
    def self.panel?(disp)
      !PokeAccess.ivar(disp, :@atajoBall).nil?
    end

    # Reads a command through the core's reader (the block): the key's command as the ball it throws, and after an
    # opening read the key's hint.
    def self.read(disp, index, interrupt)
      return yield unless panel?(disp)
      ball = ball_name
      if index == INDEX
        PokeAccess.speak(PokeAccess::I18n.t(:zball_throw, :ball => ball), interrupt) if ball
        return nil
      end
      r = yield
      hint(disp, ball) unless interrupt
      r
    end

    # Says the key's hint, queued, while key hints are said, when the ball it throws is new to this battle's menu.
    def self.hint(disp, ball)
      return unless ball && PokeAccess::Verbosity.hints?
      return unless PokeAccess::Cursor.changed?(disp, :zball_hint, ball)
      PokeAccess.speak(PokeAccess::I18n.t(:zball_hint, :key => PokeAccess::KeyHints.key(:y, "S"), :ball => ball), false)
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  override("PokeAccess::Battle", :read_command) do |_mod, original, args|
    PokeAccess::ZBallKey.read(args[0], args[1], args[2]) { original.call }
  end
end
