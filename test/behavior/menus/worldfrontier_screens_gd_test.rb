# World Frontier's own screens, gamedata pass (games/worldfrontier/): the pause menu, the trainer album and its card,
# the player's data hub, card and statistics, the island map, the starter teams, the Pokemon and Battle Point shops,
# the rental and swap screens, the battle roulette, the tournament bracket and the temple's item counter.

# The controls key its constants name lives in royal_common's controls reader, which another test evaluates.
module PokeAccess
  module RoyalControls
    class << self
      attr_accessor :key
    end
  end
end

# The pause menu as World Frontier edits it: its commands, the cursor and the bottom bar's cache of what it paints.
class WfPauseStandIn
  attr_writer :index
  def initialize(commands, cache); @commands = commands; @index = 0; @time_cache = cache; end
end

# The trainer album as far as its reader goes: the game's lookups over [WF] Album Entrenadores' trainers.
module AlbumEntrenadores
  def self.display_name(t); t.name; end
  def self.full_name(t); "#{t.name} (#{t.id})"; end
  def self.seen?(id); id != :NEW; end
  def self.seen_count(_gen); 1; end
  def self.total_count(_gen); 2; end
  def self.party_entries(t); t.team; end
  def self.party_icon_form(entry); entry[:form]; end
  def self.entry_mechanic(entry); entry[:mechanic]; end
  def self.monotype_of(_t); nil; end
  def self.battle_count(_id); 3; end
  def self.win_count(_id); 2; end
end

# The album's grid of one generation: the trainers, the cursor and the keys its footer names.
class AlbumEntrenadores_Scene
  def initialize(list); @list = list; @index = 0; @gen_index = 0; end
  def current_gen; @gen_index + 1; end
  def key_name(k); { :AUX1 => "Q", :AUX2 => "W", :USE => "C", :BACK => "X" }[k]; end
  def refresh; :grid; end
  def open_detail; :card; end
  def move(index, gen = @gen_index); @index = index; @gen_index = gen; refresh; end
end

# A trainer's card, over the same list.
class AlbumEntrenadores_DetailScene
  def initialize(list, index); @list = list; @index = index; end
  def key_name(_k); "X"; end
  def refresh; :card; end
end

# The data hub's two panels; back from a panel it shows its sprites again, then repaints.
class TarjetasHub_Scene
  def initialize; @index = 0; end
  def key_name(k); { :USE => "C", :BACK => "X" }[k]; end
  def refresh; :hub; end
  def show_after_child; :back; end
  def move(index); @index = index; refresh; end
end

# The player's card, painted label after label between its title and its footer.
class TarjetasPlayerCard_Scene
  def refresh
    pbDrawTextPositions(nil, [["TARJETA", 0, 0], ["Nombre", 0, 40], ["Rojo", 100, 40], ["Medallas", 0, 80],
                              ["8", 100, 80], ["[X]: Volver", 0, 300]])
    :card
  end
end

# The statistics: [label, value] rows, the first row in view and how many fit.
class TarjetasPlayerStats_Scene
  def initialize(lines, visible); @lines = lines; @scroll = 0; @layout = { :visible => visible }; end
  def key_name(_k); "X"; end
  def refresh; :stats; end
  def scroll_to(row); @scroll = row; refresh; end
end

# The island map: its places, the cursor, the player's dot and the help line painted under the list.
class IslaDesafioMapScene
  def initialize(locations); @locations = locations; @index = 0; end
  def player_marker; [10, 10]; end
  def help_text; "[C]: Ir   [X]: Salir"; end
  def pbRefresh; :map; end
  def show_loading; :loading; end
  def move(index); @index = index; pbRefresh; end
end

# The starter teams and their names.
module StarterTeams
  TEAMS = [[:PIKACHU, :EEVEE], [:CHARMANDER]]
  TEAM_NAMES = ["Equipo Voltio", "Equipo Llama"]
end

# A team member as the starter screen caches it.
StarterMember = Struct.new(:species, :form)

# The starter teams' list.
class StarterTeamSelector_Scene
  def initialize; @index = 0; end
  def get_cached_pokemon(i, j); StarterMember.new(StarterTeams::TEAMS[i][j], 0); end
  def pbRefresh; :teams; end
  def move(index); @index = index; pbRefresh; end
end

# The Pokemon shop's prices.
module PokemonShop
  def self.get_price(_species); 30; end
end

