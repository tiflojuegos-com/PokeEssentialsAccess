# Awakening's diary, talisman screen, ball picker and character glossary (games/awakening/glossary.rb and
# fates_screens.rb) through their hooks, on stand-ins of the game's classes defined before both files load.

# Scene_Glosario, the diary's tab menu: main paints the tabs (refresh) and runs one frame, then one more per step of
# @steps, each a cursor move (the index it lands on, repainted), :tab (a tab opened and closed back onto the menu,
# repainted) or :idle (a frame with no input).
class Scene_Glosario
  def initialize(steps = []); @commands = ["Historia", "Personajes"]; @index = 0; @steps = steps; end

  def main
    refresh
    PokeAccess::Frame.run_pollers
    @steps.each do |step|
      @index = step if step.is_a?(Integer)
      refresh unless step == :idle
      PokeAccess::Frame.run_pollers
    end
    :closed
  end

  def refresh; :refreshed; end
end

# Glosario_Historia, the story's chapter list: draw_commands paints each row of @commands ([text, unlocked, sym], a
# locked chapter as dashes) and puts the arrow on @index through update_cursor, which update also calls on each arrow.
class Glosario_Historia
  def initialize(commands, index = 0); @commands = commands; @index = index; end

  def draw_commands
    @commands.each { |row| pbDrawOutlineText(nil, 60, 80, 200, 32, Array(row).first) }
    update_cursor
    :drawn
  end

  def update_cursor; :moved; end
end

# Glosario_Historia_Secciones, a chapter's sections: a paged list (@nombres_secciones, @index on page @pagina_actual of
# @total_paginas, a locked row painted as dashes) that mover_cursor redraws, and mostrar_texto, the text's loop, which
# hides @cursor and paints on each frame of @frames, a [section, page], the section's title, its text and its
# "Página n/m" stamp, then redraws the list as it closes.
class Glosario_Historia_Secciones
  OPCIONES_POR_PAGINA = 4
  TRADUCCIONES_NOMBRES = { "Despertar" => "El despertar" }

  def initialize(ivars = {})
    @index = 0
    @pagina_actual = 0
    @total_paginas = 1
    @frames = []
    @cursor = Struct.new(:visible).new(true)
    ivars.each { |k, v| instance_variable_set(k, v) }
  end

  def mover_cursor(_direccion)
    dibujar_lista
    :moved
  end

  def dibujar_lista
    (@nombres_secciones[@pagina_actual * OPCIONES_POR_PAGINA, OPCIONES_POR_PAGINA] || []).each do |name|
      shown = glosario_historia[name.downcase.gsub(/\s+/, "").to_sym] ? (TRADUCCIONES_NOMBRES[name] || name) : "------"
      pbDrawOutlineText(nil, 40, 80, 240, 32, shown)
    end
    pbDrawOutlineText(nil, 480, 448, 150, 32, "Página #{@pagina_actual + 1}/#{@total_paginas}")
    :drawn
  end

  def mostrar_texto(_nombre)
    @cursor.visible = false
    @frames.each do |name, page|
      pages = @secciones[name]
      pbDrawOutlineText(nil, 40, 70, 432, 32, TRADUCCIONES_NOMBRES[name] || name)
      pbDrawOutlineText(nil, 40, 120, 432, 32, pages[page])
      pbDrawOutlineText(nil, 480, 448, 150, 32, "Página #{page + 1}/#{pages.length}")
    end
    dibujar_lista
    @cursor.visible = true
    :shown
  end

  private

  def glosario_historia; @historia || {}; end
end

# EquipScreen as its loop leaves the ivars the readers inspect: @talismans, @selected_index and the lore's
# @info_scroll; its lore window draws once as it opens.
class EquipScreen
  def initialize(talismans, index = 0)
    @talismans = talismans
    @selected_index = index
    @info_scroll = 0
  end

  def update_description; :described; end
  def main_loop; :looped; end
  def open_lore_window; update_lore_window; :opened; end
  def update_lore_window; :scrolled; end
  def pbEndScreen; :ended; end
  def unlocked?(_symbol); true; end

  private

  def selected_talisman; @talismans[@selected_index]; end
