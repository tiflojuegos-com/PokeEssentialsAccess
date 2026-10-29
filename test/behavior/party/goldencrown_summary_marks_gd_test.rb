# Golden Crown's summary marks (games/goldencrown/summary_marks.rb): the header says the Alpha, Noble and Totem
# symbols its edited summary paints, by the game's own checks (alpha?, isSpecies? on the forms it lists), after the
# marks core says.
class GoldencrownSummaryMarksGdTest < PokeAccessTest
  T = PokeAccess::I18n
  META = PokeAccess::Summary.singleton_class
  # A Pokemon as the header asks it: Alpha or not, the forms isSpecies? answers for, and shiny or not.
  Mon = Struct.new(:alpha, :forms, :shiny) do
    def alpha?; alpha; end
    def isSpecies?(form); forms.include?(form); end
    def shiny?; shiny; end
  end

  # Evaluates the profile file once, as boot does, and answers the header it puts on the summary; the one there before
  # is put back, with the lists of profiles and overrides, so the other tests of the process keep it.
  def self.load_profile
    header = META.instance_method(:header_icons)
    profiles = PokeAccess::Game.profiles.dup
    overrides = PokeAccess::Hooks.overrides.length
    path = File.join(Harness::ROOT, "games", "goldencrown", "summary_marks.rb")
    begin
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      META.instance_method(:header_icons)
    ensure
      META.send(:define_method, :header_icons, header)
      PokeAccess::Game.profiles.replace(profiles)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
    end
  end
  GC_HEADER = load_profile

  test "an Alpha Pokemon's header says the Alpha symbol after the shiny star" do
    assert_equal "#{T.t(:pk_shiny)}, #{T.t(:bt_m_alpha)}", header(Mon.new(true, [], true))
  end

  test "a Noble form and a Totem form say their symbols, each by the forms the summary checks" do
    assert_equal T.t(:bt_m_noble), header(Mon.new(false, [:KLEAVOR_1], false))
    assert_equal T.t(:bt_m_totem), header(Mon.new(false, [:MIMIKYU_2], false))
    assert_equal "", header(Mon.new(false, [:KLEAVOR], false)), "the base form paints none"
  end

  test "a Pokemon that answers none of the checks keeps the header as core says it" do
    pk = Object.new
    assert_equal PokeAccess::Summary.header_icons(pk), header(pk)
  end

  private

  # The header for pk with the profile's override in place of the one there, put back after.
  def header(pk)
    was = META.instance_method(:header_icons)
    META.send(:define_method, :header_icons, GC_HEADER)
    PokeAccess::Summary.header_icons(pk)
  ensure
    META.send(:define_method, :header_icons, was)
  end
end
