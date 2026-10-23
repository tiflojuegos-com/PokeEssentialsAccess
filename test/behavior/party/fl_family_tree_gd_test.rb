# FL's Family Tree page (plugins/fl_family_tree.rb, :page_family): each parent by role, as the page writes it (name,
# species, sex sign), then the species of that parent's own parents, which the page draws only as icons.
class FlFamilyTreeGdTest < PokeAccessTest
  # A family member as the plugin keeps it: name, species, gender, and its own parents by index.
  Member = Struct.new(:name, :species, :gender, :father, :mother) do
    def [](i)
      i == 0 ? father : (i == 1 ? mother : nil)
    end
  end

  test "names each parent by role, then the parents the tree knows of each" do
    t = PokeAccess::I18n
    grand = Member.new("Pidgey", :PIDGEY, 1, nil, nil)
    father = Member.new("Bob", :PIDGEOTTO, 0, nil, grand)
    mother = Member.new(species_name(:RATTATA), :RATTATA, 1, nil, nil)
    text = PokeAccess::FamilyTree.page_text(pokemon_with(Member.new("Egg", :PIDGEY, 0, father, mother)))
    dad = "#{t.t(:ftree_father, :who => "Bob, #{species_name(:PIDGEOTTO)} #{PokeAccess::Party.sign(0)}")}; " \
          "#{t.t(:ftree_grandparents, :list => "#{t.t(:ftree_unknown)}, #{species_name(:PIDGEY)}")}"
    mom = t.t(:ftree_mother, :who => "#{species_name(:RATTATA)} #{PokeAccess::Party.sign(1)}")
    assert_equal PokeAccess.sentences([dad, mom]), text,
                 "a nickname before its species, a name equal to the species said once, no grandparents line without any"
  end

  test "a tree with no one known says both parents are unknown" do
    t = PokeAccess::I18n
    text = PokeAccess::FamilyTree.page_text(pokemon_with(Member.new("Egg", :PIDGEY, 0, nil, nil)))
    assert_equal PokeAccess.sentences([t.t(:ftree_father, :who => t.t(:ftree_unknown)),
                                       t.t(:ftree_mother, :who => t.t(:ftree_unknown))]), text
  end

  test "the summary's page text answers the family page only on a scene that draws it" do
    pk = pokemon_with(Member.new("Egg", :PIDGEY, 0, nil, nil))
    scene = World.stub_scene(:@page_id => :page_family, :@pokemon => pk)
    def scene.drawPageFamily; end
    assert_equal PokeAccess::FamilyTree.page_text(pk), PokeAccess::SummaryGameData.page_text(scene, 6)
    plain = World.stub_scene(:@page_id => :page_family, :@pokemon => pk)
    assert_nil PokeAccess::SummaryGameData.page_text(plain, 6), "another game's page of that id is left to the summary"
  end

  private

  # A Pokemon whose family is the given member's parents.
  def pokemon_with(member)
    pk = Poke.build(:name => "Pika")
    pk.define_singleton_method(:family) { member }
    pk
  end

  # The species name the mod says for an id.
  def species_name(id)
    PokeAccess::Data.species_name(id).to_s
  end
end
