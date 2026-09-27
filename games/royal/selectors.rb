# Royal's new-game "BW selector" screens (KleinStudio/Skyflyer), image-only: the highlighted option by what its
# picture shows (from lang/), on each select* method; the random-mode checklist has none and is polled.
module PokeAccess
  module RoyalSelectors
    # Each selector's options by the method that lights them: [the words its picture shows, the sentence under them
    # or nil, its place among the skin-tone portraits or nil]. The portraits are the same for boy and girl.
    OPTIONS = {
      "MenuSelector2OpcionesScene" => { "selectOpc1" => [:rsel_normal, :rsel_normal_desc],
                                        "selectOpc2" => [:rsel_challenge, :rsel_challenge_desc] },
      "GenderSelectorScene"        => { "selectBoy" => [:gsel_boy], "selectGirl" => [:gsel_girl] },
      "TonoPielSelectorScene"      => { "selectTono1" => [:rsel_skin_1, nil, 1], "selectTono2" => [:rsel_skin_2, nil, 2],
                                        "selectTono3" => [:rsel_skin_3, nil, 3], "selectTono4" => [:rsel_skin_4, nil, 4] }
    }

    # The skin-tone portraits, in a two-by-two grid.
    SKIN_TONES = 4

    # Speaks a lit option: its words, its place among the portraits while positions are said and, in full, the
    # sentence under it, which the info key keeps with the words.
    def self.say(option)
      key, desc_key, n = option
      name = PokeAccess::I18n.t(key)
      head = n ? PokeAccess::Verbosity.list_entry(name, n, SKIN_TONES) : name
      desc = desc_key ? PokeAccess::I18n.t(desc_key) : nil
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([name, desc])) if desc
      PokeAccess.speak(PokeAccess::Verbosity.descriptions? ? PokeAccess.sentences([head, desc]) : head, true)
    end
  end

  # Random-mode checklist (MenuSelectorRandomScene): @select 0-3 over four categories, on when their modifier is in
  # @added; the focused one and its state, on change.
  ROYAL_RANDOM_LABELS = [:rrnd_trainers, :rrnd_encounters, :rrnd_gifts, :rrnd_items]
  RoyalRandom = SceneWatcher.reader("MenuSelectorRandomScene", :pbUpdate, :royal_random) do |s|
    sel = PokeAccess.ivar(s, :@select)
    next nil if sel.nil?
    added = (s.instance_variable_get(:@added) rescue [])
    mods = (s.instance_variable_get(:@modifiers) rescue [])
    on = (mods[sel] ? added.include?(mods[sel]) : false)
    key = ROYAL_RANDOM_LABELS[sel]
    label = key ? PokeAccess::I18n.t(key) : PokeAccess::I18n.t(:rrnd_option, :n => sel + 1)
    [[sel, on], "#{label}, #{PokeAccess::I18n.t(on ? :val_on : :val_off)}"]
  end
end

PokeAccess::Game.define("royal") do
  PokeAccess::RoyalSelectors::OPTIONS.each do |cls, methods|
    methods.each do |meth, option|
      after(cls, meth.to_sym) { |_s, _r, _a| PokeAccess::RoyalSelectors.say(option) }
    end
  end
  after("MenuSelector2OpcionesScene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
end
