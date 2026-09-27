# Infinite Fusion's alternative sprites page: each sprite as which of how many, its painted artist and whether it is
# in use. The profile is loaded for this suite alone, its page_id override taken back after it.

# The sprite chooser's loop reduced to its exit, defined before the profile binds to it: a pick that closes the entry
# sets @endscene, as select_sprite does.
class PokemonPokedexInfo_Scene
  def pbChooseAlt(_brief = false)
    @endscene = true if @pick_closes
    nil
  end
end

Suite.define("infinite fusion: the sprites page says which sprite, its artist and whether it is in use") do
  meta = (class << PokeAccess::PokedexInfoV21; self; end)
  meta.send(:alias_method, :if_spec_page_id, :page_id)
  load File.expand_path("../../../games/infinitefusion_common/sprites_page.rb", File.dirname(__FILE__))
  plain = Object.new
  eq "page 3 is this page, left by the shared reader to its own", PokeAccess::PokedexInfoV21.page_id(plain, 3), :page_other
  eq "the other pages keep their names", PokeAccess::PokedexInfoV21.page_id(plain, 2), :page_area

  opened = PokemonPokedexInfo_Scene.new
  opened.instance_variable_set(:@available, %w[25 25a])
  opened.instance_variable_set(:@selected_index, 0)
  def opened.is_main_sprite; true; end
  opened.instance_variable_set(:@paint, lambda { pbDrawTextPositions(nil, [["Artista#1", 181, 324, 0, nil, nil]]) })
  PokeAccess::Cursor.changed?(opened, :pdx_page, "Species25. cat25 Pokemon.")
  SpeakCapture.clear
  eq "drawPage keeps its return", opened.drawPage(3), 3
  eq "arriving on the page, the shared reader forgets the page it said last, to say it again on the way back",
     PokeAccess::Cursor.current(opened, :pdx_page), nil
  eq "opening the page reads the sprite, and the shared reader adds nothing", SpeakCapture.lines,
     [[PokeAccess::I18n.t(:if_sprite_pos, :n => 1, :m => 2), "Artista#1", PokeAccess::I18n.t(:if_sprite_main)].join(", ")]
  SpeakCapture.clear
  opened.drawPage(3)
  silent "the page drawn again where it was, as the sprite chooser leaves it, says the same sprite no more"
  opened.instance_variable_set(:@species, :PICHU)
  opened.drawPage(3)
  eq "and a new species on it reads again, even the same line", SpeakCapture.lines.length, 1
  meta.send(:alias_method, :page_id, :if_spec_page_id)
  meta.send(:remove_method, :if_spec_page_id)
  scene = Object.new
  scene.instance_variable_set(:@available, %w[25 25a 25b])
  scene.instance_variable_set(:@selected_index, 1)
  def scene.is_main_sprite; @selected_index == 0; end
  sp = PokeAccess::IFSpritesPage
  eq "the second of three, by its painted artist", sp.text(scene, ["Artista#1234"]),
     [PokeAccess::I18n.t(:if_sprite_pos, :n => 2, :m => 3), "Artista#1234"].join(", ")
  scene.instance_variable_set(:@selected_index, 0)
  eq "the first is the one in use", sp.text(scene, ["Otro"]),
     [PokeAccess::I18n.t(:if_sprite_pos, :n => 1, :m => 3), "Otro", PokeAccess::I18n.t(:if_sprite_main)].join(", ")
  eq "a generated sprite paints no artist", sp.text(scene, []),
     [PokeAccess::I18n.t(:if_sprite_pos, :n => 1, :m => 3), PokeAccess::I18n.t(:if_sprite_main)].join(", ")

  rows = vb_levels { sp.text(scene, ["Otro"]) }
  eq "brief: which sprite it is and that it is in use", rows[0],
     [PokeAccess::I18n.t(:if_sprite_n, :n => 1), PokeAccess::I18n.t(:if_sprite_main)].join(", ")
  eq "medium: of how many", rows[1],
     [PokeAccess::I18n.t(:if_sprite_pos, :n => 1, :m => 3), PokeAccess::I18n.t(:if_sprite_main)].join(", ")
  eq "full: its artist as well", rows[2],
     [PokeAccess::I18n.t(:if_sprite_pos, :n => 1, :m => 3), "Otro", PokeAccess::I18n.t(:if_sprite_main)].join(", ")
  PokeAccess::Config.verbosity = :brief
  sp.text(scene, ["Otro"])
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole sprite at any level", PokeAccess::Info.info_text, rows[2]

  t = PokeAccess::I18n
  spr = Struct.new(:alt_letter)
  bl = Object.new
  bl.instance_variable_set(:@available, [spr.new(""), spr.new("a")])
  bl.instance_variable_set(:@selected_index, 1)
  bl.instance_variable_set(:@species, :PIKACHU)
  def bl.is_main_sprite; false; end
  Object.send(:define_method, :getSpecies) { |sp| Struct.new(:species).new(sp == :PIKACHU ? 25 : nil) }
  had = $PokemonSystem
  sys = Object.new
  def sys.sprites_blacklist; @bl ||= { 25 => ["a"] }; end
  begin
    $PokemonSystem = sys
    truthy "a sprite on the species' blacklist is said to be out of the random pick",
           sp.text(bl, []).include?(t.t(:if_sprite_excluded))
    SpeakCapture.clear
    sp.toggled(bl)
    eq "a toggle says the state the icon shows", SpeakCapture.lines, [t.t(:if_sprite_excluded)]
    sys.sprites_blacklist[25].clear
    SpeakCapture.clear
    sp.toggled(bl)
    eq "and back in", SpeakCapture.lines, [t.t(:if_sprite_allowed)]
  ensure
    $PokemonSystem = had
    Object.send(:remove_method, :getSpecies)
  end

  chooser = PokemonPokedexInfo_Scene.new
  SpeakCapture.clear
  chooser.pbChooseAlt
  eq "the confirm key's sprite chooser says left and right now change the sprite, and leaving it the entry is back",
     SpeakCapture.lines, [t.t(:if_sprite_choosing), t.t(:if_sprite_chosen)]
  chooser.instance_variable_set(:@pick_closes, true)
  SpeakCapture.clear
  chooser.pbChooseAlt
  eq "a pick that closes the whole entry leaves no entry to go back to", SpeakCapture.lines, [t.t(:if_sprite_choosing)]
end
