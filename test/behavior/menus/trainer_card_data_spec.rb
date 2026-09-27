# The trainer card panel (TrainerCardData), shared by the classic v21 and the v22 card: every field by its content,
# the ID, the Pokedex tally and the play time included.
Suite.define("trainer card: the panel names every field, not just the ones that survive an alias") do
  eng = PokeAccess::Engine
  saved = eng.method(:player)
  had_stats = $stats
  begin
    dex = Object.new
    def dex.owned_count; 42; end
    def dex.seen_count; 90; end

    who = Object.new
    def who.name; "Ayoub"; end
    def who.public_ID; 1234; end
    def who.money; 5000; end
    def who.badges; [true, true, true, false, false, false, false, false]; end
    who.instance_variable_set(:@dex, dex)
    def who.pokedex; @dex; end

    stats = Object.new
    def stats.play_time; 3720; end
    $stats = stats
    eng.define_singleton_method(:player) { who }

    t = PokeAccess::TrainerCardData.text.to_s
    truthy "the trainer's name is in it", t.index("Ayoub")
    truthy "the ID is padded to five digits, as the card prints it", t.index("01234")
    truthy "the money is in it", t.index("5000")
    truthy "the Pokedex tally is in it -- one of the three an alias mismatch drops",
           t.index("42") && t.index("90")
    truthy "the badge count is in it", t.index(PokeAccess::I18n.t(:tr_badges, :n => 3))
    truthy "and the play time, split into hours and minutes -- 3720 seconds is 1h 2m",
           t.index(PokeAccess::I18n.t(:tr_playtime, :h => 1, :m => 2))

    eng.define_singleton_method(:player) { nil }
    eq "with no trainer there is nothing to say, and no exception", PokeAccess::TrainerCardData.text, nil

    bare = Object.new
    def bare.name; "Sin dex"; end
    def bare.money; 10; end
    eng.define_singleton_method(:player) { bare }
    t2 = PokeAccess::TrainerCardData.text.to_s
    truthy "a trainer with no pokedex still reads the fields it does have", t2.index("Sin dex")
  ensure
    eng.define_singleton_method(:player, saved)
    $stats = had_stats
  end
end

# With no $stats (v19, Fire Ash) the play time comes from the frame count, as gen-6's does; every card also says the
# day the save was started.
Suite.define("trainer card: the time is found in any era, and the start day is said") do
  eng = PokeAccess::Engine
  saved = eng.method(:player)
  had_stats = $stats
  had_fc = Graphics.respond_to?(:frame_count) ? Graphics.method(:frame_count) : nil
  start_had = ($PokemonGlobal.respond_to?(:startTime) ? $PokemonGlobal.method(:startTime) : nil)
  begin
    who = Object.new
    def who.name; "Ayoub"; end
    def who.money; 10; end
    eng.define_singleton_method(:player) { who }
    $stats = nil
    Graphics.define_singleton_method(:frame_count) { 3720 * 40 }
    $PokemonGlobal.define_singleton_method(:startTime) { Time.local(2026, 9, 18, 10, 0, 0) }
    Object.send(:define_method, :pbGetMonthName) { |m| %w[x Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre][m] }

    t = PokeAccess::TrainerCardData.text.to_s
    truthy "with no $stats the time comes from the frame count, as the card itself computes it",
           t.index(PokeAccess::I18n.t(:tr_playtime, :h => 1, :m => 2))
    day = PokeAccess::I18n.t(:tcard_date, :d => 18, :m => "Septiembre", :y => 2026)
    truthy "and the start day is said with the game's own month name, in the language's order",
           t.index(PokeAccess::I18n.t(:tcard_started, :date => day))

    g6 = PokeAccess::TrainerCard.text.to_s
    truthy "the gen-6 card says it too", g6.index(PokeAccess::I18n.t(:tcard_started, :date => day))
  ensure
    eng.define_singleton_method(:player, saved)
    $stats = had_stats
    if had_fc
      Graphics.define_singleton_method(:frame_count, had_fc)
    else
      Graphics.singleton_class.send(:remove_method, :frame_count) rescue nil
    end
    if start_had
      $PokemonGlobal.define_singleton_method(:startTime, start_had)
    else
      $PokemonGlobal.singleton_class.send(:remove_method, :startTime) rescue nil
    end
    Object.send(:remove_method, :pbGetMonthName) rescue nil
  end
end
