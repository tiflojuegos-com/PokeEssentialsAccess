# FL's v16 Advanced Pokedex (plugins/advanced_pokedex_v16.rb) as Essentials BES paints it: a page is its painted rows in
# paint order, each column top to bottom, after its place among the pages; the opening is the species, its types and the
# first page. How the hooks bind and speak is tested with Desolation's copy (rv_screens_test); these are the texts.
class AdvancedPokedexV16Test < PokeAccessTest
  T = PokeAccess::I18n
  # The first info page of BES's entry for Bulbasaur: its stats table as two painted rows, the lines around it.
  INFO_ROWS = ["Ratio de captura: 45", "Amistad base: 70", "Exp. Base: 64", "Crecimiento: Parabólico (1059860)",
               "Sexo: Machos 87.5%", "                        PS    ATQ  DEF  VEL  AT.E DF.E    TOTAL",
               "Stats Base:       045  049  049  045  065  065     318", "P. de Esfuerzo:     000  000  000  000  001  000"].freeze
  MOVE_ROWS = ["Movimientos por Nivel:", "01 Placaje", "03 Gruñido", "07 Drenadoras"].freeze

  test "a page reads its painted rows in paint order, after its place in the entry" do
    scene = World.stub_scene(:page => 1, :totalPages => 6)
    want = "#{place(1, 6)}. " + INFO_ROWS.map { |r| r.strip.gsub(/\s+/, " ") }.join(". ")
    assert_equal want, squeeze(PokeAccess::AdvancedPokedexV16.page_text(scene, INFO_ROWS))
  end

  test "a move list reads its title, then each move" do
    scene = World.stub_scene(:page => 4, :totalPages => 6)
    assert_equal "#{place(4, 6)}. Movimientos por Nivel: 01 Placaje. 03 Gruñido. 07 Drenadoras",
                 squeeze(PokeAccess::AdvancedPokedexV16.page_text(scene, MOVE_ROWS))
  end

  test "the only page of an entry has its place too" do
    scene = World.stub_scene(:page => 1, :totalPages => 1)
    assert_equal "#{place(1, 1)}. Placaje", PokeAccess::AdvancedPokedexV16.page_text(scene, ["Placaje"])
  end

  test "a page of an entry with no pages has no place" do
    scene = World.stub_scene(:page => 1, :totalPages => 0)
    assert_equal "Placaje", PokeAccess::AdvancedPokedexV16.page_text(scene, ["Placaje"])
  end

  test "brief verbosity leaves the place out" do
    scene = World.stub_scene(:page => 2, :totalPages => 6)
    assert_equal ["Placaje", "#{place(2, 6)}. Placaje", "#{place(2, 6)}. Placaje"],
                 vb_levels { PokeAccess::AdvancedPokedexV16.page_text(scene, ["Placaje"]) }
  end

  test "an entry opens with the species, its types and the page painted as it opened" do
    scene = World.stub_scene(:species => 1, :type1 => 11, :type2 => 3, :access_page => "primera pagina")
    assert_equal "#{PokeAccess::Data.species_name(1)}. #{T.t(:pdx_type, :t => 'Tipo11/Tipo3')}. primera pagina",
                 PokeAccess::AdvancedPokedexV16.opening(scene)
  end

  test "an entry of one type says it once" do
    scene = World.stub_scene(:species => 1, :type1 => 11, :type2 => 11, :access_page => "primera pagina")
    assert_equal "#{PokeAccess::Data.species_name(1)}. #{T.t(:pdx_type, :t => 'Tipo11')}. primera pagina",
                 PokeAccess::AdvancedPokedexV16.opening(scene)
  end

  test "an entry not caught opens with that it is not caught, as it paints no page" do
    scene = World.stub_scene(:species => 1, :type1 => 11, :type2 => 3)
    assert_equal "#{PokeAccess::Data.species_name(1)}. #{T.t(:pdx_type, :t => 'Tipo11/Tipo3')}. #{T.t(:pdx_not_caught)}",
                 PokeAccess::AdvancedPokedexV16.opening(scene)
  end

  private

  def place(n, total)
    T.t(:adv_dex_page, :n => n, :m => total)
  end

  def squeeze(text)
    text.gsub(/\s+/, " ")
  end
end
