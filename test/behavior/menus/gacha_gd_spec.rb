# Magic Gachapon, gamedata pass: the buttons as the build paints them (through the game's _INTL) and, on changing
# banner, the three rewards it features with their stars, named from their pictures and kept for the info key.
GachaSpecBanner = Struct.new(:name, :rewards, :stars, :description)

Suite.define("gacha: the buttons as painted, and each banner's featured rewards") do
  t = PokeAccess::I18n
  gd = GameData::Species
  had = gd.respond_to?(:try_get)
  gd.define_singleton_method(:try_get) { |i| GameData::Species.get(i) } unless had
  begin
    eggs = GachaSpecBanner.new("- Banner Permanente Huevos -",
                               ["Graphics/Pokemon/Eggs/MUNCHLAX", "Graphics/Pokemon/Eggs/TINKATINK",
                                "Graphics/Pokemon/Eggs/GIMMIGHOUL"], [5, 5, 5], "Huevos.")
    items = GachaSpecBanner.new("- Banner Permanente Objetos -",
                                ["Graphics/Items/SUPERCAPSULE", "Graphics/Items/MASTERBALL", "Graphics/Items/MAXSOUP"],
                                [5, 4, 3], "Objetos.")
    blank = GachaSpecBanner.new("Banner", ["Graphics/GachaPj/nada"] * 3, [5, 5, 5], "")
    scn = World.stub_scene(:@sel => 1, :@banner_sel => 0, :@banners => [eggs, items, blank],
                           :@sprites => { "button5" => Object.new })
    egg = lambda { |sp| t.t(:gacha_egg, :name => GameData::Species.get(sp).name) }
    featured = t.t(:gacha_featured, :list => [:MUNCHLAX, :TINKATINK, :GIMMIGHOUL].map { |sp|
      t.t(:gacha_prize, :name => egg.call(sp), :n => 5) }.join("; "))
    gm = PokeAccess::MagicGachapon
    SpeakCapture.clear
    gm.refresh(scn)
    line = SpeakCapture.last.to_s
    truthy "the banner leads, with its place", line.index(t.t(:list_entry, :name => "- Banner Permanente Huevos -", :n => 1, :tot => 3)) == 0
    truthy "then the three eggs it features, each with its stars", line.include?(featured)
    truthy "then the focused button", line.include?(". Tirar x1")
    eq "the info key keeps the featured rewards", PokeAccess::Info.info_text, featured

    scn.instance_variable_set(:@banner_sel, 1)
    SpeakCapture.clear
    gm.refresh(scn)
    items_line = t.t(:gacha_featured, :list => [[:SUPERCAPSULE, 5], [:MASTERBALL, 4], [:MAXSOUP, 3]].map { |it, n|
      t.t(:gacha_prize, :name => GameData::Item.get(it).name, :n => n) }.join("; "))
    truthy "an item banner names its items", SpeakCapture.last.to_s.include?(items_line)

    scn.instance_variable_set(:@banner_sel, 2)
    SpeakCapture.clear
    gm.refresh(scn)
    truthy "a banner whose pictures name nothing says no featured line", !SpeakCapture.last.to_s.include?(t.t(:gacha_featured, :list => ""))
    eq "and leaves nothing on the info key", PokeAccess::Info.info_text, nil

    scn.instance_variable_set(:@sel, 3)
    with_intl("Ticket ULTRA" => "ULTRA Ticket") do
      SpeakCapture.clear
      gm.refresh(scn)
      eq "a button in the English build's words", SpeakCapture.last, "ULTRA Ticket"
    end
  ensure
    (class << gd; self; end).send(:remove_method, :try_get) unless had
  end
end
