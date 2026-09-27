module PokeAccess
  # Rejuvenation's Game Boy Color trainer card (PokemonTrainerCardSceneGBC: the BADGECARD item, the Virtual League's),
  # painted in a GSC font whose ID, No., Lv and PP are glyphs set on control characters, so each face is read from the
  # data it paints. The front: the virtual player's name, ID and money and the virtual badges it draws. Turned: the
  # Virtual League team, an arrow over each member's row (species, level, HP, an item icon) and CANCEL. C on a member
  # opens its summary, three pages (info, moves, stats) turned with left and right, the members with up and down.
  module RejuvCardGBC
    # The heights the back paints CANCEL and its title at.
    CANCEL_Y = 260
    TITLE_Y = 296

    # Whether the card belongs to someone the player is not, whose money it hides.
    def self.hidden?
      ($game_switches[:NotPlayerCharacter] rescue false) ? true : false
    end

    # The front as painted: name, ID and money, then the badges it drew.
    # param badges how many badge icons the front drew
    def self.front_text(scene, badges)
      t = PokeAccess::I18n
      id = (sprintf("%05d", $Trainer.publicID($Trainer.id)) rescue nil)
      money = hidden? ? t.t(:dex_unknown) : ($Trainer.money rescue nil)
      lines = [t.t(:tc_name, :name => PokeAccess.clean(PokeAccess.ivar(scene, :@name).to_s))]
      lines.push(t.t(:tc_id, :id => id)) if id
      lines.push(t.t(:tc_money, :n => money)) unless money.nil?
      lines.push(t.t(:tr_badges, :n => badges)) unless hidden?
      PokeAccess.sentences(lines)
    end

    # The member under the back's arrow as its row paints it (species, level, HP and the item icon), or CANCEL.
    def self.member_text(scene)
      pk = Array(PokeAccess.ivar(scene, :@trainerParty))[PokeAccess.ivar(scene, :@index).to_i]
      if pk.nil?
        cancel = PokeAccess.ivar(scene, :@access_gbc_cancel).to_s
        return cancel.empty? ? PokeAccess::I18n.t(:sm_exit) : cancel
      end
      line = PokeAccess::I18n.t(:pty_member, :name => species_name(pk), :sex => "", :level => pk.level,
                                             :hp => pk.hp, :tot => pk.totalhp)
      pk.item ? "#{line}, #{PokeAccess::I18n.t(:pty_item)}" : line
    end

    # A species' name in capitals, as the card paints it.
    def self.species_name(pk)
      PokeAccess.clean((getMonName(pk.species) rescue pk.species).to_s.upcase)
    end

    # The sign painted beside a Pokemon's number, for a male or female one.
    def self.sign(pk)
      i = { :M => 0, :F => 1 }[(pk.gender rescue nil)]
      i ? " #{PokeAccess::Party::SIGNS[i]}" : ""
    end

    # The summary's header, over every page: the nickname with its sign and level, the species and the dex number.
    def self.header_text(pk)
      t = PokeAccess::I18n
      PokeAccess.sentences([t.t(:pty_head, :name => PokeAccess.clean(pk.name.to_s), :sex => sign(pk), :level => pk.level),
                            t.t(:sum_species, :s => species_name(pk)), t.t(:sum_dex, :n => (pk.dexnum rescue nil))])
    end

    # The info page: HP, types, experience and what is left to the next level.
    def self.info_text(pk)
      t = PokeAccess::I18n
      types = [pk.type1, pk.type2].compact.map { |ty| (getTypeName(ty) rescue ty).to_s.upcase }
      left = (PBExp.startExperience(pk.level + 1, pk.growthrate) - pk.exp rescue nil)
      PokeAccess.sentences([t.t(:dbk_hp, :hp => pk.hp, :tot => pk.totalhp), t.t(:sum_type, :t => types.join(", ")),
                            t.t(:sum_exp, :n => pk.exp), left ? t.t(:sum_exp_next, :n => left) : nil])
    end

    # The moves page: the item, then each move with its PP.
    def self.moves_text(pk)
      t = PokeAccess::I18n
      item = pk.item ? PokeAccess.clean((getItemName(pk.item) rescue pk.item).to_s.upcase) : t.t(:sum_none)
      moves = Array(pk.moves).compact.map do |m|
        "#{PokeAccess.clean((getMoveName(m.move) rescue m.move).to_s.upcase)}, #{t.t(:mv_pp, :pp => m.pp, :tot => m.maxpp)}"
      end
      PokeAccess.sentences([t.t(:sum_item, :i => item), moves.empty? ? t.t(:sm_no_moves) : t.t(:sm_moves, :list => moves.join(", "))])
    end

    # The stats page: attack, defense, the one special (the higher of the two) and speed, then the ID, painted without
    # the front's leading zeros, and the trainer.
    def self.stats_text(scene, pk)
      t = PokeAccess::I18n
      stats = [[t.t(:st_atk), pk.attack], [t.t(:st_def), pk.defense], [t.t(:rj_gsc_special), [pk.spatk, pk.spdef].max],
               [t.t(:st_speed), pk.speed]].map { |label, v| "#{label} #{v}" }
      ot = "#{PokeAccess.clean(PokeAccess.ivar(scene, :@name).to_s)} #{PokeAccess.ivar(scene, :@playerGender)}".strip
      PokeAccess.sentences([stats.join(", "), t.t(:sum_id, :id => (pk.publicID rescue nil)), t.t(:sum_ot, :name => ot)])
    end

    # The page the summary shows: the header first when the member changed, then the page.
    def self.summary_text(scene)
      pk = Array(PokeAccess.ivar(scene, :@trainerParty))[PokeAccess.ivar(scene, :@index).to_i]
      return nil if pk.nil?
      page = PokeAccess.ivar(scene, :@summaryPage).to_i
      body = case page
             when 1 then moves_text(pk)
             when 2 then stats_text(scene, pk)
             else info_text(pk)
             end
      last = PokeAccess.ivar(scene, :@access_gbc_member)
      scene.instance_variable_set(:@access_gbc_member, pk)
      last.equal?(pk) ? body : PokeAccess.sentences([header_text(pk), body])
    end

    # Reads the front as it is drawn, with the badge icons it drew: queued on opening, cutting in when turned back.
    def self.front(scene)
      ret = nil
      icons = PokeAccess::PaintCapture.icons { ret = yield }
      n = Array(icons).count { |p| p.to_s =~ /badges/i }
      turned = PokeAccess.ivar(scene, :@access_gbc_read)
      scene.instance_variable_set(:@access_gbc_read, true)
      scene.instance_variable_set(:@access_gbc_member, nil)
      PokeAccess.speak(front_text(scene, n), turned ? true : false)
      ret
    end

    # Reads the back as it is drawn: its title, then the member its arrow starts on, keeping the CANCEL it paints.
    def self.back(scene)
      ret = nil
      scene.instance_variable_set(:@access_gbc_building, true)
      begin
        pairs = PokeAccess::PaintCapture.sample { ret = yield }
      ensure
        scene.instance_variable_set(:@access_gbc_building, false)
      end
      at = lambda { |y| Array(pairs).select { |r| r[3] == y }.map { |r| PokeAccess.clean(r[0].to_s) }.first }
      scene.instance_variable_set(:@access_gbc_cancel, at.call(CANCEL_Y))
      scene.instance_variable_set(:@access_gbc_member, nil)
      PokeAccess.speak(PokeAccess.sentences([at.call(TITLE_Y), member_text(scene)]), true)
      ret
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PokemonTrainerCardSceneGBC", :pbDrawTrainerCardFront, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvCardGBC.front(scene) { nxt.call }
  end

  around("PokemonTrainerCardSceneGBC", :pbDrawTrainerCardBack, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvCardGBC.back(scene) { nxt.call }
  end

  after("PokemonTrainerCardSceneGBC", :changeIndexParty, :optional => true) do |scene, _r, _a|
    unless PokeAccess.ivar(scene, :@access_gbc_building)
      PokeAccess.speak(PokeAccess::RejuvCardGBC.member_text(scene), true)
    end
  end

  after("PokemonTrainerCardSceneGBC", :drawSummaryHeader, :optional => true) do |scene, _r, _a|
    t = PokeAccess::RejuvCardGBC.summary_text(scene)
    PokeAccess.speak(t, true) if t
  end
end
