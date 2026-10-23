# Awakening's relationship cards (FatesCartas: entered through its class method main, its state on the class): the
# profile wraps main, so the focused card is said while the screen runs and the class is not even read while it is
# closed; a card as its panel paints it; the screens a card opens run as the game's own and give the card back; an
# affinity award, whose points no screen shows, is not said.

# Awakening's affinity award, defined before the profile loads so that a hook added on it would bind and be heard.
def j_addExp(_pj = 0, _pts = 1); end

# FatesCartas as the profile finds it when it loads: main runs the screen (the block a test hands to on_main), the
# screens a card opens are class methods with loops of their own, and the date tables answer from the ranks a test
# unlocks and completes. It counts the reads of its state, which the profile makes through instance_variable_get.
class FatesCartas
  class << self
    attr_accessor :on_main, :unlocked, :completed, :reads

    def main; @on_main ? @on_main.call : :closed; end
    def pbLUSperfil(_lugar); :profile_done; end
    def j_Masinfo(_lugar); :info_done; end
    def j_mostrarResumenNivel(_pj); :bonuses_done; end
    def j_citaDesbloqueada?(_id, nivel); (@unlocked || []).include?(nivel); end
    def j_citaCompletada?(_id, nivel); (@completed || []).include?(nivel); end

    def instance_variable_get(sym)
      @reads = (@reads || 0) + 1
      super
    end
  end
end

fates_extra = File.join(Harness::ROOT, "games", "awakening", "fates_extra.rb")
eval(Harness.source(fates_extra), TOPLEVEL_BINDING, fates_extra)

