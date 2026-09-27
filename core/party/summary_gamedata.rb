module PokeAccess
  # Summary page text on the GameData API, shared by the v21 PokemonSummary_Scene and v22's
  # UI::PokemonSummaryVisuals; the version files only wire their hooks.
  module SummaryGameData
    # Spoken name of a type symbol, or nil.
    def self.type_name(sym); (GameData::Type.get(sym).name rescue nil); end

    # The text for the page drawn, by the scene's @page_id (a plugin's page order), else by page number; nil for
    # an egg's page, which Summary.say_egg_page reads.
    # param memo the paragraphs the page painted as formatted text, which is how the memo page writes itself
    # param pairs the page's capture with each row's position, where page one's Pokedex number is read
    def self.page_text(scene, page, memo = nil, painted = nil, pairs = nil)
      pk = PokeAccess.expect!("summary.pokemon", PokeAccess.ivar(scene, :@pokemon))
      return nil unless pk
      pid = PokeAccess.ivar(scene, :@page_id)
      return legacy_page_text(pk, page, memo, painted, scene, pairs) if pid.nil?
      case pid
      when :page_egg     then nil
      when :page_info    then info_text(pk, PokeAccess::Summary.painted_dex_number(pairs), PokeAccess::Summary.heart_of(pk, memo))
      when :page_memo    then memo_page_text(pk, memo)
      when :page_skills  then skills_text(scene, pk, painted)
      when :page_allstats then allstats_text(pk)
      when :page_moves   then moves_text(pk)
      when :page_ribbons then ribbons_text(pk)
      end
    rescue StandardError
      nil
    end

    # Classic five-page numbering, used only for a base summary with no @page_id (1 info, 2 memo, 3 stats,
    # 4 moves, 5 ribbons).
    def self.legacy_page_text(pk, page, memo = nil, painted = nil, scene = nil, pairs = nil)
      return nil if page == 1 && PokeAccess::Summary.egg?(pk)
      case page
      when 1 then info_text(pk, PokeAccess::Summary.painted_dex_number(pairs), PokeAccess::Summary.heart_of(pk, memo))
      when 2 then memo_page_text(pk, memo)
      when 3 then skills_text(scene, pk, painted)
      when 4 then moves_text(pk)
      when 5 then ribbons_text(pk)
      end
    end

    # Page one: name, header icons, dex number, species, types, held item and trainer lines; an egg has its own
    # page instead (Summary.say_egg_page).
    # param dex the Pokedex number the page paints (Summary.painted_dex_number), or nil
    # param heart the paragraph a Shadow Pokemon's page paints in place of the experience, or nil
    def self.info_text(pk, dex = nil, heart = nil)
      t = PokeAccess::I18n.t(:sum_data_of, :name => "#{pk.name}#{PokeAccess::Party.sign_phrase(pk)}", :level => pk.level) + " "
      icons = PokeAccess::Summary.header_icons(pk)
      t += "#{icons}. " unless icons.empty?
      t += PokeAccess::I18n.t(:sum_dex, :n => dex) + " " if dex
      sp = (pk.speciesName rescue nil); t += PokeAccess::I18n.t(:sum_species, :s => sp) + " " if sp && !sp.to_s.empty?
      ty = (pk.types.map { |s| type_name(s) }.compact rescue [])
      t += PokeAccess::I18n.t(:sum_type, :t => ty.join(' ')) + " " unless ty.empty?
      t += PokeAccess::Summary.item_fact(pk) + " "
      t += PokeAccess::Summary.trainer_facts(pk).join(" ")
      heart ? "#{t} #{heart}" : t
    rescue StandardError
      nil
    end

    # Page two: the trainer memo as painted, or the nature alone where nothing was painted.
    # param painted the formatted paragraphs the page drew, or nil
    def self.memo_text(pk, painted = nil)
      memo = PokeAccess::I18n.t(:sm_memo)
      from_paint = PokeAccess::Summary.painted_memo(painted)
      return from_paint if from_paint
      nat = (pk.nature ? pk.nature.name : nil rescue nil)
      (nat && !nat.to_s.empty?) ? "#{memo}. #{PokeAccess::I18n.t(:sm_nature, :n => nat)}." : "#{memo}."
    rescue StandardError
      nil
    end

    # An egg's memo page as v22's draw_egg_memo paints it: where the egg came from and how close it is to
    # hatching, without the nature memo_text would add.
    def self.egg_memo_text(pk)
      place = (pk.obtain_text rescue nil).to_s
      place = (pbGetMapNameFromId(pk.obtain_map) rescue nil).to_s if place.empty?
      from = PokeAccess::I18n.t(:sm_met_egg)
      from = "#{from}: #{place}" unless place.empty?
      PokeAccess::Util.join_parts([from, PokeAccess::Incubator.hatch_state(pk)])
    rescue StandardError
      nil
    end

    # Page three: hp and the five stats, whatever else this game's page writes beside them (stats_extras), the
    # nature's effect its label colours show, then the ability, with the description where the page writes it.
    # param painted the strings the page painted, or nil when it was not captured
    def self.stats_text(pk, painted = nil)
      t = PokeAccess::I18n.t(:sm_stats) + ". " + PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp,
        :atk => pk.attack, :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed)
      extra = (stats_extras(pk) rescue [])
      t += " " + extra.join(" ") unless extra.nil? || extra.empty?
      nat = PokeAccess::Summary.nature_effect_line(pk)
      t += " " + nat if nat
      ab = PokeAccess::Summary.ability_line(pk, painted)
      ab ? "#{t} #{ab}" : t
    rescue StandardError
      nil
    end

    # Sentences a game's stats page writes beside the stats, which a profile adds where a plugin paints them
    # (individual and effort values, the nature's marks). None on the stock page.
    def self.stats_extras(_pk); []; end

    # The memo page: its own paragraph, then whatever this game's page draws beside it (memo_extras).
    def self.memo_page_text(pk, memo)
      t = memo_text(pk, memo)
      extra = (memo_extras(pk) rescue [])
      extra.nil? || extra.empty? ? t : [t, extra.join(" ")].compact.join(" ")
    end

    # Sentences a game's memo page draws beside the memo, which a profile adds where a plugin paints them
    # (Enhanced UI's egg groups). None on the stock page.
    def self.memo_extras(_pk); []; end

    # The stats page, or Enhanced Pokemon UI's EV/IV face while @statToggle shows it.
    def self.skills_text(scene, pk, painted)
      PokeAccess.ivar(scene, :@statToggle) ? eviv_text(pk) : stats_text(pk, painted)
    end

    # Enhanced Pokemon UI's EV/IV face of the stats page: each stat's EV and IV, their totals, the EVs left under
    # the limit and the Hidden Power type the page draws as an icon.
    def self.eviv_text(pk)
      rows = []
      ev_total = 0
      iv_total = 0
      GameData::Stat.each_main do |s|
        ev = pk.ev[s.id].to_i
        iv = pk.iv[s.id].to_i
        ev_total += ev
        iv_total += iv
        rows.push(PokeAccess::I18n.t(:sm_eviv_row, :stat => s.name, :ev => ev, :iv => iv))
      end
      rows.push(PokeAccess::I18n.t(:sm_eviv_total, :ev => ev_total, :iv => iv_total))
      limit = (::Pokemon::EV_LIMIT rescue nil)
      rows.push(PokeAccess::I18n.t(:sm_ev_left, :n => limit - ev_total, :max => limit)) if limit
      hp = (pbHiddenPower(pk)[0] rescue nil)
      hp_name = hp ? type_name(hp) : nil
      rows.push(PokeAccess::I18n.t(:sm_hidden_power, :t => hp_name)) if hp_name
      "#{PokeAccess::I18n.t(:sm_stats)}. #{rows.join('. ')}"
    rescue StandardError
      nil
    end

    # IVs and EVs per stat, as the pages that paint them lay them out.
    # param ev_sp the EV shown on the Sp. Atk row, which a mixed-EV game shares with Attack
    def self.iv_ev_text(pk, ev_sp = :SPECIAL_ATTACK)
      iv = pk.iv; ev = pk.ev
      PokeAccess::I18n.t(:sm_ivev,
        :hpi => iv[:HP], :hpe => ev[:HP], :ai => iv[:ATTACK], :ae => ev[:ATTACK],
        :di => iv[:DEFENSE], :de => ev[:DEFENSE], :sai => iv[:SPECIAL_ATTACK], :sae => ev[ev_sp],
        :sdi => iv[:SPECIAL_DEFENSE], :sde => ev[:SPECIAL_DEFENSE], :si => iv[:SPEED], :se => ev[:SPEED])
    rescue StandardError
      nil
    end

    # Page four: the moves with their pp (Summary.moves_text).
    def self.moves_text(pk)
      PokeAccess::Summary.moves_text(pk)
    end

    # The all-stats page (page_allstats): each stat's value, IV and EV, the EV total, the Hidden Power icon's type
    # and the nature's effect its tinted labels show.
    def self.allstats_text(pk)
      rows = []
      ev_total = 0
      GameData::Stat.each_main do |s|
        ev = pk.ev[s.id].to_i
        ev_total += ev
        rows.push(PokeAccess::I18n.t(:sm_allstats_row, :stat => s.name, :tot => stat_value(pk, s.id),
                                     :iv => pk.iv[s.id].to_i, :ev => ev))
      end
      rows.push(PokeAccess::I18n.t(:sm_ev_total, :n => ev_total))
      hp = (pbHiddenPower(pk)[0] rescue nil)
      rows.push(PokeAccess::I18n.t(:sm_hidden_power, :t => type_name(hp))) if hp && type_name(hp)
      nat = PokeAccess::Summary.nature_effect_line(pk)
      rows.push(nat) if nat
      "#{PokeAccess::I18n.t(:sm_stats)}. #{rows.join('. ')}"
    rescue StandardError
      stats_text(pk)
    end

    # A stat's value by its id, as the stats pages print it (the maximum, for HP).
    def self.stat_value(pk, id)
      case id
      when :HP then pk.totalhp
      when :ATTACK then pk.attack
      when :DEFENSE then pk.defense
      when :SPECIAL_ATTACK then pk.spatk
      when :SPECIAL_DEFENSE then pk.spdef
      when :SPEED then pk.speed
      end
    end

    # The ribbons page: how many ribbons.
    def self.ribbons_text(pk)
      n = (pk.numRibbons rescue 0).to_i
      n > 0 ? PokeAccess::I18n.t(:sm_ribbons, :n => n) : PokeAccess::I18n.t(:sm_ribbons_none)
    rescue StandardError
      nil
    end

    # A move's power as the moves page shows it, asked the way each era names it: display_power (v20+),
    # display_damage (Soulstones 2), or the plain figure, power in v20+ and base_damage in v19.
    def self.move_power(data, pk, move)
      pw = (data.display_power(pk, move) rescue nil)
      pw = (data.display_damage(pk, move) rescue nil) if pw.nil?
      pw = PokeAccess.attr_of(data, :power, :base_damage) if pw.nil?
      pw.to_i
    end

    # A focused move at the summary move reading's level: name, type, category, power, accuracy, pp and
    # description; type and category as this Pokemon uses them (display_*), as the icons show.
    def self.move_detail(pk, move)
      return nil unless move
      id = (move.id rescue nil)
      data = (GameData::Move.get(id) rescue nil)
      nm = (move.name rescue nil); nm = (data ? data.name : PokeAccess::I18n.t(:info_move)) if nm.nil? || nm.to_s.empty?
      ty = (data ? type_name((data.display_type(pk, move) rescue data.type)) : nil)
      pw = data ? move_power(data, pk, move) : 0
      acc = (move.display_accuracy(pk) rescue (data ? data.accuracy : 0)).to_i
      pp = (move.pp rescue nil); tot = (move.total_pp rescue nil)
      desc = (move.description rescue (data ? data.description : ""))
      cat = data ? PokeAccess::MoveInfo.category_word((data.display_category(pk, move) rescue (data.category rescue nil))) : nil
      PokeAccess::MoveInfo.leveled(:summary_move, nm.to_s, ty, pw, acc, :cat => cat, :pp => pp, :total_pp => tot,
                                   :desc => desc)
    rescue StandardError
      (move.name rescue PokeAccess::I18n.t(:info_move))
    end
  end
end
