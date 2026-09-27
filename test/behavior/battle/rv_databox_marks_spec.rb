# The rv engine's own databox boxes, registered by games/rv_common over the core's databox marks and read through
# the gen-6 databox hook: PULSE, Rift and Perfection forms, Rejuvenation's Ultra Burst and Terastal boxes, and its
# ball for a species caught in another form.
Harness.load_common("rv_common")

Suite.define("rv databox: the engine's own boxes are said as marks, in the order drawn") do
  t = PokeAccess::I18n
  bt = PokeAccess::Battle
  foe = Struct.new(:index, :name, :pokemon).new(1, "Magnezone", Object.new)
  box = PokemonDataBox.new(foe)
  box.extra = %w[Battle/battlePulseEvoBox Battle/battleBoxOwnedSpecies]
  SpeakCapture.clear
  box.refresh
  marks = [t.t(:rv_mark_pulse), t.t(:rv_mark_owned_species)]
  eq "a PULSE form caught only as a species", bt.shown_marks(foe), marks
  eq "said as the foe comes in", SpeakCapture.lines,
     [t.t(:bt_marks_entry, :name => "Magnezone", :marks => marks.join(", "))]

  box.extra = %w[Battle/battleRiftEvoBox Battle/battlePerfectionEvoBox Battle/battleUltraEvoBox
                 Battle/battleTerastalBox Battle/battleBoxOwned]
  box.refresh
  eq "Rift, Perfection, Ultra Burst, Terastal and the stock caught ball", bt.shown_marks(foe),
     [t.t(:rv_mark_rift), t.t(:rv_mark_perfection), t.t(:bt_m_ultra), t.t(:bt_m_tera), t.t(:dex_caught)]
end
