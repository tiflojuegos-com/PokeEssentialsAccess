# The info key's builders on the gen-6 engine (core/field/contextual.rb): a Pokemon's data sheet and its glance line, a
# move's line from the data, and the trainer line from $Trainer.
class ContextualInfoTest < PokeAccessTest
  Info = PokeAccess::Info

  test "the data sheet says name and sign, level, species, nature, ability, item, stats and trainer lines" do
    pk = bulba(:item => 5)
    def pk.ot; "Ayoub"; end
    def pk.publicID; 42; end
    def pk.exp; 1250; end
    t = PokeAccess::I18n
    trainer = [t.t(:sum_ot, :name => "Ayoub"), t.t(:sum_id, :id => "00042"), t.t(:sum_exp, :n => 1250)]
    assert_equal sheet(:item => "Item5", :trainer => trainer), Info.summary_text(pk)
  end

  test "the data sheet of a Pokemon holding nothing, with no original trainer, says no item, on loan and ID unknown" do
    assert_equal sheet, Info.summary_text(bulba)
  end

  test "the data sheet says the Pokedex number after the name when the screen gives one" do
    assert_equal sheet(:after_name => PokeAccess::I18n.t(:sum_dex, :n => 25)), Info.summary_text(bulba, 25)
  end

  test "the data sheet says the types after the species where the data knows them" do
    pk = bulba
    def pk.type1; 3; end
    def pk.type2; 4; end
    assert_equal sheet(:types => "Tipo3 Tipo4"), Info.summary_text(pk)
  end

  test "the data sheet says the header's icons after the name" do
    assert_equal sheet(:after_name => "#{PokeAccess::I18n.t(:pk_shiny)}."), Info.summary_text(bulba(:shiny => true))
  end

  test "the data sheet keeps the rest when the stats cannot be read" do
    pk = bulba
    def pk.spdef; raise "sin estadística"; end
    assert_equal sheet(:stats => false), Info.summary_text(pk).squeeze(" "), "as spoken, its spaces collapsed"
  end

  test "no Pokemon has no data sheet, nor one that breaks it" do
    broken = bulba
    def broken.species; raise "sin especie"; end
    assert_nil Info.summary_text(nil), "nil"
    assert_nil Info.summary_text(broken), "a Pokemon whose species raises"
  end

  test "the glance says name, level and HP" do
    pk = Poke.build(:name => "Char", :level => 30, :hp => 50, :totalhp => 70, :item => 0, :status => 0, :gender => nil)
    assert_equal PokeAccess::I18n.t(:pk_glance, :name => "Char", :level => 30, :hp => 50, :tot => 70),
                 Info.pokemon_info(pk)
  end

  test "the glance says the Exp. Share mark the member's panel draws, then the sex sign" do
    pk = Poke.build(:name => "Pika", :level => 12)
    pk.define_singleton_method(:expshare) { true }
    assert_equal "#{pika_glance} #{PokeAccess::I18n.t(:pty_expshare)}. ♂.", Info.pokemon_info(pk)
  end

  test "the glance says the item held, by its own name or the data's" do
    { 5 => "Item5", Struct.new(:name).new("Restos") => "Restos", :LEFTOVERS => "ItemLEFTOVERS" }.each do |item, name|
      pk = Poke.build(:name => "Pika", :level => 12, :item => item)
      assert_equal "#{pika_glance} ♂. #{PokeAccess::I18n.t(:pk_holds, :item => name)}.", Info.pokemon_info(pk),
                   "holding #{item.inspect}"
    end
  end

  test "the glance says no item held when its name is blank" do
    pk = Poke.build(:name => "Pika", :level => 12, :item => Struct.new(:name).new(""))
    assert_equal "#{pika_glance} ♂.", Info.pokemon_info(pk)
  end

  test "the glance says the status, and nothing for none" do
    { 1 => " #{PokeAccess::I18n.t(:st_sleep)}.", 0 => "", nil => "", :NONE => "" }.each do |status, said|
      pk = Poke.build(:name => "Pika", :level => 12, :status => status)
      assert_equal "#{pika_glance} ♂.#{said}", Info.pokemon_info(pk), "status #{status.inspect}"
    end
  end

  test "the glance of an egg is only that it is an egg" do
    egg = Poke.build(:name => "Huevo")
    def egg.egg?; true; end
    def egg.isEgg?; true; end
    assert_equal PokeAccess::I18n.t(:pty_egg), Info.pokemon_info(egg)
  end

  test "no Pokemon has no glance" do
    assert_nil Info.pokemon_info(nil)
  end

  test "a move known by its id takes its name, type, category, power and accuracy from the data" do
    assert_equal mov7_line, Info.move_info(id_move(7))
  end

  test "a move whose own name is blank is named by the data" do
    move = id_move(7)
    def move.name; ""; end
    assert_equal mov7_line, Info.move_info(move)
  end

  test "no move has no line" do
    assert_nil Info.move_info(nil)
  end

  test "a move picked by id from the Pokemon's moves is described from it and kept for the info key" do
    pk = Poke.build(:moves => [nil, id_move(3), id_move(7)])
    assert_equal mov7_line, Info.move_by_id_info(pk, 7)
    assert_equal mov7_line, Info.info_text
  end

  test "a move by id the Pokemon does not know is described through the game's PBMove, and kept" do
    Object.const_set(:PBMove, Struct.new(:id))
    pk = Poke.build(:moves => [id_move(3)])
    assert_equal mov7_line, Info.move_by_id_info(pk, 7)
    assert_equal mov7_line, Info.info_text
  ensure
    Object.send(:remove_const, :PBMove) if Object.const_defined?(:PBMove)
  end

  test "a move by id with no PBMove to build is only named" do
    assert_equal "Mov7", Info.move_by_id_info(Poke.build(:moves => []), 7)
    assert_nil Info.info_text, "and nothing is kept for the info key"
  end

  test "no move id, or id 0, has no line" do
    assert_equal [nil, nil], [Info.move_info_by_id(nil), Info.move_info_by_id(0)]
  end

  test "the trainer line reads $Trainer: name, money and badges" do
    assert_equal trainer_line, Info.trainer_info
  end

  test "the trainer line adds the Pokedex tally once the trainer has the Pokedex" do
    def $Trainer.pokedex; true; end
    assert_equal "#{trainer_line}. #{PokeAccess::I18n.t(:tr_pokedex, :owned => 12, :seen => 30)}", Info.trainer_info
  ensure
    $Trainer.singleton_class.send(:remove_method, :pokedex)
  end

  private

  # A gen-6 Pokemon with every stat apart, changed by opts.
  def bulba(opts = {})
    Poke.build({ :name => "Bulba", :species => 1, :level => 12, :hp => 30, :totalhp => 44, :attack => 20,
                 :defense => 18, :spatk => 22, :spdef => 16, :speed => 25 }.merge(opts))
  end

  # The data sheet of bulba: name and sign at level 12, what the screen adds after them (:after_name), the species,
  # the types if given (:types), nature and ability from the gen-6 data, the item held (:item, none by default), the
  # six stats unless :stats is false, then the trainer lines (:trainer, by default those of a Pokemon with no original
  # trainer: on loan, its ID unknown).
  def sheet(opts = {})
    t = PokeAccess::I18n
    parts = [t.t(:sum_data_of, :name => "Bulba ♂", :level => 12), opts[:after_name]]
    parts.push(t.t(:sum_species, :s => "Especie1"))
    parts.push(t.t(:sum_type, :t => opts[:types])) if opts[:types]
    parts.push(t.t(:sum_nature, :n => "Naturaleza0"), t.t(:sum_ability, :a => "Habilidad1"),
               t.t(:sum_item, :i => opts[:item] || t.t(:sum_none)))
    six = t.t(:sum_stats, :hp => 30, :tot => 44, :atk => 20, :def => 18, :spa => 22, :spd => 16, :spe => 25)
    parts.push(six) unless opts[:stats] == false
    lent = [t.t(:sum_ot, :name => t.t(:sum_loaned)), t.t(:sum_id, :id => t.t(:pdx_unknown_short))]
    parts.concat(opts[:trainer] || lent)
    parts.compact.join(" ")
  end

  # The glance's opening for the default Pika: name, level 12 and 40 of 40 HP.
  def pika_glance
    PokeAccess::I18n.t(:pk_glance, :name => "Pika", :level => 12, :hp => 40, :tot => 40)
  end

  # The line of move 7 as the gen-6 data describes it.
  def mov7_line
    t = PokeAccess::I18n
    ["Mov7", t.t(:mv_type, :t => "Tipo2"), t.t(:cat_special), t.t(:mv_power, :p => 47),
     t.t(:mv_acc, :a => 100)].join(". ")
  end

  # The trainer line of the gen-6 $Trainer: name, money and badges.
  def trainer_line
    ["Ayoub", PokeAccess::I18n.t(:tr_money, :n => 3000), PokeAccess::I18n.t(:tr_badges, :n => 0)].join(". ")
  end

  # A move object that only knows its id, as a screen holding a bare id hands it.
  def id_move(id)
    move = Object.new
    move.define_singleton_method(:id) { id }
    move
  end
end
