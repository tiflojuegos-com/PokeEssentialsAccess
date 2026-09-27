# Soulstones 2's Type Match-up chart (SpeciesTypeMatch_Scene), written for the game's own tts reader, off as
# shipped: while it is up, what the game hands tts is spoken, and Control reads the full match-up.
module PokeAccess
  module SS2TypeChart
    # The lines of the chart's own reader that name a key ("USE Button: Jump to Different Species.").
    KEY_LINE = /\A(?:\w+ Button|LEFT and RIGHT):/

    @live = nil

    # Whether the chart is the screen running now, which is the only place the relay speaks.
    def self.live; @live; end

    # The chart opening, with the message depth it opens at.
    def self.enter(scene)
      @live = scene
      @depth = PokeAccess.message_depth
    end

    def self.leave; @live = nil; end

    # Runs part of the chart with the relay off: the species list and type question, which other readers say,
    # and the first draw, which repeats the opening line.
    def self.aside
      live = @live
      @live = nil
      yield
    ensure
      @live = live
    end

    # One line the game handed to its own reader, unless it is a message shown on top of the chart or a key the
    # chart names while hints are left out.
    def self.relay(text)
      return unless @live
      return if PokeAccess.message_depth > @depth.to_i
      return if !PokeAccess::Verbosity.hints? && PokeAccess.clean(text.to_s) =~ KEY_LINE
      PokeAccess.speak_clean(text, false)
    rescue StandardError
      nil
    end

    # The chart's icons, strongest first, each with the predicate this game's Effectiveness tells it apart
    # by. A value none of them names is drawn with the neutral icon, and neutral is left out.
    GROUPS = [[:hyper_effective?, :mv_eff_hyper], [:pretty_effective?, :mv_eff_super],
              [:not_so_effective?, :mv_eff_weak], [:barely_effective?, :mv_eff_barely],
              [:immune?, :mv_eff_none]]

    # The full match-up on Control, composed here, since the game's own reader files half damage as a quarter.
    def self.read_full(scene)
      return unless (Input.trigger?(Input::CTRL) rescue false)
      list = PokeAccess.ivar(scene, :@species)
      sp = (list[PokeAccess.ivar(scene, :@index).to_i] rescue nil)
      t = sp ? matchup_text(GameData::Species.get(sp)) : nil
      PokeAccess.speak(t, true) if t
    rescue StandardError
      nil
    end

    # The species with its form, its types, and every icon group with the attacking types that draw it,
    # classified by the same calls the chart makes over the same type list.
    def self.matchup_text(s)
      name = [s.real_name.to_s, (s.form.to_i > 0 ? s.real_form_name.to_s : "")].reject { |p| p.empty? }.join(" ")
      mine = s.types.map { |ty| GameData::Type.get(ty).name }
      parts = [name, PokeAccess::I18n.t(:mv_type, :t => mine.join(" "))]
      attackers = []
      GameData::Type.each { |d| attackers.push(d.id) unless d.id == :QMARKS }
      GROUPS.each do |pred, key|
        hit = attackers.select { |a| Effectiveness.send(pred, Effectiveness.calculate(a, s.types[0], s.types[1])) }
        next if hit.empty?
        names = hit.map { |a| GameData::Type.get(a).name }.join(", ")
        parts.push(PokeAccess::I18n.t(:ss2_matchup_group, :eff => PokeAccess::I18n.t(key), :types => names))
      end
      parts.join(". ")
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  around("SpeciesTypeMatch_Scene", :pbTypeMatchUp, :optional => true) do |scene, nxt, _a|
    PokeAccess::SS2TypeChart.enter(scene)
    begin
      nxt.call
    ensure
      PokeAccess::SS2TypeChart.leave
    end
  end

  [:pbChooseSpeciesFromList, :pbChooseMonoTypeSpecies].each do |m|
    around("SpeciesTypeMatch_Scene", m, :optional => true) do |_scene, nxt, _a|
      PokeAccess::SS2TypeChart.aside { nxt.call }
    end
  end
  around("SpeciesTypeMatch_Scene", :drawSpeciesTypes, :optional => true) do |scene, nxt, _a|
    PokeAccess.ivar(scene, :@init) ? PokeAccess::SS2TypeChart.aside { nxt.call } : nxt.call
  end

  # Control, noticed from the screen's per-frame pbUpdate.
  after("SpeciesTypeMatch_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
    PokeAccess::SS2TypeChart.read_full(scene)
  end
end

# The relay, on the top-level tts; it speaks only while the chart runs, since the game calls tts from many screens.
PokeAccess::Hooks.wrap_global("tts", "ss2_tts_relay", :before) do |args, _r|
  PokeAccess::SS2TypeChart.relay(args[0])
end
