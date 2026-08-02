# Awakening's relationship cards (FatesCartas). The screen is entered through self.main and keeps its
# whole state on the class, so there is no instance to hold and the reader has to poll -- which means it
# polls on every frame of the entire game, not just while the screen is up. It used to answer that poll by
# resolving "FatesCartas" by name and reading three class ivars, forever.
#
# So main is wrapped now, and the two halves of that need pinning together: the screen must still read
# (a wrapper that fails to install is a silent, permanent mute), and the poller must not touch the class
# at all while the screen is closed -- which is the whole point and the half a "does it speak?" test
# cannot see.
require File.expand_path("../../../games/awakening/fates_extra", File.dirname(__FILE__))

Suite.define("awakening cards: reads while open, and does not go looking while closed") do
  fx = PokeAccess::AwakeningFatesExtra
  reads = 0
  spoke_inside = nil
  made = false
  begin
    panel = Object.new
    panel.instance_variable_set(:@nombre, "Chrom")
    panel.instance_variable_set(:@rango_letras, "A")

    klass = Class.new
    Object.const_set(:FatesCartas, klass) unless Object.const_defined?(:FatesCartas)
    made = true
    klass.define_singleton_method(:instance_variable_get) { |sym| reads += 1; super(sym) }
    klass.define_singleton_method(:main) do
      @posi = 0
      @paneles = { "chrom" => panel }
      @master_index = ["chrom"]
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

    # Closed: the poller must bail on its first line. Not "stays silent" -- silence proves nothing here,
    # the old version was silent too while reading the class forty times a second.
    reads = 0
    SpeakCapture.clear
    10.times { fx.cards(nil) }
    silent "a closed screen says nothing"
    eq "and the class is never even read", reads, 0

    FatesCartas.main
    truthy "the card is read while the screen is open", spoke_inside.to_s.index("Chrom")
    truthy "with its rank", spoke_inside.to_s.index("A")

    # And it lets go on the way out, including when the screen leaves by raising.
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
