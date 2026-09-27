# Enhanced Pokemon UI: the IV grades, shiny leaves and happiness meter, each said where its settings draw it; the
# legacy data menu and the all-stats page.

module MUISpec
  Stat = Struct.new(:id, :name)
  STATS = [Stat.new(:HP, "PS"), Stat.new(:ATTACK, "Ataque"), Stat.new(:DEFENSE, "Defensa"),
           Stat.new(:SPECIAL_ATTACK, "At. Esp."), Stat.new(:SPECIAL_DEFENSE, "Def. Esp."), Stat.new(:SPEED, "Velocidad")]

  # Runs the block with these plugin settings in place and the stats walkable, restoring both after.
  def self.with(settings)
    had_each = GameData::Stat.respond_to?(:each_main)
    GameData::Stat.define_singleton_method(:each_main) { |&b| STATS.each(&b) } unless had_each
    saved = {}
    settings.each do |k, v|
      saved[k] = Settings.const_defined?(k) ? [Settings.const_get(k)] : nil
      Settings.send(:remove_const, k) if saved[k]
      Settings.const_set(k, v)
    end
    yield
  ensure
    settings.each_key do |k|
      Settings.send(:remove_const, k) if Settings.const_defined?(k)
      Settings.const_set(k, saved[k][0]) if saved[k]
    end
    class << GameData::Stat; remove_method :each_main; end unless had_each
  end

  # Runs the block with happiness_figures? forced: the plugin's bar alone (false) or Anil's figures beside it (true).
  def self.figures(on)
    ui = PokeAccess::EnhancedPokemonUI
    saved = ui.method(:happiness_figures?)
    ui.define_singleton_method(:happiness_figures?) { on }
    yield
  ensure
    ui.define_singleton_method(:happiness_figures?, saved)
  end

  def self.poke(leaf = 0)
    pk = Poke.build(:name => "Chispa", :happiness => 204,
                    :iv => { :HP => 31, :ATTACK => 30, :DEFENSE => 0, :SPECIAL_ATTACK => 27,
                             :SPECIAL_DEFENSE => 20, :SPEED => 5 })
    pk.define_singleton_method(:shiny_leaf) { leaf }
    pk.define_singleton_method(:shiny_crown?) { leaf == 6 }
    pk
  end
end

Suite.define("enhanced pokemon ui: the IV grades, the leaves and the happiness meter where the settings draw them") do
  t = PokeAccess::I18n
  grades = t.t(:mui_iv_ratings, :list => "PS S, Ataque A, Defensa F, At. Esp. B, Def. Esp. C, Velocidad D")
  MUISpec.with(:SUMMARY_IV_RATINGS => true, :SUMMARY_SHINY_LEAF => true, :SUMMARY_HAPPINESS_METER => true,
               :STORAGE_IV_RATINGS => true, :STORAGE_SHINY_LEAF => true) do
    pk = MUISpec.poke(3)
    truthy "the stats page ends with each stat's grade, in the plugin's order",
           PokeAccess::SummaryGameData.stats_text(pk).to_s.include?(grades)
    match "the header counts the leaves", PokeAccess::Summary.header_icons(pk), /#{Regexp.escape(t.t(:mui_leaves, :n => 3))}/
    MUISpec.figures(false) do
      truthy "the first page ends with the share of the meter filled",
             PokeAccess::SummaryGameData.info_text(pk).to_s.end_with?(t.t(:mui_happiness, :n => 80))
    end
    MUISpec.figures(true) do
      truthy "or, where the page writes them beside it (Anil), with the figures",
             PokeAccess::SummaryGameData.info_text(pk).to_s.end_with?(t.t(:mui_happiness_value, :n => 204, :max => 255))
    end
    details = PokeAccess::Party.pc_details(pk)
    truthy "and the PC panel has the leaves and the grades too",
           details.include?(t.t(:mui_leaves, :n => 3)) && details.include?(grades)
    eq "six leaves are the crown", PokeAccess::EnhancedPokemonUI.leaves(MUISpec.poke(6)), t.t(:mui_leaf_crown)
  end
end