# The Pokemon shop: the species the search and order leave, the cursor, the order and the search typed; toggling the
# order (to the list given) keeps the cursor on its Pokemon, as pbToggleSortMode does.
class PokemonShop_Scene
  def initialize(list); @filtered_pokemon = list; @cursor_index = 0; @sort_mode = :pokedex; @search_text = ""; end
  def shop_species_label(species); "Nombre #{species}"; end
  def pbRefresh; :grid; end
  def pbSearch(text, list); @search_text = text; @filtered_pokemon = list; @cursor_index = 0; pbRefresh; :searched; end
  def move(index); @cursor_index = index; pbRefresh; end
  def toggle_sort(list)
    current = @filtered_pokemon[@cursor_index]
    @sort_mode = @sort_mode == :pokedex ? :alphabetical : :pokedex
    @filtered_pokemon = list
    @cursor_index = list.index(current) || 0
    pbRefresh
  end
end

# World Frontier's grid of the Battle Point shop, over the stub's scene.
class BattlePointShop_Scene
  def pbRefresh; :bpgrid; end
end

# The Battle Point shop's adapter, as far as the row goes.
class WfBpAdapter
  def getDisplayName(item); "Objeto #{item}"; end
  def getDisplayPrice(item, *_a); "#{item.to_s.length} PB"; end
end

# A rental or swap ball's Pokemon.
RentalMon = Struct.new(:speciesName, :species)

# The rental screen: the balls, the cursor and the balls chosen.
class RentalChooseScene
  def initialize(rentals); @rentals = rentals; @index = 0; @chosen = []; end
  def refresh_top_slots; :slots; end
  def pick(index, chosen); @index = index; @chosen = chosen; refresh_top_slots; end
end

# The swap screen: the phase, the player's balls and the rival's, a cursor on each.
class SwapChooseScene
  def initialize(mine, rivals); @my = mine; @rivals = rivals; @idx_mine = 0; @idx_rival = 0; @phase = :pick_mine; end
  def refresh_help_text; :help; end
  def update_cursor_position; :cursor; end
  def reset_blink; :blink; end
  def set_phase(phase); @phase = phase; refresh_help_text; update_cursor_position; :phased; end
  def mine_at(i); @idx_mine = i; update_cursor_position; end
end

# The battle roulette's overlay over the rule it lands on.
class BattleRouletteUI
  def initialize(rule); @chosen = { :name => rule }; end
  def draw_overlay(_mode); :overlay; end
end

# A tournament as the bracket shows it.
class WfTournament
  attr_reader :data, :eliminated
  def initialize(names, out); @names = names; @eliminated = out; @data = { :title => "Torneo Mundial" }; end
  def participant_count; @names.length; end
  def participant_name(i); @names[i]; end
  def round_label; "Semifinal"; end
end

# The bracket board, a function of its own.
module FrentePWTBracket
  def self.show(_pwt); :shown; end
end

# The temple's item counter.
module BattleTemple
  class RoomItemLabel
    def paint(_text); :painted; end
  end
end

