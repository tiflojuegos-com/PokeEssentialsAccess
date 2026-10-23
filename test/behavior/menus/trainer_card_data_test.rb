# The composed trainer card: TrainerCardData (the v21 and v22 cards' fallback) names every field the trainer has, in
# the card's order, and TrainerCard.text (the gen-6 card's) is the trainer summary; both close with the save's start day.
class TrainerCardDataTest < PokeAccessTest
  # The game's month names, by month number.
  MONTHS = [nil, "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre"].freeze

  test "names every field of a trainer that has them all, in the card's order" do
    who = trainer(:name => "Ayoub", :public_ID => 1234, :money => 5000, :badges => [true, true, true, false, false],
                  :pokedex => trainer(:owned_count => 42, :seen_count => 90))
    as_trainer(who) do
      with_stats(3720) do
        assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_id, :id => "01234"), t(:tc_money, :n => 5000),
                      t(:tc_pokedex, :owned => 42, :seen => 90), t(:tr_badges, :n => 3),
                      t(:tr_playtime, :h => 1, :m => 2)].join(". "),
                     PokeAccess::TrainerCardData.text
      end
    end
  end

  test "says nothing with no trainer" do
    as_trainer(nil) { assert_nil PokeAccess::TrainerCardData.text }
  end

  test "reads the fields a trainer with no ID, Pokedex or badges does have" do
    as_trainer(trainer(:name => "Sin dex", :money => 10)) do
      assert_equal [t(:tc_title), t(:tc_name, :name => "Sin dex"), t(:tc_money, :n => 10)].join(". "),
                   PokeAccess::TrainerCardData.text
    end
  end

  test "leaves out the name of a trainer with none to read" do
    { "a nil name" => trainer(:name => nil, :money => 10),
      "no name at all" => trainer(:money => 10) }.each do |what, who|
      as_trainer(who) do
        assert_equal [t(:tc_title), t(:tc_money, :n => 10)].join(". "), PokeAccess::TrainerCardData.text, what
      end
    end
  end

  test "reads the other fields of a trainer whose Pokedex fails to count" do
    as_trainer(trainer(:name => "Ayoub", :money => 10, :pokedex => failing_dex)) do
      assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10)].join(". "),
                   PokeAccess::TrainerCardData.text
    end
  end

  test "a face falling back on the composed card keeps its paint's return when the Pokedex fails to count" do
    as_trainer(trainer(:name => "Ayoub", :money => 10, :pokedex => failing_dex)) do
      card = lambda { PokeAccess::TrainerCardData.text }
      assert_equal :painted, PokeAccess::TrainerCard.read_face(Object.new, true, card) { :painted }
    end
  end

  test "counts a trainer with no money as holding none" do
    as_trainer(trainer(:name => "Ayoub")) do
      assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 0)].join(". "),
                   PokeAccess::TrainerCardData.text
    end
  end

  test "leaves out a Pokedex that keeps no counts" do
    as_trainer(trainer(:name => "Ayoub", :money => 10, :pokedex => Object.new)) do
      assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10)].join(". "),
                   PokeAccess::TrainerCardData.text
    end
  end

  test "counts badges however the engine exposes them" do
    { { :numbadges => 4 } => 4, { :badge_count => 5 } => 5, { :badges => [true, false, true] } => 2,
      { :numbadges => 4, :badges => [true] } => 4 }.each do |fields, n|
      as_trainer(trainer({ :name => "Ayoub", :money => 10 }.merge(fields))) do
        assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10), t(:tr_badges, :n => n)].join(". "),
                     PokeAccess::TrainerCardData.text, fields.keys.inspect
      end
    end
  end

  test "splits the play time into whole hours and the minutes past them" do
    { 3600 => [1, 0], 3599 => [0, 59], 7322 => [2, 2], 59 => [0, 0] }.each do |secs, (h, m)|
      as_trainer(trainer(:name => "Ayoub", :money => 10)) do
        with_stats(secs) do
          assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10),
                        t(:tr_playtime, :h => h, :m => m)].join(". "),
                       PokeAccess::TrainerCardData.text, "#{secs} seconds"
        end
      end
    end
  end

  test "takes the play time from the frame count over the frame rate where the game keeps no $stats" do
    as_trainer(trainer(:name => "Ayoub", :money => 10)) do
      with_stats(nil) do
        with_frames(3720 * Graphics.frame_rate) do
          assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10),
                        t(:tr_playtime, :h => 1, :m => 2)].join(". "),
                       PokeAccess::TrainerCardData.text
        end
      end
    end
  end

  test "closes with the day the save was started, the month named by the game, in the language's order" do
    as_trainer(trainer(:name => "Ayoub", :money => 10)) do
      with_start(Time.local(2026, 9, 18, 10, 0, 0), :pbGetMonthName => lambda { |m| MONTHS[m] }) do
        assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10), started(18, "Septiembre", 2026)]
                       .join(". "),
                     PokeAccess::TrainerCardData.text
      end
    end
  end

  test "names the start month by the game's abbreviation, else by its number, where it has no full name" do
    { { :pbGetAbbrevMonthName => lambda { |_m| "Sep" } } => "Sep",
      { :pbGetMonthName => lambda { |_m| "" }, :pbGetAbbrevMonthName => lambda { |_m| "Sep" } } => "Sep",
      { :pbGetAbbrevMonthName => lambda { |_m| "" } } => "9",
      {} => "9" }.each do |functions, month|
      as_trainer(trainer(:name => "Ayoub", :money => 10)) do
        with_start(Time.local(2026, 9, 18, 10, 0, 0), functions) do
          assert_equal [t(:tc_title), t(:tc_name, :name => "Ayoub"), t(:tc_money, :n => 10), started(18, month, 2026)]
                         .join(". "),
                       PokeAccess::TrainerCardData.text, "with #{functions.keys.inspect}"
        end
      end
    end
  end

  test "the gen-6 card's summary closes with the start day too" do
    as_trainer(trainer(:name => "Ayoub", :money => 10)) do
      with_start(Time.local(2026, 9, 18, 10, 0, 0), :pbGetMonthName => lambda { |m| MONTHS[m] }) do
        assert_equal ["Ayoub", t(:tr_money, :n => 10), started(18, "Septiembre", 2026)].join(". "),
                     PokeAccess::TrainerCard.text
      end
    end
  end

  test "the gen-6 card's summary of a save with no start time is the summary alone" do
    as_trainer(trainer(:name => "Ayoub", :money => 10)) do
      assert_equal ["Ayoub", t(:tr_money, :n => 10)].join(". "), PokeAccess::TrainerCard.text
    end
  end

  test "the gen-6 card's summary with no trainer is nothing, start time or not" do
    as_trainer(nil) do
      with_start(Time.local(2026, 9, 18, 10, 0, 0), :pbGetMonthName => lambda { |m| MONTHS[m] }) do
        assert_nil PokeAccess::TrainerCard.text
      end
    end
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The card's start-day line for a date.
  def started(day, month, year)
    t(:tcard_started, :date => t(:tcard_date, :d => day, :m => month, :y => year))
  end

  # A trainer (or any engine object) answering only the given fields.
  def trainer(fields)
    who = Object.new
    fields.each { |name, value| who.define_singleton_method(name) { value } }
    who
  end

  # A Pokedex whose owned count raises, as one whose count takes an argument this engine does not pass.
  def failing_dex
    dex = trainer(:seen_count => 90)
    dex.define_singleton_method(:owned_count) { |region| region }
    dex
  end

  # Runs the block with who as the player the engine exposes ($Trainer on gen-6), the stub's put back after.
  def as_trainer(who)
    was = $Trainer
    $Trainer = who
    yield
  ensure
    $Trainer = was
  end

  # Runs the block with $stats counting secs of play time, or no $stats for nil, put back after.
  def with_stats(secs)
    was = $stats
    $stats = secs.nil? ? nil : trainer(:play_time => secs)
    yield
  ensure
    $stats = was
  end

  # Runs the block with Graphics counting frames frames since boot.
  def with_frames(frames)
    answering(Graphics, :frame_count, frames) { yield }
  end

  # Runs the block with the save started at time and the game's month-name functions as given.
  def with_start(time, functions)
    answering($PokemonGlobal, :startTime, time) { GameFunctions.with(functions) { yield } }
  end

  # Runs the block with obj's method name answering value, the one it had of its own (if any) put back after.
  def answering(obj, name, value)
    meta = obj.singleton_class
    had = meta.method_defined?(name, false) ? meta.instance_method(name) : nil
    meta.send(:define_method, name) { value }
    yield
  ensure
    if had
      meta.send(:define_method, name, had)
    else
      meta.send(:remove_method, name)
    end
  end
end
