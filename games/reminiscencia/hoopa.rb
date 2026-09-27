module PokeAccess
  # Reminiscencia's Hoopa gacha: a prize the roulette stops on is handed over with pbAddPokemonRNG, whose "obtained"
  # line names only the species; a shiny one (the paid shiny boost) is drawn shiny, said after that line.
  module ReminHoopa
    @spinning = false

    # Runs the roulette with the prize watch on.
    def self.spin
      @spinning = true
      yield
    ensure
      @spinning = false
    end

    # Before pbAddPokemonRNG: during the roulette, a shiny prize going into a party or box with room says so after
    # the obtained line.
    def self.prize(pokemon)
      return unless @spinning && PokeAccess::Party.shiny?(pokemon)
      return if (pbBoxesFull? rescue false)
      PokeAccess.after_next_line(PokeAccess::Party.shiny_word(pokemon))
    end
  end
end

# The Hoopa gacha's balance (heart scales and coins), painted by drawMaintext after every spin, captured and said
# queued; its prize and refusals are dialogue, a shiny prize marked after it.
PokeAccess::Game.define("reminiscencia") do
  around("HoopaGacha", :drawMaintext, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:rem_hoopa, false) { nxt.call }
  end
  around("HoopaGacha", :startRoulette, :optional => true) do |_s, nxt, _a|
    PokeAccess::ReminHoopa.spin { nxt.call }
  end
  kernel("pbAddPokemonRNG", :before) { |args, _r| PokeAccess::ReminHoopa.prize(args[0]) }
end
