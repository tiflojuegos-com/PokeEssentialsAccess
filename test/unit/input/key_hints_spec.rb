# A hint's letter for a button rebound with the mod's remap becomes the bound key; nothing else changes, nor anything
# while no key is rebound.
Suite.define("key hints: a rebound button's letter becomes the bound key, and only that") do
  kh = PokeAccess::KeyHints
  rgss = kh::RGSS_LETTERS
  was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
  PokeAccess::Config.rebinds = {}
  eq "with nothing rebound a hint is untouched", kh.localize("[A] Curar", rgss), "[A] Curar"

  PokeAccess::Config.rebinds = { :x => 0x4A, :c => 0x4B }
  eq "a bracketed key", kh.localize("[A] Curar", rgss), "[J] Curar"
  eq "a button not rebound keeps its letter", kh.localize("[D] Brújula", rgss), "[D] Brújula"
  eq "a key that labels a line, one of two", kh.localize("C/X: Salir", rgss), "K/X: Salir"
  eq "two bracketed keys", kh.localize("[A]/[S]: Desplazarse", rgss), "[J]/[S]: Desplazarse"
  eq "a letter the table leaves out is never a key", kh.localize("[X] Eventos", { "A" => :x }), "[X] Eventos"
  eq "a sentence is only read for keys when asked", kh.localize("Pulsa C para acceder", rgss), "Pulsa C para acceder"
  eq "and then the key it asks for", kh.localize("Pulsa C para acceder", rgss, true), "Pulsa K para acceder"
  eq "a key named after 'la tecla'", kh.localize("Puedes cambiar a los modos con la tecla C.", rgss, true),
     "Puedes cambiar a los modos con la tecla K."
  eq "a button's name is no letter", kh.localize("Press Cancel when ready.", rgss, true), "Press Cancel when ready."
  PokeAccess::Config.rebinds = { :a => 0x58, :b => 0x5A }
  eq "a key asked for after 'la tecla' is swapped once, even when two buttons trade their letters",
     kh.localize("Pulsa la tecla Z para confirmar.", rgss, true), "Pulsa la tecla X para confirmar."
  eq "in English and French too",
     [kh.localize("Press the key Z.", rgss, true), kh.localize("Appuie sur la touche Z.", rgss, true)],
     ["Press the key X.", "Appuie sur la touche X."]
  PokeAccess::Config.rebinds = { :x => 0x4A, :c => 0x4B }
  eq "nor is a colon after a word that is no key", kh.localize("Hora: 12:30", rgss), "Hora: 12:30"
  eq "the key for the mod's own text: the bound one", kh.key(:c, "C"), "K"
  eq "or the game's while it keeps its own", kh.key(:z, "D"), "D"

  PokeAccess::Config.key_hint_letters = { "A" => :x }
  eq "the profile's table is the default", kh.localize("[A] Vial"), "[J] Vial"
  SpeakCapture.clear
  PokeAccess::PausePanel.instance_variable_set(:@last, [])
  PokeAccess::PausePanel.say(["[A] Curar", "[D] Brújula"])
  eq "the pause panel says the key the player uses", SpeakCapture.last, PokeAccess.sentences(["[J] Curar", "[D] Brújula"])
  title = PokeAccess::I18n.t(:title_screen)
  eq "and the title's prompt the key bound to confirm",
     PokeAccess::TitleScreen.prompt, "#{title}. #{PokeAccess::I18n.t(:title_press, :key => "K")}"
  PokeAccess::Config.rebinds = {}
  enter = PokeAccess::I18n.t(:title_press, :key => PokeAccess::I18n.t(:key_enter))
  eq "which is Enter while nothing is rebound", PokeAccess::TitleScreen.prompt, "#{title}. #{enter}"
  eq "another picture that waits for the key says its own text before it",
     PokeAccess::TitleScreen.prompt(:rcr_notice), "#{PokeAccess::I18n.t(:rcr_notice)}. #{enter}"
  PokeAccess::Config.verbosity = :brief
  eq "and without hints, the screen alone", PokeAccess::TitleScreen.prompt, title
  PokeAccess::Config.verbosity = :full
ensure
  PokeAccess::Config.rebinds = was[0]
  PokeAccess::Config.key_hint_letters = was[1]
  PokeAccess::PausePanel.instance_variable_set(:@last, [])
end