# Style 0 draws each IV as one of six stars that differ only in colour and size: said by them, not by letters.
Suite.define("enhanced pokemon ui: in the star style each IV is said as the star it draws") do
  t = PokeAccess::I18n
  s = lambda { |n| t.t(:"mui_iv_star_#{n}") }
  stars = t.t(:mui_iv_stars, :list => "PS #{s.call(5)}, Ataque #{s.call(4)}, Defensa #{s.call(0)}, " \
                                      "At. Esp. #{s.call(3)}, Def. Esp. #{s.call(2)}, Velocidad #{s.call(1)}")
  MUISpec.with(:SUMMARY_IV_RATINGS => true, :STORAGE_IV_RATINGS => true, :IV_DISPLAY_STYLE => 0) do
    pk = MUISpec.poke
    truthy "the stats page says each stat's star", PokeAccess::SummaryGameData.stats_text(pk).to_s.include?(stars)
    truthy "and so does the PC panel", PokeAccess::Party.pc_details(pk).include?(stars)
  end
  MUISpec.with(:SUMMARY_IV_RATINGS => true, :IV_DISPLAY_STYLE => 1) do
    truthy "the letter style keeps the letters", PokeAccess::SummaryGameData.stats_text(MUISpec.poke).to_s.include?(
      t.t(:mui_iv_ratings, :list => "PS S, Ataque A, Defensa F, At. Esp. B, Def. Esp. C, Velocidad D"))
  end
end

Suite.define("enhanced pokemon ui: settings turned off draw nothing, and nothing is said") do
  t = PokeAccess::I18n
  MUISpec.with(:SUMMARY_IV_RATINGS => false, :SUMMARY_SHINY_LEAF => false, :SUMMARY_HAPPINESS_METER => false,
               :STORAGE_IV_RATINGS => false, :STORAGE_SHINY_LEAF => false) do
    pk = MUISpec.poke(3)
    falsy "no grades on the stats page", PokeAccess::SummaryGameData.stats_text(pk).to_s.include?("PS S")
    falsy "no leaves in the header", PokeAccess::Summary.header_icons(pk).include?(t.t(:mui_leaves, :n => 3))
    [false, true].each do |figures|
      MUISpec.figures(figures) do
        first = PokeAccess::SummaryGameData.info_text(pk).to_s
        falsy "no meter on the first page, as a share or as figures (#{figures})",
              first.include?(t.t(:mui_happiness, :n => 80)) || first.include?(t.t(:mui_happiness_value, :n => 204, :max => 255))
      end
    end
    details = PokeAccess::Party.pc_details(pk)
    eq "and the PC panel as the vanilla one: no grades", details.grep(/PS S/), []
    falsy "nor leaves", details.include?(t.t(:mui_leaves, :n => 3))
  end
end

# The legacy data menu the summary offers: each page read as painted, label beside value.
Suite.define("enhanced pokemon ui: the legacy menu reads each page as it is painted") do
  ui = PokeAccess::EnhancedPokemonUI
  ui.legacy_open
  begin
    SpeakCapture.clear
    pbDrawTextPositions(nil, [["PIKA'S LEGACY", 295, 100], ["General", 256, 152],
                              ["Items consumed:", 38, 196], ["3", 474, 196], ["Moves learned:", 38, 228], ["7", 474, 228]])
    ui.legacy_poll
    eq "the page, a line per row, waiting its turn", SpeakCapture.log,
       [["PIKA'S LEGACY. General. Items consumed: 3. Moves learned: 7", false]]
    SpeakCapture.clear
    ui.legacy_poll
    silent "nothing new painted, nothing said"
    pbDrawTextPositions(nil, [["PIKA'S LEGACY", 295, 100], ["Battle History", 256, 152], ["Opponents defeated:", 38, 196], ["12", 474, 196]])
    ui.legacy_poll
    eq "the next page interrupts", SpeakCapture.log.map { |l| l[1] }, [true]
  ensure
    ui.legacy_close
  end
end

# The all-stats page paints each stat's value with its IV and EV in columns, the effort total and Hidden Power's
# type; the nature only tints the labels, so no nature is said.
Suite.define("summary (modern): the all-stats page says what its table paints") do
  t = PokeAccess::I18n
  MUISpec.with({}) do
    pk = MUISpec.poke
    pk.ev = { :HP => 4, :ATTACK => 252, :DEFENSE => 0, :SPECIAL_ATTACK => 0, :SPECIAL_DEFENSE => 0, :SPEED => 252 }
    text = PokeAccess::SummaryGameData.allstats_text(pk).to_s
    truthy "each stat's value, IV and EV", text.include?(t.t(:sm_allstats_row, :stat => "Ataque", :tot => pk.attack, :iv => 30, :ev => 252))
    truthy "and the effort total", text.include?(t.t(:sm_ev_total, :n => 508))
    falsy "and no nature name the page does not write", text.include?(t.t(:sm_nature, :n => ""))
  end
end

# Anil's profile is the one that writes the figures.
Suite.define("enhanced pokemon ui: Anil's first page writes the happiness as figures") do
  truthy "the profile turns the figures on", PokeAccess::EnhancedPokemonUI.happiness_figures?
end
