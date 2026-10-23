# Sevii's move detail (games/sevii/summary.rb): the contest category its icon shows under each move's type, found by
# the move's name as the page finds it. Only the profile's module is evaluated: its override of the move line belongs
# to the Sevii process. The categories are the contests reader's, whose module is evaluated if no test did.
unless defined?(PokeAccess::SeviiContests)
  sevii_contests_path = File.join(Harness::ROOT, "games", "sevii", "contests.rb")
  eval(Harness.source(sevii_contests_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, sevii_contests_path)
end
sevii_summary_path = File.join(Harness::ROOT, "games", "sevii", "summary.rb")
eval(Harness.source(sevii_summary_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, sevii_summary_path)

class SeviiSummaryTest < PokeAccessTest
  T = PokeAccess::I18n

  # The contest moves the game compiles, named after the battle move of their number; two share a name.
  module ContestMovesStandIn
    NAMES = { 33 => "Placaje", 40 => "Picotazo", 52 => "Picotazo" }
    def self.maxValue; 60; end
    def self.getName(id); NAMES[id] || ""; end
  end

  # A contest move's data as contestmoves.dat keeps it, its category first.
  class ContestMoveDataStandIn
    TYPES = { 33 => 4, 40 => 1, 52 => 3 }
    attr_reader :contestType
    def initialize(id); @contestType = TYPES[id] || 0; end
  end

  test "a summary move's note is the contest category its icon shows" do
    with_contest_data do
      assert_equal T.t(:if2_ct_category, :t => T.t(:cnd_tough)), PokeAccess::SeviiSummary.type_note(:summary_move, "Placaje")
    end
  end

  test "takes the first contest move of the name, as the page's own loop does: a match turns its name into a number" do
    with_contest_data do
      assert_equal T.t(:if2_ct_category, :t => T.t(:cnd_beauty)), PokeAccess::SeviiSummary.type_note(:summary_move, "Picotazo")
    end
  end

  test "gives no note to another reading, a name with no contest move, or no name" do
    with_contest_data do
      assert_nil PokeAccess::SeviiSummary.type_note(:battle_move, "Placaje")
      assert_nil PokeAccess::SeviiSummary.type_note(:summary_move, "Surf")
      assert_nil PokeAccess::SeviiSummary.type_note(:summary_move, nil)
    end
  end

  test "the move line says the note right after the type" do
    with_contest_data do
      note = PokeAccess::SeviiSummary.type_note(:summary_move, "Placaje")
      line = PokeAccess::MoveInfo.line("Placaje", "Normal", 40, 100, :note => note, :cat => T.t(:cat_physical))
      assert_equal ["Placaje", T.t(:mv_type, :t => "Normal"), note, T.t(:cat_physical), T.t(:mv_power, :p => "40"),
                    T.t(:mv_acc, :a => 100)].join(". "), line
    end
  end

  private

  # Runs the block with the stand-ins under the game's names, the classes there put back after.
  def with_contest_data
    swaps = { :PBContestMoves => ContestMovesStandIn, :PBContestMoveData => ContestMoveDataStandIn }
    priors = swaps.keys.map { |n| [n, Object.const_defined?(n) ? Object.send(:remove_const, n) : nil] }
    swaps.each { |n, k| Object.const_set(n, k) }
    yield
  ensure
    swaps.each_key { |n| Object.send(:remove_const, n) if Object.const_defined?(n) }
    (priors || []).each { |n, k| Object.const_set(n, k) if k }
  end
end