# The mod's help texts name the mod's keys as the player has set them, the glossary's help included.
Suite.define("key hints: the mod's help texts name the mod's keys where they are set") do
  cm = PokeAccess::ConfigMenu
  was = [PokeAccess::Config.keys.dup, cm.instance_variable_get(:@mode), cm.instance_variable_get(:@index)]
  ctrl = cm.keyname(0x11)
  truthy "at the defaults, Control G", PokeAccess::I18n.t(:snd_mark_help, cm.key_vars).include?("#{ctrl} G")
  PokeAccess::Config.keys[:field] = 0x42
  PokeAccess::Config.keys[:prev] = 0x55
  truthy "moved, the key the marker is on", PokeAccess::I18n.t(:snd_mark_help, cm.key_vars).include?("#{ctrl} B")
  truthy "and the previous target's", PokeAccess::I18n.t(:help_defer_rebuild, cm.key_vars).include?("(U, L")
  cm.instance_variable_set(:@mode, :sounds)
  cm.instance_variable_set(:@index, PokeAccess::SoundGlossary::ENTRIES.index { |e| e[0] == :mark })
  SpeakCapture.clear
  cm.speak_help
  spoke "the glossary's help key says it", /#{Regexp.escape(ctrl)} B\b/
ensure
  PokeAccess::Config.keys = was[0]
  cm.instance_variable_set(:@mode, was[1])
  cm.instance_variable_set(:@index, was[2])
end

# Royal's hint letters follow the keys its F1 menu paints; RPG Maker's letters stand while F1 keeps them.
Suite.define("key hints: Royal's letters are the keys its F1 menu paints") do
  load File.expand_path("../../../games/royal/key_hints.rb", File.dirname(__FILE__)) unless defined?(PokeAccess::RoyalKeys)
  kh = PokeAccess::KeyHints
  was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters.dup]
  eq "without the game's reader, the profile's table", kh.table, PokeAccess::Config.key_hint_letters
  names = { :ACTION => "Z", :BACK => "X", :USE => "C", :JUMPUP => "A", :JUMPDOWN => "S", :SPECIAL => "D",
            :AUX1 => "Q", :AUX2 => "W" }
  reader = Module.new
  reader.instance_variable_set(:@names, names)
  def reader.key_name(n); @names[n] || "?"; end
  Object.const_set(:KeybindingReader, reader)
  eq "F1 untouched: RPG Maker's letters", PokeAccess::RoyalKeys.letters, kh::RGSS_LETTERS
  names[:SPECIAL] = "F"
  names[:JUMPUP] = "D"
  PokeAccess::Config.rebinds = { :z => 0x4B }
  eq "a key F1 moved is read as the button it has now", kh.localize("[F] Brújula"), "[K] Brújula"
  eq "and the letter it left, as the button F1 gave it", kh.localize("[D] Curar"), "[D] Curar"
  PokeAccess::Config.rebinds = { :x => 0x4A }
  eq "which a rebind of that button replaces", kh.localize("[D] Curar"), "[J] Curar"
ensure
  Object.send(:remove_const, :KeybindingReader) if defined?(::KeybindingReader)
  PokeAccess::Config.rebinds = was[0]
  PokeAccess::Config.key_hint_letters = was[1]
end

Suite.define("key hints: with hints left out, the gate drops them, keeps a count, and the label they hang from goes") do
  kh = PokeAccess::KeyHints
  lines = ["Medallas: 3", "LISTA DE TARJETAS:", "Pulsa C para acceder", "[A] Vial (2/3)", "[D] Radar"]
  eq "with hints said, every line stays", kh.gate(lines), lines
  PokeAccess::Config.verbosity = :brief
  eq "without them the hints go, a count stays and the orphan label goes", kh.gate(lines), ["Medallas: 3", "Vial (2/3)"]
  eq "a window's hint sentence goes, a figure stays whole",
     kh.gate_sentences("Peso: 6.9 kg. Press Enter for more details."), "Peso: 6.9 kg."
  eq "and a text with no hint is left as it is", kh.gate_sentences("Nv. 5, 3.5%"), "Nv. 5, 3.5%"
  PokeAccess::PausePanel.instance_variable_set(:@last, [])
  SpeakCapture.clear
  PokeAccess::PausePanel.say(["Dinero: 300", "[A] Curar"])
  eq "the pause panel leaves its shortcuts out", SpeakCapture.last, PokeAccess.sentences(["Dinero: 300"])
  PokeAccess::PaintCapture.arm(:kh_spec)
  PokeAccess::PaintCapture.note("Tarjeta de Brock")
  PokeAccess::PaintCapture.note("[C]: Leer la descripción")
  SpeakCapture.clear
  PokeAccess::PaintCapture.flush_pending(:kh_spec, true)
  eq "and a painted capture said whole leaves its key lines out", SpeakCapture.last, "Tarjeta de Brock"
ensure
  PokeAccess::Config.verbosity = :full
end
