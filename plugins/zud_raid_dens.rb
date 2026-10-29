module PokeAccess
  # ZUD's Max Raid Den (MaxRaidScene): the entry screen once painted (its title, the boss as its silhouette, type icons,
  # stars and marks show it, the field, the party it takes in, the battle's limits and the keys), the party again after
  # the party screen, and the rewards screen after the raid. Its labels are captured as painted on the den's overlay.
  module ZudRaidDens
    # The field the header's pictures name: the battle weather and terrain by the battle reader's words, the
    # environment by the raid tag its picture shows.
    WEATHERS = { :Sun => :w_sun, :Rain => :w_rain, :Sandstorm => :w_sandstorm, :Hail => :w_hail,
                 :ShadowSky => :w_shadow_sky, :Fog => :w_fog, :HarshSun => :w_harsh_sun, :HeavyRain => :w_heavy_rain,
                 :StrongWinds => :w_strong_winds }
    TERRAINS = { :Electric => :bt_electric, :Grassy => :bt_grassy, :Misty => :bt_misty, :Psychic => :bt_psychic }
    ENVIRONS = { :None => :zden_env_urban, :Grass => :zden_env_fields, :TallGrass => :zden_env_fields,
                 :MovingWater => :zden_env_aquatic, :StillWater => :zden_env_aquatic, :Puddle => :zden_env_wetlands,
                 :Underwater => :zden_env_underwater, :Cave => :zden_env_cavern, :Rock => :zden_env_rocky,
                 :Sand => :zden_env_sandy, :Forest => :zden_env_forest, :ForestGrass => :zden_env_forest,
                 :Snow => :zden_env_frosty, :Ice => :zden_env_frosty, :Volcano => :zden_env_volcanic,
                 :Graveyard => :zden_env_spiritual, :Sky => :zden_env_sky, :Space => :zden_env_space,
                 :UltraSpace => :zden_env_ultra_space }
    # The rewards screen's bonus marks, by the number the scene keeps for each in @bonuses.
    BONUSES = [:zden_hard, :zden_bonus_perfect, :zden_bonus_timer, :zden_bonus_fair, :zden_bonus_capture]
    # The stars the entry screen can line up; a legendary raid's sixth rank shows five.
    STARS_MAX = 5
    # Where the entry screen paints its labels, [x, y]: the title, the field header and the three keys' captions.
    TITLE = [25, 21]
    FIELD = [450, 8]
    LEAVE = [403, 143]
    ENTER = [403, 206]
    PARTY = [111, 284]
    # Where the rewards screen paints its rows, [x, y]; the result goes at y 20 wherever its text starts.
    RESULT_Y = 20
    GENDER = [20, 76]
    LEVEL = [38, 77]
    ABILITY_Y = 283
    NONE_Y = 168
    BONUS = [8, 8]
    EXIT = [393, 284]

    @scene = nil
    @phase = nil
    @rows = []
    @said = true

    # Holds the den while its entry screen runs (the block), collecting what it paints from the start.
    def self.entry(scene)
      watch(scene, :entry)
      yield
    ensure
      @scene = nil
      @phase = nil
    end

    # Holds the rewards screen while it runs (the block); the den closes after it.
    def self.rewards(scene)
      watch(scene, :rewards)
      yield
    ensure
      @phase = :done
    end

    # Starts collecting a den screen's paint, to be said once it lands.
    def self.watch(scene, phase)
      @scene = scene
      @phase = phase
      @rows = []
      @said = false
    end

    def self.phase; @phase; end

    # A string the game painted: kept while a den screen is open and it went onto the den's overlay.
    def self.note(bitmap, text, x, y)
      return unless @scene && (@phase == :entry || @phase == :rewards)
      return unless bitmap.equal?(PokeAccess.ivar(@scene, :@overlay))
      t = PokeAccess.clean(text.to_s)
      @rows.push([t, x.to_i, y.to_i]) unless t.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Speaks the open screen once its paint has landed: the loop's first frame, after everything is drawn.
    def self.poll
      return if @said || @scene.nil? || @rows.empty?
      @said = true
      line = @phase == :rewards ? rewards_line(@scene, @rows) : entry_line(@scene, @rows)
      PokeAccess.speak(line, false) unless line.to_s.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The text painted at [x, y], or nil.
    def self.at(rows, pos)
      r = rows.find { |row| row[1] == pos[0] && row[2] == pos[1] }
      r ? r[0] : nil
    end

    # The text painted at height y, or nil.
    def self.at_y(rows, y)
      r = rows.find { |row| row[2] == y }
      r ? r[0] : nil
    end

    # The entry screen as it stands: title, boss, field, party, the battle's limits, then the keys.
    def self.entry_line(scene, rows)
      painted = rows.map { |r| [r[1], r[2]] }
      known = [TITLE, FIELD, LEAVE, ENTER, PARTY]
      limits = rows.select { |r| !known.include?([r[1], r[2]]) }.map { |r| r[0] }
      parts = [at(rows, TITLE)].concat(boss_parts(scene))
      parts.push(field_line(scene, at(rows, FIELD))) if painted.include?(FIELD)
      parts.push(party_line(scene))
      parts.concat(limits)
      parts.concat(hints([[at(rows, ENTER), :c, :key_enter], [at(rows, LEAVE), :b, :key_escape],
                          [at(rows, PARTY), :a, nil]]))
      PokeAccess.sentences(parts)
    end

    # The boss as the den shows it: a black silhouette, its type icons, its stars and the marks beside them.
    def self.boss_parts(scene)
      parts = [PokeAccess::I18n.t(:zden_boss)]
      types = boss_types(scene)
      parts.push(PokeAccess::I18n.t(:zud_raid_types, :list => types.join(", "))) unless types.empty?
      rank = PokeAccess.ivar(scene, :@rank)
      parts.push(PokeAccess::I18n.t(:zden_stars, :n => [rank.to_i, STARS_MAX].min)) if rank.to_i > 0
      parts.push(PokeAccess::I18n.t(:dmax_factor)) if PokeAccess.ivar(scene, :@gmax)
      parts.push(PokeAccess::I18n.t(:zden_hard)) if PokeAccess.ivar(scene, :@hardmode)
      parts.push(PokeAccess::I18n.t(:zden_loot)) if PokeAccess.ivar(scene, :@loot)
      parts
    end

    # The boss species' types, as its form's two icons show them.
    def self.boss_types(scene)
      sp = PokeAccess.ivar(scene, :@bosspoke)
      form = PokeAccess.ivar(scene, :@bossform)
      id = (::GameData::Species.get_species_form(sp, form) rescue sp)
      PokeAccess::Data.species_types(id)
    end

    # The field header: its painted label and the weather, terrain and environment its pictures show.
    def self.field_line(scene, label)
      words = []
      w = WEATHERS[PokeAccess.ivar(scene, :@weather)]
      words.push(PokeAccess::I18n.t(w)) if w
      t = TERRAINS[PokeAccess.ivar(scene, :@terrain)]
      words.push(PokeAccess::I18n.t(t)) if t
      e = ENVIRONS[PokeAccess.ivar(scene, :@environ)]
      words.push(PokeAccess::I18n.t(e)) if e
      "#{label}: #{words.join(', ')}"
    end

    # The party the den takes in, as its icons show it: the first able Pokemon, as many as the raid's size.
    def self.party_line(scene)
      size = PokeAccess.ivar(scene, :@size).to_i
      party = (($Trainer || $player).party rescue []) || []
      able = party.select { |pk| pk && !(pk.egg? rescue false) && !(pk.fainted? rescue false) }
      names = able[0, size].map { |pk| PokeAccess.clean(pk.name.to_s) }
      PokeAccess::I18n.t(:zden_party, :list => names.join(", "))
    end

    # The painted captions of the keys' buttons, each with its key, while key hints are said.
    # param keys [caption, button, i18n key of the button's default key name or nil for its letter]
    def self.hints(keys)
      return [] unless PokeAccess::Verbosity.hints?
      keys.select { |k| k[0] }.map do |caption, button, name|
        key = PokeAccess::KeyHints.key(button, name ? PokeAccess::I18n.t(name) : "Z")
        PokeAccess::I18n.t(:hint_label_key, :label => caption, :key => key)
      end
    end

    # Says the party again when the party screen closes over the entry screen.
    def self.party_back
      return unless @scene && @phase == :entry
      PokeAccess.speak(party_line(@scene), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The rewards screen: the result, the Pokemon's sex, level and ability ("???" said as unknown), the bonus marks or
    # that none was earned, and the key that leaves; the rewards list is a command window the menu reader says.
    def self.rewards_line(scene, rows)
      result = at_y(rows, RESULT_Y)
      info = [at(rows, GENDER), at(rows, LEVEL)].compact.join(" ")
      parts = [result, unknown(info), unknown(at_y(rows, ABILITY_Y)), at_y(rows, NONE_Y)]
      bonus = bonus_line(scene, at(rows, BONUS))
      parts.push(bonus) if bonus
      parts.concat(hints([[at(rows, EXIT), :b, :key_escape]]))
      PokeAccess.sentences(parts)
    end

    # The bonus header and the marks under it, or nil when the screen shows none.
    def self.bonus_line(scene, label)
      return nil unless label
      marks = (PokeAccess.ivar(scene, :@bonuses) || []).map { |b| BONUSES[b.to_i] }.compact
      "#{label}: #{marks.map { |k| PokeAccess::I18n.t(k) }.join(', ')}"
    end

    # Painted question marks as the word for unknown, which a screen reader would leave unsaid.
    def self.unknown(t)
      t ? PokeAccess::DexEntry.unknown_marks(t) : nil
    end
  end
end

PokeAccess::Hooks.around_hook("MaxRaidScene", :pbMaxRaidEntry, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudRaidDens.entry(scene) { nxt.call }
end
PokeAccess::Hooks.around_hook("MaxRaidScene", :pbRaidRewardsScreen, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudRaidDens.rewards(scene) { nxt.call }
end
# The den's paint, looked at only while one of its screens is open.
PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_zud_den_pbDrawTextPositions", :before) do |args, _r|
  next unless PokeAccess::ZudRaidDens.phase
  (args[1] || []).each { |r| PokeAccess::ZudRaidDens.note(args[0], r[0], r[1], r[2]) if r.is_a?(Array) }
end
PokeAccess::Hooks.wrap_kernel("drawTextEx", "plugin_zud_den_drawTextEx", :before) do |args, _r|
  PokeAccess::ZudRaidDens.note(args[0], args[5], args[1], args[2]) if PokeAccess::ZudRaidDens.phase
end
PokeAccess::Hooks.wrap_kernel("pbPokemonScreen", "plugin_zud_den_pbPokemonScreen", :after) do |_args, _r|
  PokeAccess::ZudRaidDens.party_back
end
PokeAccess::Frame.each_pulse { PokeAccess::ZudRaidDens.poll }
