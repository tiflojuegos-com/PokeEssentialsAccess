module PokeAccess
  # Enhanced Pokemon UI (Modular UI Scenes plugin), where its settings turn each on: the IV ratings (the six stars by
  # colour and size in style 0, the letters F D C B A S in style 1) on the summary's stats page and in the PC panel,
  # the shiny leaves or crown on the summary and in the PC panel, and the happiness meter on the summary's first
  # page, plus the legacy menu.
  module EnhancedPokemonUI
    GRADES = %w[F D C B A S]
    STARS = [:mui_iv_star_0, :mui_iv_star_1, :mui_iv_star_2, :mui_iv_star_3, :mui_iv_star_4, :mui_iv_star_5]

    # A setting of the plugin, false where the game's Settings leave it out.
    def self.setting(name)
      ::Settings.const_defined?(name) ? ::Settings.const_get(name) : false
    rescue StandardError
      false
    end

    # The icon the plugin picks for one IV (pbDisplayIVRatings): the maximum, one under it, none, and three
    # bands between.
    def self.grade(iv)
      max = (::Pokemon::IV_STAT_LIMIT rescue 31)
      return 5 if iv == max
      return 4 if iv == max - 1
      return 0 if iv == 0
      return 3 if iv > max - (max / 4)
      return 2 if iv > max - (max / 2)
      1
    end

    # Every stat with its rating as the plugin draws it, in its order: a star in style 0, a letter otherwise; nil when
    # the stats cannot be walked.
    def self.iv_ratings(pk)
      stars = setting(:IV_DISPLAY_STYLE) == 0
      rows = []
      GameData::Stat.each_main do |s|
        g = grade(pk.iv[s.id].to_i)
        rows.push("#{s.name} #{stars ? PokeAccess::I18n.t(STARS[g]) : GRADES[g]}")
      end
      return nil if rows.empty?
      PokeAccess::I18n.t(stars ? :mui_iv_stars : :mui_iv_ratings, :list => rows.join(", "))
    rescue StandardError
      nil
    end

    # The shiny leaves as they are drawn, the crown or how many, or nil for none.
    def self.leaves(pk)
      return PokeAccess::I18n.t(:mui_leaf_crown) if (pk.shiny_crown? rescue false)
      n = (pk.shiny_leaf rescue 0).to_i
      n > 0 ? PokeAccess::I18n.t(:mui_leaves, :n => n) : nil
    end

    # The legacy data menu (pbLegacyMenu): its pages of counts are captured as painted while its loop runs.
    def self.legacy_open
      @legacy = true
      @legacy_first = true
      PokeAccess::PaintCapture.arm(:mui_legacy)
    end

    def self.legacy_close
      @legacy = false
      PokeAccess::PaintCapture.take(:mui_legacy)
    end

    # Says a legacy page once painted (the next frame finds it): the first queued, the next ones interrupting.
    def self.legacy_poll
      return unless @legacy && PokeAccess::PaintCapture.pending?(:mui_legacy)
      lines = PokeAccess::PaintCapture.lines(PokeAccess::PaintCapture.take_pairs(:mui_legacy))
      PokeAccess::PaintCapture.arm(:mui_legacy)
      return if lines.empty?
      PokeAccess.speak(lines.join(". "), !@legacy_first)
      @legacy_first = false
    end

    # The happiness meter as the share of its bar that is filled, or as the figures a page writes beside
    # it. None for a shadow Pokemon or an egg, which the plugin draws no meter for.
    def self.happiness(pk)
      return nil if (pk.shadowPokemon? rescue false) || PokeAccess::Summary.egg?(pk)
      n = pk.happiness.to_i
      return PokeAccess::I18n.t(:mui_happiness_value, :n => n, :max => max_happiness) if happiness_figures?
      PokeAccess::I18n.t(:mui_happiness, :n => [((n * 100) / 255.0).round, 100].min)
    rescue StandardError
      nil
    end

    # Whether the page writes the happiness as figures beside the meter; a game whose copy does overrides this.
    def self.happiness_figures?
      false
    end

    def self.max_happiness
      (::Settings::MAX_HAPPINESS rescue 255)
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :stats_extras, :tag => "enhanced_pokemon_ui") do |_m, original, args|
  extra = PokeAccess::EnhancedPokemonUI.setting(:SUMMARY_IV_RATINGS) ? PokeAccess::EnhancedPokemonUI.iv_ratings(args[0]) : nil
  original.call + [extra].compact
end

PokeAccess::Hooks.override(PokeAccess::Summary, :header_icons, :tag => "enhanced_pokemon_ui") do |_m, original, args|
  icons = original.call
  leaf = PokeAccess::EnhancedPokemonUI.setting(:SUMMARY_SHINY_LEAF) ? PokeAccess::EnhancedPokemonUI.leaves(args[0]) : nil
  leaf ? [icons, leaf].reject { |s| s.to_s.empty? }.join(", ") : icons
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :info_text, :tag => "enhanced_pokemon_ui") do |_m, original, args|
  t = original.call
  meter = PokeAccess::EnhancedPokemonUI.setting(:SUMMARY_HAPPINESS_METER) ? PokeAccess::EnhancedPokemonUI.happiness(args[0]) : nil
  (t && meter) ? "#{t.strip} #{meter}" : t
end

PokeAccess::Hooks.override(PokeAccess::Party, :pc_details, :tag => "enhanced_pokemon_ui") do |_m, original, args|
  ui = PokeAccess::EnhancedPokemonUI
  extra = []
  extra.push(ui.leaves(args[0])) if ui.setting(:STORAGE_SHINY_LEAF)
  extra.push(ui.iv_ratings(args[0])) if ui.setting(:STORAGE_IV_RATINGS)
  original.call + extra.compact
end

PokeAccess::Hooks.around_hook("PokemonSummary_Scene", :pbLegacyMenu, :optional => true) do |_scene, nxt, _a|
  PokeAccess::EnhancedPokemonUI.legacy_open
  begin
    nxt.call
  ensure
    PokeAccess::EnhancedPokemonUI.legacy_close
  end
end
PokeAccess::Keys.on_frame { PokeAccess::EnhancedPokemonUI.legacy_poll }
