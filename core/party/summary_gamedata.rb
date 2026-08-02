module PokeAccess
  # Spoken summary content built on the GameData data API (GameData:: / Pokemon objects), shared by every
  # engine that uses it -- the classic PokemonSummary_Scene (v21.1 and the Sky fork) AND v22's
  # UI::PokemonSummaryVisuals. It lives at the module root, not under a version folder, because the content
  # is identical across them; a version file only wires its own scene's hooks and delegates here. This keeps
  # the rule that no version depends on another. (Named by the data API, not "modern", which would not age.)
  module SummaryGameData
    # Spoken name of a type symbol, or nil.
    def self.type_name(sym); (GameData::Type.get(sym).name rescue nil); end

    # The text for the page currently drawn, chosen by the SV-Summary plugin's @page_id symbol (the plugin
    # orders pages dynamically, so a fixed 1..5 numbering would read the wrong page). Falls back to the
    # classic numbering for a base summary with no @page_id. param page the numeric page argument (fallback).
    def self.page_text(scene, page)
      pk = PokeAccess.expect!("summary.pokemon", PokeAccess.ivar(scene, :@pokemon))
      return nil unless pk
      pid = PokeAccess.ivar(scene, :@page_id)
      return legacy_page_text(pk, page) if pid.nil?
      case pid
      when :page_egg     then PokeAccess::I18n.t(:sm_egg)
      when :page_info    then info_text(pk)
      when :page_memo    then memo_text(pk)
      when :page_skills  then stats_text(pk)
      when :page_allstats then allstats_text(pk)
      when :page_moves   then moves_text(pk)
      when :page_ribbons then ribbons_text(pk)
      end
    rescue StandardError
      nil
    end

    # Classic five-page numbering, used only for a base summary with no @page_id (1 info, 2 memo, 3 stats,
    # 4 moves, 5 ribbons).
    def self.legacy_page_text(pk, page)
      case page
      when 1 then info_text(pk)
      when 2 then memo_text(pk)
      when 3 then stats_text(pk)
      when 4 then moves_text(pk)
      when 5 then ribbons_text(pk)
      end
    end

    # Page one: species, types, ability and held item.
    def self.info_text(pk)
      t = PokeAccess::I18n.t(:sum_data_of, :name => pk.name, :level => pk.level) + " "
      w = PokeAccess::Party.gender_word(pk); t += w + ". " if w
      sp = (pk.speciesName rescue nil); t += PokeAccess::I18n.t(:sum_species, :s => sp) + " " if sp && !sp.to_s.empty?
      ty = (pk.types.map { |s| type_name(s) }.compact rescue [])
      t += PokeAccess::I18n.t(:sum_type, :t => ty.join(' ')) + " " unless ty.empty?
      ab = (pk.ability ? pk.ability.name : nil rescue nil); t += PokeAccess::I18n.t(:sum_ability, :a => ab) + " " if ab && !ab.to_s.empty?
      it = (pk.item ? pk.item.name : nil rescue nil); t += PokeAccess::I18n.t(:sum_item, :i => it) + " " if it && !it.to_s.empty?
      t
    rescue StandardError
      nil
    end

    # Page two: the trainer memo (nature for now; met data varies by version).
    def self.memo_text(pk)
      nat = (pk.nature ? pk.nature.name : nil rescue nil)
      memo = PokeAccess::I18n.t(:sm_memo)
      (nat && !nat.to_s.empty?) ? "#{memo}. #{PokeAccess::I18n.t(:sm_nature, :n => nat)}." : "#{memo}."
    rescue StandardError
      nil
    end

    # Page three: hp and the five stats.
    def self.stats_text(pk)
      PokeAccess::I18n.t(:sm_stats) + ". " + PokeAccess::I18n.t(:sum_stats, :hp => pk.hp, :tot => pk.totalhp,
        :atk => pk.attack, :def => pk.defense, :spa => pk.spatk, :spd => pk.spdef, :spe => pk.speed)
    rescue StandardError
      nil
    end

    # Page four: the four moves with pp, as an overview (detail is read on navigation). Same walk and
    # assembly as the agnostic page, so it simply delegates (the shared each_real_move already resolves
    # names via the Data adapter, which is GameData here).
    def self.moves_text(pk)
      PokeAccess::Summary.moves_text(pk)
    end

    # The IV/EV page (Lin's plugin, page_allstats): individual and effort values per stat, from the modern
    # pkmn.iv / pkmn.ev hashes (keyed by stat symbol).
    def self.allstats_text(pk)
      iv = (pk.iv rescue nil)
      ev = (pk.ev rescue nil)
      return stats_text(pk) unless iv && ev
      s = PokeAccess::I18n.t(:sm_ivev,
        :hpi => iv[:HP], :hpe => ev[:HP], :ai => iv[:ATTACK], :ae => ev[:ATTACK],
        :di => iv[:DEFENSE], :de => ev[:DEFENSE], :sai => iv[:SPECIAL_ATTACK], :sae => ev[:SPECIAL_ATTACK],
        :sdi => iv[:SPECIAL_DEFENSE], :sde => ev[:SPECIAL_DEFENSE], :si => iv[:SPEED], :se => ev[:SPEED])
      nat = (pk.nature ? pk.nature.name : nil rescue nil)
      s += ". " + PokeAccess::I18n.t(:sm_nature, :n => nat) if nat && !nat.to_s.empty?
      s
    rescue StandardError
      stats_text(pk)
    end

    # The ribbons page (disabled in some builds, kept for base/other summaries): ribbon count.
    def self.ribbons_text(pk)
      n = (pk.numRibbons rescue 0).to_i
      n > 0 ? PokeAccess::I18n.t(:sm_ribbons, :n => n) : PokeAccess::I18n.t(:sm_ribbons_none)
    rescue StandardError
      nil
    end

    # Full detail of a focused move on the moves page: name, type, power, accuracy, pp and description, from
    # the modern move/GameData objects.
    def self.move_detail(pk, move)
      return nil unless move
      id = (move.id rescue nil)
      data = (GameData::Move.get(id) rescue nil)
      nm = (move.name rescue nil); nm = (data ? data.name : PokeAccess::I18n.t(:info_move)) if nm.nil? || nm.to_s.empty?
      ty = (data ? type_name(data.type) : nil)
      pw = 0; pw = (data.display_power(pk, move) rescue (data.power rescue 0)).to_i if data
      acc = (move.display_accuracy(pk) rescue (data ? data.accuracy : 0)).to_i
      pp = (move.pp rescue nil); tot = (move.total_pp rescue nil)
      desc = (move.description rescue (data ? data.description : ""))
      PokeAccess::MoveInfo.line(nm.to_s, ty, pw, acc, :pp => pp, :total_pp => tot, :desc => desc)
    rescue StandardError
      (move.name rescue PokeAccess::I18n.t(:info_move))
    end
  end
end