end

# BallSelectorInterface, the in-battle ball picker: @ball_list, @ball_counts and the focused @index.
class BallSelectorInterface
  def initialize(balls, counts, index = 0); @ball_list = balls; @ball_counts = counts; @index = index; end
  def update_display; :shown; end
end

# Glosario_Personajes, the character glossary: a paged list (@nombres_secciones, @index on page @pagina_actual of
# @total_paginas) whose biography loop, mostrar_texto, hides the list's overlay and paints on each frame the page's
# "Página n/m" stamp (@frames[name] lists the page of each frame, or [:next, name] to move on to that character), then
# shows the list again and redraws it with its own stamp.
class Glosario_Personajes
  OPCIONES_POR_PAGINA = 4
  TRADUCCIONES_PERSONAJES = { "Persefone" => "Perséfone" }

  def initialize(ivars = {})
    @index = 0
    @pagina_actual = 0
    @total_paginas = 1
    @overlay = Struct.new(:visible).new(true)
    ivars.each { |k, v| instance_variable_set(k, v) }
  end

  def mover_cursor(_direccion); :moved; end

  def dibujar_lista
    pbDrawOutlineText(nil, 352, 352, 150, 32, "Página #{@pagina_actual + 1}/#{@total_paginas}")
    :drawn
  end

  def mostrar_texto(nombre, _pagina_inicial = 0)
    pages = @secciones[nombre]["text"]
    @overlay.visible = false
    (@frames[nombre] || []).each do |frame|
      if frame.is_a?(Array)
        mostrar_texto(frame[1])
        break
      end
      pbDrawOutlineText(nil, 352, 352, 150, 32, "Página #{frame + 1}/#{pages.length}")
    end
    @overlay.visible = true
    dibujar_lista
    :shown
  end

  private

  def glosario_historia; @historia || {}; end
end

