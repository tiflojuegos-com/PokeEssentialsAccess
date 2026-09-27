# Awakening's relationship cards (FatesCartas: entered through self.main, state on the class): main is wrapped, so the
# reader reads while the screen runs and never touches the class while it is closed. The fixture's @master_index is
# [7] on purpose: the panel is keyed by @posi (as a string), not through it. j_addExp is stood in before the profile
# loads, so a hook on it would bind: the game shows no affinity number, and nothing may say one.
def j_addExp(_pj = 0, _pts = 1); :added; end

require File.expand_path("../../../games/awakening/fates_extra", File.dirname(__FILE__))

Suite.define("awakening cards: reads while open, and does not go looking while closed") do
  fx = PokeAccess::AwakeningFatesExtra
  reads = 0
  spoke_inside = nil
  made = false
  begin
    character = Object.new
    character.instance_variable_set(:@nombre, "Chrom")
    character.instance_variable_set(:@rango_letras, "A")
    character.define_singleton_method(:nombre) { @nombre }
    character.define_singleton_method(:rango_letras) { @rango_letras }
    panel = Object.new
    panel.define_singleton_method(:pj) { character }

    klass = Class.new
    Object.const_set(:FatesCartas, klass) unless Object.const_defined?(:FatesCartas)
    made = true
    klass.define_singleton_method(:instance_variable_get) { |sym| reads += 1; super(sym) }
    klass.define_singleton_method(:main) do
      @posi = 0
      @paneles = { "0" => panel }
      @master_index = [7]
      SpeakCapture.clear
      PokeAccess::AwakeningFatesExtra.cards(nil)
      spoke_inside = SpeakCapture.lines.join(" ")
    end

    PokeAccess::Game.define("fates_cards_spec") do
      override("FatesCartas", :main) do |mod, original, _args|
        PokeAccess::AwakeningFatesExtra.watch_cards(mod)
        begin
          original.call
        ensure
          PokeAccess::AwakeningFatesExtra.unwatch_cards
        end
      end
    end

    reads = 0
    SpeakCapture.clear
    10.times { fx.cards(nil) }
    silent "a closed screen says nothing"
    eq "and the class is never even read", reads, 0

    FatesCartas.main
    truthy "the card is read while the screen is open", spoke_inside.to_s.index("Chrom")
    falsy "without the rank letter no screen paints", spoke_inside.to_s =~ /\bA\b/

    reads = 0
    fx.cards(nil)
    eq "once closed it stops reading again", reads, 0

    klass.define_singleton_method(:main) { raise "la pantalla revienta" }
    begin
      FatesCartas.main
    rescue StandardError
    end
    reads = 0
    fx.cards(nil)
    eq "a screen that leaves by raising still lets go", reads, 0
  ensure
    fx.unwatch_cards
    Object.send(:remove_const, :FatesCartas) if made && Object.const_defined?(:FatesCartas)
  end
end

# The panel paints ten stars (a date done has a star of its own) and an alert when the date of the character's
# current rank is unlocked and not done; the stand-in unlocks only the date of rank 3.
Suite.define("awakening cards: the panel's stars, its dates done and its date alert, as painted") do
  t = PokeAccess::I18n
  fx = PokeAccess::AwakeningFatesExtra
  made = !Object.const_defined?(:FatesCartas)
  if made
    cartas = Module.new
    cartas.define_singleton_method(:j_citaDesbloqueada?) { |_id, nivel| nivel == 3 }
    cartas.define_singleton_method(:j_citaCompletada?) { |_id, _nivel| false }
    Object.const_set(:FatesCartas, cartas)
  end
  begin
    card = Struct.new(:nombre, :rango_visible, :citas_completadas, :index).new("Lana", 3, { 4 => true }, 0)
    eq "the name, four stars lit (three of rank and a date's), the date done and the alert", fx.card_line(card),
       ["Lana", t.t(:awk_card_stars, :n => 4), t.t(:awk_prof_dates, :n => 1), t.t(:awk_card_alert)].join(", ")
    card.rango_visible = 2
    card.citas_completadas = {}
    eq "no date done and no alert at a rank whose date is locked", fx.card_line(card),
       ["Lana", t.t(:awk_card_stars, :n => 2)].join(", ")
  ensure
    Object.send(:remove_const, :FatesCartas) if made && Object.const_defined?(:FatesCartas)
  end
end

# Left and right move an arrow over the focused card that leads nowhere (confirm only says the feature is not
# available); a profile or the level bonuses close back onto the list, which then says the focused card again.
Suite.define("awakening cards: the card once, the idle arrow unsaid, and the card again behind a closed screen") do
  t = PokeAccess::I18n
  fx = PokeAccess::AwakeningFatesExtra
  card = Struct.new(:nombre, :rango_visible, :citas_completadas, :index).new("Lana", 3, {}, 0)
  panel = Struct.new(:pj, :rango).new(card, 3)
  holder = Class.new
  holder.instance_variable_set(:@posi, 0)
  holder.instance_variable_set(:@paneles, { "0" => panel })
  holder.instance_variable_set(:@rng_pos, 0)
  whole = "Lana, #{t.t(:awk_card_stars, :n => 3)}"
  old = $Trainer
  begin
    fx.watch_cards(holder)
    fx.cards(nil)
    eq "the card as its panel paints it", SpeakCapture.lines, [whole]
    SpeakCapture.clear
    holder.instance_variable_set(:@rng_pos, 1)
    fx.cards(nil)
    silent "a step of the arrow is no rank and says nothing"
    holder.instance_variable_set(:@rng_pos, 0)
    fx.cards(nil)
    SpeakCapture.clear
    tr = Object.new
    tr.define_singleton_method(:lista_cartas) { [] }
    $Trainer = tr
    eq "the profile runs as the game's own loop", fx.open_profile(0) { :profile_done }, :profile_done
    fx.cards(nil)
    eq "and closing it brings the card back", SpeakCapture.lines, [whole]
    SpeakCapture.clear
    eq "the level bonuses run as the game's own loop", fx.open_bonuses(card) { :bonuses_done }, :bonuses_done
    fx.cards(nil)
    eq "and closing them brings the card back too", SpeakCapture.lines, [whole]
  ensure
    fx.unwatch_cards
    $Trainer = old
  end
end

# j_addExp adds points no screen shows (and drops them past rank 9): the tea's reaction is the game's own message.
Suite.define("awakening cards: an affinity award says no number") do
  old = $Trainer
  begin
    holly = Struct.new(:nombre, :rango_visible).new("Holly", 2)
    tr = Object.new
    tr.define_singleton_method(:lista_cartas) { [holly] }
    $Trainer = tr
    eq "the game's own award runs", j_addExp(0, 50), :added
    silent "and nothing is said of it"
  ensure
    $Trainer = old
  end
end