class FatesCardsTest < PokeAccessTest
  # The stand-in the profile bound to, kept out of the constant table between tests: another suite builds its own.
  CARTAS = Object.send(:remove_const, :FatesCartas)

  # A character's card as the trainer's list keeps it, and a panel of the screen showing one.
  Card = Struct.new(:nombre, :edad, :titulo, :cumpleanios, :aliados, :localidad, :signo, :exp, :exp_t, :rango_visible,
                    :citas_completadas, :index, :info, :rango_letras)
  Panel = Struct.new(:pj)

  test "a closed screen says nothing and never reads the class" do
    with_cards_screen do |cartas|
      show(cartas, 0, "0" => Panel.new(lana))
      cartas.reads = 0
      10.times { cards }
      assert_nothing_spoken
      assert_equal 0, cartas.reads
    end
  end

  test "while main runs the focused card is said as its panel paints it, found by its place and not the master index" do
    with_cards_screen do |cartas|
      cartas.on_main = lambda do
        show(cartas, 0, "0" => Panel.new(chrom), "7" => Panel.new(lana))
        cartas.instance_variable_set(:@master_index, [7])
        cards
        :closed
      end
      assert_equal :closed, FatesCartas.main, "main keeps its own return"
      assert_equal [["Chrom, #{stars(0)}", true]], SpeakCapture.log
    end
  end

  test "once main returns the screen is let go, and the class is not read again" do
    with_cards_screen do |cartas|
      cartas.on_main = lambda { show(cartas, 0, "0" => Panel.new(lana)) }
      FatesCartas.main
      cartas.reads = 0
      cards
      assert_nothing_spoken
      assert_equal 0, cartas.reads
    end
  end

  test "a main that raises lets its error through and still lets the screen go" do
    with_cards_screen do |cartas|
      cartas.on_main = lambda do
        show(cartas, 0, "0" => Panel.new(lana))
        raise "la pantalla revienta"
      end
      assert_raises(RuntimeError) { FatesCartas.main }
      cartas.reads = 0
      cards
      assert_nothing_spoken
      assert_equal 0, cartas.reads
    end
  end

  test "a card is said once, and again only when the focus moves or the screen opens anew" do
    with_cards_screen do |cartas|
      cartas.on_main = lambda do
        panels = { "0" => Panel.new(lana), "1" => Panel.new(chrom) }
        show(cartas, 0, panels)
        cards
        cartas.instance_variable_set(:@rng_pos, 1)
        cards
        show(cartas, 1, panels)
        cards
      end
      FatesCartas.main
      cartas.on_main = lambda do
        show(cartas, 1, "0" => Panel.new(lana), "1" => Panel.new(chrom))
        2.times { cards }
      end
      FatesCartas.main
      assert_equal ["Lana, #{stars(3)}", "Chrom, #{stars(0)}", "Chrom, #{stars(0)}"], SpeakCapture.lines
    end
  end

  test "a focus with no panel, a panel with no character, or state the screen has not set says nothing" do
    nameless = lana
    nameless.nombre = ""
    with_cards_screen do |cartas|
      cartas.on_main = lambda do
        [[3, { "0" => Panel.new(lana) }], [0, { "0" => Panel.new(nil) }], [0, { "0" => Panel.new(nameless) }],
         [nil, { "0" => Panel.new(lana) }], [0, [Panel.new(lana)]]].each do |posi, panels|
          show(cartas, posi, panels)
          cards
        end
      end
      FatesCartas.main
      assert_nothing_spoken
    end
  end

  test "a card is said with the stars its panel lights, the dates done and the alert of a date waiting" do
    with_cards_screen do |cartas|
      cartas.unlocked = [3]
      { [3, { 4 => true }, []] => ["Lana", stars(4), dates(1), alert],
        [3, { 1 => true }, []] => ["Lana", stars(3), dates(1), alert],
        [2, {}, []] => ["Lana", stars(2)],
        [3, nil, [3]] => ["Lana", stars(3)],
        [10, {}, []] => ["Lana", stars(10)] }.each do |(rank, done, completed), want|
        cartas.completed = completed
        card = lana
        card.rango_visible = rank
        card.citas_completadas = done
        assert_equal want.join(", "), PokeAccess::AwakeningFatesExtra.card_line(card), "rank #{rank}, #{done.inspect}"
      end
    end
  end

  test "without the game's date tables a card shows no alert" do
    assert_equal "Lana, #{stars(3)}", PokeAccess::AwakeningFatesExtra.card_line(lana)
  end

  test "a card's profile is said as it opens, runs as the game's own loop, and closing it says the card again" do
    PokeAccess::Config.verbosity = :brief
    waiting = lana
    waiting.citas_completadas = { 0 => true }
    ready = PokeAccess::I18n.t(:awk_prof_date_ready)
    { "a character with no dates on record" => [chrom, [], [chrom_profile], "Chrom, #{stars(0)}"],
      "one with a date done and the first one waiting" =>
        [waiting, [0], [lana_profile, dates(1), ready], "Lana, #{stars(3)}, #{dates(1)}"] }
      .each do |what, (card, unlocked, profile, line)|
      with_cards_screen do |cartas|
        cartas.unlocked = unlocked
        with_trainer_cards([card]) do
          ran = nil
          cartas.on_main = lambda do
            show(cartas, 0, "0" => Panel.new(card))
            cards
            SpeakCapture.clear
            ran = FatesCartas.pbLUSperfil(0)
            cards
          end
          FatesCartas.main
          assert_equal :profile_done, ran, what
          assert_equal [[profile.join(". "), true], [line, true]], SpeakCapture.log, what
        end
      end
    end
  end

  test "a card's level bonuses are said as they open and run as the game's own loop; closed, they read no key" do
    with_cards_screen do |cartas|
      with_bonuses(0 => { 1 => { :titulo => "Confianza", :descripcion => "Sube el ataque." } }) do
        ran = nil
        cartas.on_main = lambda do
          show(cartas, 0, "0" => Panel.new(lana))
          cards
          SpeakCapture.clear
          ran = FatesCartas.j_mostrarResumenNivel(lana)
          pressing(Input::DOWN) { PokeAccess::AwakeningFatesExtra.bonus_poll }
          cards
        end
        FatesCartas.main
        assert_equal :bonuses_done, ran
        title = PokeAccess::I18n.t(:awk_bonus_title, :name => "Lana")
        level = PokeAccess::I18n.t(:awk_bonus_row, :n => 1, :title => "Confianza")
        assert_equal [["#{title}. #{level}", true], ["Lana, #{stars(3)}", true]], SpeakCapture.log
      end
    end
  end

  test "a card's notes are said under their title as they open, and the game's own screen runs" do
    with_cards_screen do
      with_trainer_cards([lana]) do
        assert_equal :info_done, FatesCartas.j_Masinfo(0)
        assert_equal [["#{PokeAccess::I18n.t(:awk_info_title)}. Le gusta el té.", true]], SpeakCapture.log
      end
    end
  end

  # A guard against hooking the award again: the profile leaves j_addExp alone, as the points it adds show nowhere.
  test "an affinity award says no number, as no screen shows one" do
    with_trainer_cards([lana]) do
      j_addExp(0, 50)
      assert_nothing_spoken
    end
  end

  private

  def lana
    Card.new("Lana", 17, "Reina", "5 de mayo", ["Guerrera"], "Alba", "Leo", 30, 100, 3, {}, 0, ["Le gusta el té."],
             "B")
  end

  def chrom
    Card.new("Chrom", 20, "Príncipe", "1 de abril", ["Lord"], "Ylisse", "Aries", 0, 50, 0, nil, 1, [], "A")
  end

  # Lana's and Chrom's profiles as the screen lays out their fields.
  def lana_profile
    PokeAccess::I18n.t(:awk_prof, :name => "Lana", :age => 17, :title => "Reina", :bday => "5 de mayo",
                                  :cls => "Guerrera", :loc => "Alba", :sign => "Leo", :exp => 30, :tot => 100,
                                  :stars => 3)
  end

  def chrom_profile
    PokeAccess::I18n.t(:awk_prof, :name => "Chrom", :age => 20, :title => "Príncipe", :bday => "1 de abril",
                                  :cls => "Lord", :loc => "Ylisse", :sign => "Aries", :exp => 0, :tot => 50,
                                  :stars => 0)
  end

  def stars(n)
    PokeAccess::I18n.t(:awk_card_stars, :n => n)
  end

  def dates(n)
    PokeAccess::I18n.t(:awk_prof_dates, :n => n)
  end

  def alert
    PokeAccess::I18n.t(:awk_card_alert)
  end

  # The frame poll of the cards screen.
  def cards
    PokeAccess::AwakeningFatesExtra.cards(nil)
  end

  # Sets the screen's state as the game keeps it on the class: the focused panel's place and the panels by place.
  def show(cartas, posi, panels)
    cartas.instance_variable_set(:@posi, posi)
    cartas.instance_variable_set(:@paneles, panels)
  end

  # Runs the block with FatesCartas in place, its state fresh, and lets the screen, its card and the constant go
  # afterwards.
  def with_cards_screen
    CARTAS.on_main = nil
    CARTAS.unlocked = []
    CARTAS.completed = []
    CARTAS.reads = 0
    [:@posi, :@paneles, :@master_index, :@rng_pos].each do |iv|
      CARTAS.send(:remove_instance_variable, iv) if CARTAS.instance_variable_defined?(iv)
    end
    Object.const_set(:FatesCartas, CARTAS)
    yield CARTAS
  ensure
    Object.send(:remove_const, :FatesCartas) if Object.const_defined?(:FatesCartas)
    PokeAccess::AwakeningFatesExtra.unwatch_cards
    PokeAccess::AwakeningFatesExtra.bonus_close
  end

  # The block's value with the game's table of level bonuses (PersonajesFates.resumen_niveles) answering table,
  # taken out afterwards.
  def with_bonuses(table)
    personajes = Module.new
    personajes.define_singleton_method(:resumen_niveles) { table }
    Object.const_set(:PersonajesFates, personajes)
    yield
  ensure
    Object.send(:remove_const, :PersonajesFates)
  end

  # The block's value with key pressed this frame, as Input.trigger? answers; the stub's own answer put back after.
  def pressing(key)
    meta = Input.singleton_class
    meta.send(:alias_method, :fates_cards_trigger, :trigger?)
    meta.send(:define_method, :trigger?) { |k, *_rest| k == key }
    yield
  ensure
    meta.send(:alias_method, :trigger?, :fates_cards_trigger)
    meta.send(:remove_method, :fates_cards_trigger)
  end

  # The block's value with the trainer's list of cards set to list.
  def with_trainer_cards(list)
    was = $Trainer
    trainer = Object.new
    trainer.define_singleton_method(:lista_cartas) { list }
    $Trainer = trainer
    yield
  ensure
    $Trainer = was
  end
end
