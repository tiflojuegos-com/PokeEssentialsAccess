# New-game "BW selector" screens (KleinStudio/Skyflyer): the option sprites carry no text, and the prompt
# and confirm are already spoken by the dialogue hook (pbMessageDisplay). These only announce which option
# the cursor highlights as you navigate. The two/four-option scenes set @select in their select* methods,
# so hook those and speak a fixed label; the random-mode checklist has no select* methods, so it is polled.
PokeAccess::Game.define("royal") do
  {
    "MenuSelector2OpcionesScene" => { "selectOpc1" => "Modo normal", "selectOpc2" => "Modo reto" },
    "GenderSelectorScene"        => { "selectBoy" => "Chico", "selectGirl" => "Chica" },
    "TonoPielSelectorScene"      => { "selectTono1" => "Tono de piel 1", "selectTono2" => "Tono de piel 2",
                                      "selectTono3" => "Tono de piel 3", "selectTono4" => "Tono de piel 4" }
  }.each do |cls, methods|
    methods.each do |meth, label|
      after(cls, meth.to_sym) { |_s, _r, _a| PokeAccess.speak(label, true) }
    end
  end
end

module PokeAccess
  # Random-mode selector (MenuSelectorRandomScene): a checklist with no select* methods -- @select 0-3 over
  # four categories, each toggled on/off in @added. SceneWatcher.reader tracks the live scene and speaks the
  # focused category and its on/off state on change.
  ROYAL_RANDOM_LABELS = ["Entrenadores", "Encuentros", "Regalos", "Objetos"]
  RoyalRandom = SceneWatcher.reader("MenuSelectorRandomScene", :pbUpdate, :royal_random) do |s|
    sel = PokeAccess.ivar(s, :@select)
    next nil if sel.nil?
    added = (s.instance_variable_get(:@added) rescue [])
    mods = (s.instance_variable_get(:@modifiers) rescue [])
    on = (mods[sel] ? added.include?(mods[sel]) : false)
    [[sel, on], "#{ROYAL_RANDOM_LABELS[sel] || "Opcion #{sel + 1}"}, #{on ? 'activado' : 'desactivado'}"]
  end
end