controls_was = PokeAccess::RoyalControls.key
%w[constants pause_menu album player_cards island_map starter_team shops rental roulette pwt temple].each do |name|
  path = File.join(Harness::ROOT, "games", "worldfrontier", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end
WF_CONTROLS_KEY = PokeAccess::RoyalControls.key
PokeAccess::RoyalControls.key = controls_was

class WorldfrontierScreensGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  # A trainer of the album: id, name and team entries.
  Trainer = Struct.new(:id, :name, :team)
  # The player as far as the shop's header goes.
  Player = Struct.new(:battle_points)

  test "names its own transcription of the controls picture" do
    assert_equal :wf_controls, WF_CONTROLS_KEY
  end

  test "says a species with the name of the form its icon shows only where the form has one" do
    assert_equal "Species#{:PIKACHU}", PokeAccess::WfSpecies.name(:PIKACHU, 0)
    assert_equal "Species#{:PIKACHU}", PokeAccess::WfSpecies.name(:PIKACHU, 2)
  end

  test "the pause menu says its first command queued with the points, then each move cutting in" do
    scene = WfPauseStandIn.new(["Pokédex", "Equipo"], [nil, nil, "120 PB"])
    pause = PokeAccess::WfPauseMenu
    pause.watch(scene)
    pause.poll
    scene.index = 1
    pause.poll
    pause.poll
    pause.unwatch
    assert_equal [["Pokédex", false], ["120 PB", false], ["Equipo", true]], SpeakCapture.log
  end

  test "the album opens on its title, generation and count, then says each trainer as its cell paints it" do
    list = [Trainer.new(:ROJO, "Rojo", []), Trainer.new(:NEW, "Azul", [])]
    scene = AlbumEntrenadores_Scene.new(list)
    scene.refresh
    scene.move(1)
    head = "ÁLBUM DE ENTRENADORES. Gen. 1, 1/2"
    assert_equal [[head, false], [vb_entry("Rojo", 1, 2), false], [vb_entry("???", 2, 2), true]],
                 SpeakCapture.log.reject { |t, _i| t =~ /Generación/ }
  end

  test "the album's card says the trainer, the battles and the team, its title first" do
    list = [Trainer.new(:ROJO, "Rojo", [{ :species => :PIKACHU, :form => 0, :mechanic => :dynamax }])]
    AlbumEntrenadores_DetailScene.new(list, 0).refresh
    team = I18n.t(:wf_album_team, :list => "Species#{:PIKACHU}, #{I18n.t(:bt_m_dynamax)}")
    card = PokeAccess.sentences(["FICHA DE ENTRENADOR", "Rojo (ROJO)", PokeAccess::Verbosity.position(1, 1),
                                 "Enfrentamientos: 3   Victorias: 2", team])
    assert_equal PokeAccess.clean(card), SpeakCapture.lines.first.split(". Izq.").first
  end

  test "the album's card counts the silhouettes of a trainer never fought" do
    list = [Trainer.new(:NEW, "Azul", [{ :species => :EEVEE, :form => 0 }, { :species => :EEVEE, :form => 0 }])]
    AlbumEntrenadores_DetailScene.new(list, 0).refresh
    assert_spoken(/#{Regexp.escape(I18n.t(:wf_album_team_hidden, :n => 2))}/)
  end

  test "the data hub says its title and panel as it opens, each panel it moves to, and again after a panel" do
    hub = TarjetasHub_Scene.new
    hub.refresh
    hub.move(1)
    hub.show_after_child
    hub.refresh
    lines = SpeakCapture.lines
    assert_match(/\ADATOS DEL JUEGO\. #{Regexp.escape(vb_entry("MIS DATOS", 1, 2))}/, lines[0])
    assert_equal [vb_entry("ÁLBUM", 2, 2), vb_entry("ÁLBUM", 2, 2)], lines[1..2]
  end

  test "the player's card says each label with its value, and the keys" do
    TarjetasPlayerCard_Scene.new.refresh
    assert_equal ["TARJETA. Nombre: Rojo. Medallas: 8. [X]: Volver"], SpeakCapture.lines
  end

  test "the statistics say the rows in view, then the row each scroll brings in" do
    rows = [["Combates", "10"], ["Victorias", "7"], ["Pasos", "500"]]
    stats = TarjetasPlayerStats_Scene.new(rows, 2)
    stats.refresh
    stats.scroll_to(1)
    stats.scroll_to(0)
    assert_match(/\AESTADÍSTICAS\. Combates: 10\. Victorias: 7/, SpeakCapture.lines[0])
    assert_equal [vb_entry("Pasos: 500", 3, 3), vb_entry("Combates: 10", 1, 3)], SpeakCapture.lines[1..2]
  end

  test "the island map says each place with how far it lies from the player's dot" do
    places = [{ :name => "Torre", :x => 12, :y => 7, :desc => "Una torre." }, { :name => "Dojo", :x => 10, :y => 10 }]
    map = IslaDesafioMapScene.new(places)
    map.show_loading
    map.pbRefresh
    map.move(1)
    torre = "#{vb_entry('Torre', 1, 2)}, #{PokeAccess::Locator.dir_phrase(2, -3)}"
    assert_equal "Abriendo el mapa de la isla...", SpeakCapture.lines[0]
    assert_match(/\AIsla Desafío\. #{Regexp.escape(torre)}/, SpeakCapture.lines[1])
    assert_equal "#{vb_entry('Dojo', 2, 2)}, #{I18n.t(:loc_here)}", SpeakCapture.lines[2]
  end

  test "the starter teams say each team with its Pokemon, the title first" do
    teams = StarterTeamSelector_Scene.new
    teams.pbRefresh
    teams.move(1)
    first = "ELIGE TU EQUIPO INICIAL. #{vb_entry('Equipo Voltio', 1, 2)}: Species#{:PIKACHU}, Species#{:EEVEE}"
    assert_equal [[first, false], ["#{vb_entry('Equipo Llama', 2, 2)}: Species#{:CHARMANDER}", true]], SpeakCapture.log
  end

  test "the Pokemon shop opens on its header, says each Pokemon with its price, and the search it ends on" do
    with_player(Player.new(45)) do
      shop = PokemonShop_Scene.new([:PIKACHU, :EEVEE])
      shop.pbRefresh
      shop.move(1)
      shop.pbSearch("pika", [])
    end
    lines = SpeakCapture.lines
    assert_equal ["TIENDA DE POKÉMON. PB: 45. Orden: Nº Dex.", vb_entry("Nombre PIKACHU, PB: 30", 1, 2)], lines[0..1]
    assert_equal [vb_entry("Nombre EEVEE, PB: 30", 2, 2), "Buscar: pika", I18n.t(:wf_shop_empty)], lines[-3..-1]
  end

  test "toggling the Pokemon shop's order says the new order, then the Pokemon the cursor follows, queued" do
    with_player(Player.new(45)) do
      shop = PokemonShop_Scene.new([:BULBASAUR, :PIKACHU, :EEVEE])
      shop.pbRefresh
      shop.move(1)
      SpeakCapture.clear
      shop.toggle_sort([:BULBASAUR, :EEVEE, :PIKACHU])
      shop.move(0)
      shop.toggle_sort([:BULBASAUR, :PIKACHU, :EEVEE])
    end
    bulbasaur = vb_entry("Nombre BULBASAUR, PB: 30", 1, 3)
    assert_equal [["Orden: Alfab.", true], [vb_entry("Nombre PIKACHU, PB: 30", 3, 3), false], [bulbasaur, true],
                  ["Orden: Nº Dex.", true], [bulbasaur, false]], SpeakCapture.log
  end

  test "the Battle Point shop's grid says the focused item with its price and the exit cell" do
    shop = BattlePointShop_Scene.new
    shop.instance_variable_set(:@stock, [:PROTEIN, :ZINC])
    shop.instance_variable_set(:@adapter, WfBpAdapter.new)
    [0, 2].each do |i|
      shop.instance_variable_set(:@grid_cursor_index, i)
      shop.pbRefresh
    end
    assert_equal [vb_entry("Objeto PROTEIN, 7 PB", 1, 3), vb_entry(I18n.t(:pc_cancel), 3, 3)], SpeakCapture.lines
  end

  test "the rental screen says how many Pokemon are left to choose and the focused ball, chosen or not" do
    rental = RentalChooseScene.new([RentalMon.new("Pikachu", :PIKACHU), RentalMon.new("Eevee", :EEVEE)])
    rental.refresh_top_slots
    rental.pick(0, [0])
    pick = [["Elige 3 Pokémon para combatir.", false], [vb_entry("Pikachu", 1, 2), false],
            ["Elige 2 Pokémon para combatir.", true], [vb_entry("Pikachu, #{I18n.t(:swap_chosen)}", 1, 2), false]]
    assert_equal pick, SpeakCapture.log
  end

  test "the swap screen says its instruction per phase and the ball focused in each" do
    swap = SwapChooseScene.new([RentalMon.new("Pikachu", :PIKACHU)], [RentalMon.new("Onix", :ONIX)])
    swap.refresh_help_text
    swap.update_cursor_position
    swap.set_phase(:pick_rival)
    rival = "Elige uno de los Pokémon rivales para llevártelo."
    assert_equal [["Elige el Pokémon de tu equipo que será cambiado.", false], [vb_entry("Pikachu", 1, 1), false],
                  [rival, true], [vb_entry("Onix", 1, 1), false]], SpeakCapture.log
  end

  test "the roulette says its lead line while it spins and the rule it lands on, with the keys" do
    ui = BattleRouletteUI.new("Combate inverso")
    ui.draw_overlay(:spinning)
    ui.draw_overlay(:announce)
    skip_key = PokeAccess::KeyHints.localize("X para saltar", nil, true)
    go_on = PokeAccess::KeyHints.localize("Pulsa C para continuar", nil, true)
    assert_equal [["La regla del combate es... #{skip_key}", false], ["¡Combate inverso! #{go_on}", true]], SpeakCapture.log
  end

  test "the bracket says the tournament, its round, who is in and who is out" do
    FrentePWTBracket.show(WfTournament.new(%w[Rojo Azul Verde], [false, true, false]))
    board = PokeAccess.sentences(["Torneo Mundial", "Semifinal", I18n.t(:wf_pwt_in, :list => "Rojo, Verde"),
                                  I18n.t(:wf_pwt_out, :list => "Azul")])
    assert_equal [[board, true]], SpeakCapture.log
  end

  test "the temple says its room's item counter each time it is repainted" do
    BattleTemple::RoomItemLabel.new.paint("Objetos de la sala: 1/3")
    assert_equal [["Objetos de la sala: 1/3", false]], SpeakCapture.log
  end

  private

  # A list row with its place, as the verbosity in use says it.
  def vb_entry(name, n, tot)
    PokeAccess::Verbosity.list_entry(name, n, tot)
  end

  # Runs the block with the player as given, put back after.
  def with_player(player)
    was = $player
    $player = player
    yield
  ensure
    $player = was
  end
end
