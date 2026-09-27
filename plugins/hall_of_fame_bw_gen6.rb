# The gen-6 BW Hall of Fame script (HallOfFameScene with writePokemonDataPC; Realidea, Uranium), a rework that never
# calls what core hooks: read on moveSprite (each frame of an entrant's slide, deduped by index; -1 is the trainer),
# the entry's closing card, the PC viewer's record as painted (writeNormalDataPC) and card (writePokemonDataPC). The
# viewer picks an entrant only by a click on it: the accept key stands for a click on the front one.
module PokeAccess
  module HallOfFameBWGen6
    @pc = nil

    # The spoken card of one hall entrant, or nil.
    def self.member_line(pk)
      return nil unless pk
      PokeAccess::I18n.t(:pc_slot, :name => pk.name, :level => pk.level)
    rescue StandardError
      nil
    end

    # The PC viewer's card as painted: species and sex sign, level, nickname, original trainer, moves; an egg as
    # "Egg". Brief is species and nickname; medium adds the level; full the rest. The info key keeps it whole until
    # the scene ends.
    def self.pc_card(pk)
      return nil unless pk
      egg = (pk.isEgg? rescue false)
      species = egg ? PokeAccess::I18n.t(:pty_egg) : (PBSpecies.getName(pk.species) rescue pk.name).to_s
      sign = egg ? nil : PokeAccess::Party.gender_glyph(pk)
      signed = [species, sign].compact.join(" ")
      parts = [[PokeAccess::Verbosity.keep?(:hall_of_fame, :full) ? signed : species, :brief]]
      parts.push([PokeAccess::I18n.t(:hofbw_level, :n => pk.level), :medium]) unless egg
      parts.push([PokeAccess::I18n.t(:hof_nickname, :name => pk.name), :brief]) if pk.name.to_s != species
      ot = (pk.ot rescue nil)
      parts.push([PokeAccess::I18n.t(:hofbw_ot, :name => ot), :full]) if ot && !ot.to_s.empty?
      moves = ((pk.moves || []).map { |m| m.id > 0 ? (PBMoves.getName(m.id) rescue nil) : nil }.compact rescue [])
      parts.push([PokeAccess::I18n.t(:sm_moves, :list => moves.join(", ")), :full]) unless moves.empty?
      whole = parts.map { |p| p[0] }
      whole[0] = signed
      PokeAccess::Info.set_info(:text, whole.join(", "))
      PokeAccess::Verbosity.line(:hall_of_fame, parts)
    rescue StandardError
      member_line(pk)
    end

    # The PC viewer's record as writeNormalDataPC paints it (its number and place among the records), then the team
    # it holds, which the viewer shows only as pictures; on the first record read, the keys to pick and to leave.
    def self.pc_record(scene)
      pairs = PokeAccess::PaintCapture.sample { yield }
      parts = PokeAccess::PaintCapture.lines(pairs)
      team = (PokeAccess.ivar(scene, :@hallEntry) || []).map { |pk| (pk.name rescue nil) }.compact
      parts.push(PokeAccess::I18n.t(:hofbw_team, :list => team.join(", "))) unless team.empty?
      line = PokeAccess.sentences(parts)
      return line unless PokeAccess::Cursor.changed?(scene, :hofbw6_keys, true)
      PokeAccess::Verbosity.with_hint(line, PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:hofbw_pc_keys)))
    end

    # Holds the PC viewer while its selection loop runs.
    def self.watch(scene); @pc = scene; end
    def self.unwatch; @pc = nil; end

    # True when the viewer asks whether its front entrant (@positions[0]) was clicked, on a frame the accept key was
    # pressed with no record picked: that is the key's click.
    def self.pick?(args)
      s = @pc
      return false unless s && !PokeAccess.ivar(s, :@selectedrecord) && Input.trigger?(Input::C)
      front = (PokeAccess.ivar(s, :@positions) || [])[0]
      front ? (args[0] == front[0] - 48 && args[1] == front[1] - 48) : false
    rescue StandardError
      false
    end

    # The entry's closing card (congratulations, player, ID and time) once it shows, with the key that ends it.
    def self.closing_card(scene)
      rows = PokeAccess.ivar(scene, :@access_hof_card)
      return unless rows.is_a?(Array) && PokeAccess::Cursor.changed?(scene, :hofbw6_card, true)
      line = PokeAccess::Util.join_parts(rows.map { |r| PokeAccess.clean(r) }, ", ")
      key = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:hofbw_card_key))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(line, key), false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("HallOfFameScene", :moveSprite, :optional => true) do |scene, _r, args|
  i = args[0]
  next unless i.is_a?(Integer) && i >= 0
  entry = PokeAccess.ivar(scene, :@hallEntry)
  PokeAccess::Cursor.announce(scene, :hofbw6_slide, i, false) do
    PokeAccess::HallOfFameBWGen6.member_line((entry[i] rescue nil))
  end
end
PokeAccess::Hooks.after_hook("HallOfFameScene", :writePokemonDataPC, :optional => true) do |_s, _r, args|
  t = PokeAccess::HallOfFameBWGen6.pc_card(args[0])
  PokeAccess.speak(t, true) if t
end
PokeAccess::Hooks.around_hook("HallOfFameScene", :writeNormalDataPC, :optional => true) do |scene, nxt, _a|
  ret = nil
  t = PokeAccess::HallOfFameBWGen6.pc_record(scene) { ret = nxt.call }
  index = PokeAccess.ivar(scene, :@hallIndex)
  PokeAccess::Cursor.announce(scene, :hofbw6_record, [index, t], true, false) { t }
  ret
end
PokeAccess::Hooks.around_hook("HallOfFameScene", :pbPCSelection, :optional => true) do |s, nxt, _a|
  PokeAccess::HallOfFameBWGen6.watch(s)
  begin
    nxt.call
  ensure
    PokeAccess::HallOfFameBWGen6.unwatch
  end
end
PokeAccess::Hooks.around_hook("Game_Mouse", :inAreaLeft?, :optional => true) do |_m, nxt, args|
  PokeAccess::HallOfFameBWGen6.pick?(args) || nxt.call
end
# The card is painted hidden, for the trainer's slide to reveal: kept as painted, said once writeTrainerData runs
# (each frame the scene then waits for the key).
PokeAccess::Hooks.around_hook("HallOfFameScene", :createTrainerBattler, :optional => true) do |s, nxt, _a|
  r = nil
  rows = PokeAccess::PaintCapture.sample { r = nxt.call }
  s.instance_variable_set(:@access_hof_card, PokeAccess::PaintCapture.laid_out(rows))
  r
end
PokeAccess::Hooks.after_hook("HallOfFameScene", :writeTrainerData, :optional => true,
                             :hook_container => true) do |s, _r, _a|
  PokeAccess::HallOfFameBWGen6.closing_card(s)
end
PokeAccess::Hooks.after_hook("HallOfFameScene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

PokeAccess::Verbosity.define_reading(:hall_of_fame, :vb_hall_of_fame, :vbh_hall_of_fame)
