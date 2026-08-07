# The trainer card panel, shared by the classic v21 card and the v22 UI card. It had no coverage at all,
# which matters because of HOW it broke: a gen-6 fork can declare the modern class name as an empty
# subclass alias, the modern card binds instead of the gen-6 one, and the panel then reads the trainer
# through the modern accessors -- which silently drop the ID, the Pokedex tally and the play time. The
# card still talks, so nothing looks broken; it just stops saying three of the six things it is for.
#
# So this asserts the CONTENT, field by field, rather than that a string came out.
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
    # Matched as whole phrases, not as loose digits: "01234" alone contains a 1, a 2 and a 3, so digit
    # spotting passes with the badge count and the play time both missing.
    truthy "the badge count is in it", t.index("3 medallas")
    truthy "and the play time, split into hours and minutes -- 3720 seconds is 1h 2m",
           t.index("1 horas") && t.index("2 minutos")

    # No player at all is the boot case (the card can be opened from a menu before a save is loaded on
    # some forks): it must answer nothing rather than raise into the scene.
    eng.define_singleton_method(:player) { nil }
    eq "with no trainer there is nothing to say, and no exception", PokeAccess::TrainerCardData.text, nil

    # A trainer whose pokedex accessor is absent still gets the rest of the card. Degrading to silence
    # here would be the same bug from the other side.
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
