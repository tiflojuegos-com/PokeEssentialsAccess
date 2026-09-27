# The MUI Data Page's species sub-lists (family, compatible species, those with an ability, item or move): every
# list ends in a Return cell, :RETURN, that no species resolves; the box beneath describes the focused species; and
# the stats box paints its six values beside their names before the total.

# GameData::Species as the game answers :RETURN: try_get finds nothing and get raises.
module DataListSpec
  def self.with_return
    k = (class << GameData::Species; self; end)
    had_try = k.method_defined?(:try_get)
    old_try = had_try ? GameData::Species.method(:try_get) : nil
    old_get = GameData::Species.method(:get)
    k.send(:define_method, :try_get) { |i| i == :RETURN ? nil : new(i) }
    k.send(:define_method, :get) { |i| raise ArgumentError, "no species #{i}" if i == :RETURN; new(i) }
    yield
  ensure
    k.send(:define_method, :get, old_get)
    had_try ? k.send(:define_method, :try_get, old_try) : k.send(:remove_method, :try_get)
  end
end

Suite.define("pokedex data page: the Return cell of a species list says the way back") do
  DataListSpec.with_return do
    pdx = PokeAccess::PokedexInfoV21
    scene = PokemonPokedexInfo_Scene.new
    list = [:BULBASAUR, :IVYSAUR, :RETURN]
    SpeakCapture.clear
    pdx.species_list_read(scene, list, 1, 0)
    spoke "a species cell names it", /\A#{Regexp.escape(PokeAccess::Data.species_name(:IVYSAUR))}/
    SpeakCapture.clear
    pdx.species_list_read(scene, list, 2, 0)
    spoke "the last cell is the way back", /\A#{Regexp.escape(PokeAccess::I18n.t(:back))}/
  end
end

Suite.define("pokedex data page: a species cell is read with the box beneath it and the page") do
  scene = PokemonPokedexInfo_Scene.new
  scene.instance_variable_set(:@list_paint, [["<c2=043c3aff>Evolution Method\nLevel 16</c2>", 34, 294]])
  list = (1..14).map { |n| "SP#{n}".to_sym } + [:RETURN]
  name = PokeAccess::Data.species_name(:SP1)
  page = PokeAccess::I18n.t(:pdx_list_page, :n => 1, :tot => 2)
  SpeakCapture.clear
  scene.pbChooseSpeciesDataList
  eq "the list's draw keeps its return value", scene.pbDrawSpeciesDataList(list, 0, 0, 1, :family), :list_drawn
  eq "the species, the page of several, then the box", SpeakCapture.lines,
     ["#{name}. #{page}. Evolution Method Level 16"]
  eq "the info key keeps species and box", PokeAccess::Info.info_text, "#{name}. Evolution Method Level 16"
  SpeakCapture.clear
  scene.pbDrawSpeciesDataList(list, 1, 0, 1, :family)
  eq "the next cell on the same page leaves the page out", SpeakCapture.lines,
     ["#{PokeAccess::Data.species_name(:SP2)}. Evolution Method Level 16"]
  SpeakCapture.clear
  scene.pbDrawSpeciesDataList(list, 0, 1, 1, :family)
  eq "turning the page says it", SpeakCapture.lines,
     ["#{PokeAccess::Data.species_name(:SP13)}. #{PokeAccess::I18n.t(:pdx_list_page, :n => 2, :tot => 2)}. " \
      "Evolution Method Level 16"]
  PokeAccess::Config.verbosity = :medium
  begin
    SpeakCapture.clear
    scene.pbDrawSpeciesDataList(list, 1, 1, 1, :family)
    eq "medium: the species alone", SpeakCapture.lines, [PokeAccess::Data.species_name(:SP14)]
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    scene.pbDrawSpeciesDataList(list, 0, 0, 1, :family)
    eq "brief: a turned page is not said either, as the positions reading promises", SpeakCapture.lines,
       [PokeAccess::Data.species_name(:SP1)]
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

Suite.define("pokedex data page: the stats box says the six values beside the total") do
  scene = PokemonPokedexInfo_Scene.new
  scene.instance_variable_set(:@notes_paint, [
    ["HP\nSpeed", 34, 324], [" 45\n 45", 128, 324], ["Attack\nDefense", 192, 324], [" 49\n 49", 286, 324],
    ["Sp. Atk\nSp. Def", 350, 324], [" 65\n 65", 444, 324], ["Base Stats - Total: 318", 34, 294]
  ])
  SpeakCapture.clear
  scene.pbDrawDataNotes(:stats)
  eq "the total, then each name with its value, as the box lays them out", SpeakCapture.lines,
     ["#{PokeAccess::I18n.t(:pdx_sec_stats)}. Base Stats - Total: 318. HP 45, Speed 45. Attack 49, Defense 49. " \
      "Sp. Atk 65, Sp. Def 65"]
  scene.instance_variable_set(:@notes_paint, [["General Statistics\nCapture Success Rate: 45%", 34, 294]])
  SpeakCapture.clear
  scene.pbDrawDataNotes(:general)
  eq "a section of one paragraph reads as before", SpeakCapture.lines,
     ["#{PokeAccess::I18n.t(:pdx_sec_general)}. General Statistics Capture Success Rate: 45%"]
end