%w[glossary fates_screens].each do |name|
  path = File.join(Harness::ROOT, "games", "awakening", "#{name}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class AwakeningEquipTest < PokeAccessTest
  T = PokeAccess::I18n
  CHAPTERS = [["Prólogo", true, :prologo], ["Capítulo 1", true, :cap1], ["--------", false, :cap2], "Epílogo"]
  SECTIONS = ["Despertar", "La caida", "Pacto", "Eclipse", "Alba"]
  SECTION_TEXTS = { "Despertar" => ["Despierta en el bosque.", "Sigue el río."], "La caida" => ["Cae la noche."],
                    "Pacto" => ["Se sella el pacto."] }
  UNLOCKED_SECTIONS = { :despertar => true, :lacaida => true, :pacto => true, :alba => true }
  SUN = { :id => 7, :name => "Talismán del Sol", :symbol => :sol, :description => "Da fuerza.",
          :lore => "Forjado al alba." }
  MOON = { :id => 1, :name => "Talismán de la Luna", :symbol => :luna, :description => "Da calma." }
  CHARACTERS = ["Holly", "Persefone", "Ares", "Liam", "Lana"]
  BIOS = { "Holly" => { "text" => ["siblingA y Holly.", "Segunda."], "afinidad" => "Neutral",
                        "localidad" => "Verbena" },
           "Liam" => { "text" => ["Hermano."], "afinidad" => "", "localidad" => "Pueblo" } }

  test "the diary's tab menu says its focus as it opens, queued" do
    Scene_Glosario.new.main
    assert_equal [["Historia", false]], SpeakCapture.log
  end

  test "the diary's tab menu says the tab the cursor lands on" do
    Scene_Glosario.new([1]).main
    assert_equal [["Historia", false], ["Personajes", true]], SpeakCapture.log
  end

  test "the diary's tab menu says nothing more on a frame with no input" do
    Scene_Glosario.new([:idle, :idle]).main
    assert_equal [["Historia", false]], SpeakCapture.log
  end

  test "the diary's tab menu says its focus again once a tab closes back onto it" do
    Scene_Glosario.new([:tab]).main
    assert_equal [["Historia", false], ["Historia", true]], SpeakCapture.log
  end

  test "the diary's tab menu says nothing for a cursor off its tabs" do
    Scene_Glosario.new([2, -1]).main
    assert_equal [["Historia", false]], SpeakCapture.log
  end

  test "the story's chapter list says its focused chapter with its place as it opens" do
    Glosario_Historia.new(CHAPTERS).draw_commands
    assert_equal [[T.t(:list_entry, :name => "Prólogo", :n => 1, :tot => 4), true]], SpeakCapture.log
  end

  test "the story's chapter list says the chapter the cursor moves to, and nothing more while it stays" do
    list = Glosario_Historia.new(CHAPTERS)
    list.draw_commands
    SpeakCapture.clear
    list.instance_variable_set(:@index, 1)
    2.times { list.update_cursor }
    assert_equal [[T.t(:list_entry, :name => "Capítulo 1", :n => 2, :tot => 4), true]], SpeakCapture.log
  end

  test "the story's chapter list says its focus again, once, as a chapter's sections close back onto it" do
    list = Glosario_Historia.new(CHAPTERS)
    2.times { list.draw_commands }
    prologue = [T.t(:list_entry, :name => "Prólogo", :n => 1, :tot => 4), true]
    assert_equal [prologue, prologue], SpeakCapture.log
  end

  test "the story's chapter list reads a locked chapter as locked and a row of plain text as written" do
    { 2 => T.t(:awk_glos_locked), 3 => "Epílogo" }.each do |i, name|
      SpeakCapture.clear
      Glosario_Historia.new(CHAPTERS, i).update_cursor
      assert_equal [[T.t(:list_entry, :name => name, :n => i + 1, :tot => 4), true]], SpeakCapture.log, "row #{i}"
    end
  end

  test "the story's chapter list says nothing for a cursor off its chapters or on a chapter with no name" do
    [4, -1].each { |i| Glosario_Historia.new(CHAPTERS, i).update_cursor }
    Glosario_Historia.new([["", true, :cap9]]).update_cursor
    assert_nothing_spoken
  end

  test "a chapter's section list says its focused section, translated, with its place as it opens" do
    sections.dibujar_lista
    assert_equal [[T.t(:list_entry, :name => "El despertar", :n => 1, :tot => 5), true]], SpeakCapture.log
  end

  test "a chapter's section list says the section the cursor moves to on the page shown" do
    sections(:@pagina_actual => 1).mover_cursor(:derecha)
    assert_equal [[T.t(:list_entry, :name => "Alba", :n => 5, :tot => 5), true]], SpeakCapture.log
  end

  test "a chapter's section list reads a section the story has not unlocked as locked" do
    sections(:@index => 3).mover_cursor(:abajo)
    assert_equal [[T.t(:list_entry, :name => T.t(:awk_glos_locked), :n => 4, :tot => 5), true]], SpeakCapture.log
  end

  test "a chapter's section list says nothing for a cursor past its sections" do
    sections(:@pagina_actual => 1, :@index => 1).mover_cursor(:derecha)
    assert_nothing_spoken
  end

  test "a section's text says each page it turns to with its title and number, and nothing more as it closes" do
    story_text([["Despertar", 0], ["Despertar", 1]])
    assert_equal [[diary_page("El despertar", 1, 2, "Despierta en el bosque."), true],
                  [diary_page("El despertar", 2, 2, "Sigue el río."), true]], SpeakCapture.log
  end

  test "a section page painted again on the next frame is not said again" do
    story_text([["Despertar", 0], ["Despertar", 0]])
    assert_equal [[diary_page("El despertar", 1, 2, "Despierta en el bosque."), true]], SpeakCapture.log
  end

  test "paging past a section's last page reads the next section by the title it paints" do
    story_text([["Despertar", 1], ["La caida", 0]])
    assert_equal [[diary_page("El despertar", 2, 2, "Sigue el río."), true],
                  [diary_page("La caida", 1, 1, "Cae la noche."), true]], SpeakCapture.log
  end

  test "paging past a one-page section reads the next section's first page" do
    story_text([["La caida", 0], ["Pacto", 0]])
    assert_equal [[diary_page("La caida", 1, 1, "Cae la noche."), true],
                  [diary_page("Pacto", 1, 1, "Se sella el pacto."), true]], SpeakCapture.log
  end

  test "below medium, a section page is said without its number" do
    PokeAccess::Config.verbosity = :brief
    story_text([["Despertar", 0]])
    assert_equal [["El despertar. Despierta en el bosque.", true]], SpeakCapture.log
  end

  test "a section's page past either end reads as its first" do
    scene = World.stub_scene(:@secciones => { "Despertar" => ["Uno.", "Dos."] })
    first = diary_page("El despertar", 1, 2, "Uno.")
    { 1 => diary_page("El despertar", 2, 2, "Dos."), 2 => first, -1 => first }.each do |page, line|
      assert_equal line, PokeAccess::AwakeningStoryGlossary.body(scene, "Despertar", page), "page #{page}"
    end
  end

  test "the diary names its sibling placeholder after the one playing: Liam under switch 80, Lana under 81" do
    chapter = World.stub_scene(:@secciones => { "Capitulo 1" => ["siblingA me encontro espiando la cascada."] })
    { 80 => "Liam", 81 => "Lana", nil => "siblingA" }.each do |switch, sibling|
      $game_switches.clear
      $game_switches[switch] = true if switch
      line = diary_page("Capitulo 1", 1, 1, "#{sibling} me encontro espiando la cascada.")
      assert_equal line, PokeAccess::AwakeningStoryGlossary.body(chapter, "Capitulo 1", 0), "switch #{switch.inspect}"
    end
  end

  test "reads the focused talisman with its place and, in full, its description" do
    EquipScreen.new([SUN, MOON]).update_description
    sun = T.t(:list_entry, :name => "Talismán del Sol", :n => 1, :tot => 2)
    assert_equal [["#{sun}. Da fuerza.", true]], SpeakCapture.log
  end

  test "says a talisman once while the cursor stays on it" do
    screen = EquipScreen.new([SUN, MOON])
    screen.update_description
    SpeakCapture.clear
    screen.update_description
    assert_nothing_spoken
  end

  test "keeps the talisman on the info key until the screen ends" do
    screen = EquipScreen.new([SUN, MOON])
    screen.update_description
    assert_equal "Talismán del Sol. Da fuerza.", PokeAccess::Info.info_text, "while the screen is up"
    screen.pbEndScreen
    assert_nil PokeAccess::Info.info_text, "once it ends"
  end

  test "opening the screen says the cursed energy and the talisman in each slot, queued" do
    $game_variables[399] = 45
    $game_variables[397] = 7
    $game_variables[398] = 1
    EquipScreen.new([SUN, MOON]).main_loop
    assert_equal [[summary(45, "Talismán del Sol", "Talismán de la Luna"), false]], SpeakCapture.log
  end

  test "opening the lore window says the whole lore at once" do
    EquipScreen.new([SUN, MOON]).open_lore_window
    assert_equal [["Forjado al alba.", true]], SpeakCapture.log
  end

  test "the ball picker says the ball and how many are left, and in full the description painted under it" do
    head = T.t(:awk_ball, :name => "Pocion", :n => 5)
    lines = with_item_description("Una ball de alto rendimiento.") do
      vb_levels do
        SpeakCapture.clear
        BallSelectorInterface.new([1], [5]).update_display
        SpeakCapture.last
      end
    end
    assert_equal [head, head, "#{head}. Una ball de alto rendimiento."], lines
  end

  test "the ball picker reads a ball it gives no count by name alone" do
    BallSelectorInterface.new([1], nil).update_display
    assert_equal [["Pocion", true]], SpeakCapture.log
  end

  test "the ball picker puts the focused ball on the info key" do
    with_item_description("Una ball de alto rendimiento.") do
      BallSelectorInterface.new([1], [5]).update_display
      assert_equal "Pocion. Una ball de alto rendimiento.", PokeAccess::Info.info_text
    end
  end

  test "the ball picker says a ball once while the cursor stays on it" do
    picker = BallSelectorInterface.new([1], [5])
    picker.update_display
    SpeakCapture.clear
    picker.update_display
    assert_nothing_spoken
  end

  test "the ball picker says nothing for a cursor past its list" do
    BallSelectorInterface.new([1], [5], 1).update_display
    assert_nothing_spoken
  end

  test "the character glossary reads the focused character with its page as the list opens" do
    characters(:@total_paginas => 2).dibujar_lista
    assert_equal [[T.t(:awk_glos_page, :name => "Holly", :page => 1, :pages => 2), true]], SpeakCapture.log
  end

  test "the character glossary reads the character under the cursor on the page shown" do
    characters(:@total_paginas => 2, :@pagina_actual => 1).mover_cursor(2)
    assert_equal [[T.t(:awk_glos_page, :name => "Lana", :page => 2, :pages => 2), true]], SpeakCapture.log
  end

  test "the character glossary reads each character as its list paints it: translated, locked, or as written" do
    { 1 => "Perséfone", 2 => T.t(:awk_glos_locked), 0 => "Holly" }.each do |i, name|
      SpeakCapture.clear
      characters(:@index => i).mover_cursor(2)
      assert_equal [[name, true]], SpeakCapture.log, "row #{i}"
    end
  end

  test "the character glossary says no page for a one-page list, nor at brief" do
    characters.mover_cursor(2)
    assert_equal [["Holly", true]], SpeakCapture.log, "one page"
    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    characters(:@total_paginas => 2).mover_cursor(2)
    assert_equal [["Holly", true]], SpeakCapture.log, "two pages at brief"
  end

  test "the character glossary says nothing for a cursor past its characters" do
    characters(:@total_paginas => 2, :@pagina_actual => 1, :@index => 1).mover_cursor(2)
    assert_nothing_spoken
  end

  test "a biography's first page says the character with its affinity and place, the page and its text" do
    $game_switches[81] = true
    biography("Holly" => [0])
    assert_equal [[first_holly_page, true]], SpeakCapture.log
  end

  test "turning a biography's page says the next page without the headings" do
    $game_switches[81] = true
    biography("Holly" => [0, 1])
    second = diary_page("Holly", 2, 2, "Segunda.")
    assert_equal [[first_holly_page, true], [second, true]], SpeakCapture.log
  end

  test "a biography page painted again on the next frame is not said again" do
    $game_switches[81] = true
    biography("Holly" => [0, 0])
    assert_equal [[first_holly_page, true]], SpeakCapture.log
  end

  test "moving on to the next character reads its first page with its headings" do
    $game_switches[81] = true
    biography("Holly" => [0, [:next, "Liam"]], "Liam" => [0])
    liam = diary_page("Liam. #{T.t(:awk_glos_loc, :name => 'Pueblo')}", 1, 1, "Hermano.")
    assert_equal [[first_holly_page, true], [liam, true]], SpeakCapture.log
  end

  test "below medium, a biography page is said without its number" do
    $game_switches[81] = true
    PokeAccess::Config.verbosity = :brief
    biography("Holly" => [0])
    assert_equal [["#{holly_headings}. Lana y Holly.", true]], SpeakCapture.log
  end

  test "a biography's page past either end reads as its first, with no headings unless asked" do
    scene = characters(:@secciones => BIOS)
    first = diary_page("Holly", 1, 2, "siblingA y Holly.")
    { 1 => diary_page("Holly", 2, 2, "Segunda."), 2 => first, -1 => first }.each do |page, line|
      assert_equal line, PokeAccess::AwakeningFates.biography(scene, "Holly", page), "page #{page}"
    end
  end

  test "the hooked methods return what the game's own return" do
    screen = EquipScreen.new([SUN, MOON])
    people = characters(:@secciones => BIOS, :@frames => {})
    chapters = Glosario_Historia.new(CHAPTERS)
    story = sections
    calls = { [screen, [:update_description]] => :described, [screen, [:main_loop]] => :looped,
              [screen, [:open_lore_window]] => :opened, [screen, [:update_lore_window]] => :scrolled,
              [screen, [:pbEndScreen]] => :ended, [BallSelectorInterface.new([1], [5]), [:update_display]] => :shown,
              [people, [:dibujar_lista]] => :drawn, [people, [:mover_cursor, 2]] => :moved,
              [people, [:mostrar_texto, "Holly"]] => :shown, [Scene_Glosario.new, [:main]] => :closed,
              [Scene_Glosario.new, [:refresh]] => :refreshed, [chapters, [:draw_commands]] => :drawn,
              [chapters, [:update_cursor]] => :moved, [story, [:dibujar_lista]] => :drawn,
              [story, [:mover_cursor, :abajo]] => :moved, [story, [:mostrar_texto, "Despertar"]] => :shown }
    calls.each { |(obj, call), value| assert_equal value, obj.send(*call), "#{obj.class}##{call[0]}" }
  end

  private

  # Runs the block with every item described as text, the data's own lookup put back after; the block's value.
  def with_item_description(text)
    data = PokeAccess::Data
    real = data.method(:item_description)
    data.define_singleton_method(:item_description) { |_id| text }
    yield
  ensure
    data.define_singleton_method(:item_description, real)
  end

  # A chapter's sections over SECTIONS (Despertar translated, Eclipse not unlocked yet), two pages of four, with the
  # given ivars.
  def sections(ivars = {})
    Glosario_Historia_Secciones.new({ :@nombres_secciones => SECTIONS, :@secciones => SECTION_TEXTS,
                                      :@historia => UNLOCKED_SECTIONS, :@total_paginas => 2 }.merge(ivars))
  end

  # Opens the section list (its focus said, then cleared) and the text of the first frame's section, painting the
  # frames given, each a [section, page].
  def story_text(frames)
    scene = sections(:@frames => frames)
    scene.dibujar_lista
    SpeakCapture.clear
    scene.mostrar_texto(frames[0][0])
  end

  # The character glossary over CHARACTERS (Persefone translated, Ares not unlocked yet) with the given ivars.
  def characters(ivars = {})
    unlocked = { :holly => true, :persefone => true, :liam => true, :lana => true }
    Glosario_Personajes.new({ :@nombres_secciones => CHARACTERS, :@historia => unlocked }.merge(ivars))
  end

  # Opens the character list (its focus said, then cleared) and Holly's biography, painting the frames given.
  def biography(frames)
    scene = characters(:@secciones => BIOS, :@frames => frames)
    scene.dibujar_lista
    SpeakCapture.clear
    scene.mostrar_texto("Holly")
  end

  # The talisman screen's opening line: the cursed energy and what each slot holds.
  def summary(energy, first, second)
    [T.t(:awk_energy, :n => energy), T.t(:awk_slot, :n => 1, :name => first),
     T.t(:awk_slot, :n => 2, :name => second)].join(". ")
  end

  # A diary page as said from medium: its title, which page of how many, and its text.
  def diary_page(title, page, pages, text)
    T.t(:awk_glos_bio, :name => title, :page => page, :pages => pages, :text => text)
  end

  # Holly's name with the affinity and place her biography paints above its text.
  def holly_headings
    ["Holly", T.t(:awk_glos_aff, :name => "Neutral"), T.t(:awk_glos_loc, :name => "Verbena")].join(". ")
  end

  # Holly's first page as said from medium, her sibling named Lana (switch 81).
  def first_holly_page
    diary_page(holly_headings, 1, 2, "Lana y Holly.")
  end
end
