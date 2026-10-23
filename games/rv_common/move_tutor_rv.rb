module PokeAccess
  # The Move Tutor app of the engine Reborn and Rejuvenation share: the focused move's type, PP and each party member's
  # mark (can learn, knows, cannot), after the name the generic reader says; each profile binds its own scene.
  module MoveTutorRV
    # The codes pbPartyCanLearnThisMove? gives a member, as the screen's marks.
    UNABLE = 0
    ABLE = 1
    KNOWN = 2

    # The focused move's type, PP and party marks, queued behind its name while the list has the cursor; once per move.
    # A list entry is the move, or [move, item, quantity] for one still to be paid for.
    def self.describe(scene)
      list = PokeAccess.sprite(scene, "commands")
      return unless list && list.active
      entry = (PokeAccess.ivar(scene, :@moves)[list.index] rescue nil)
      move = entry.is_a?(Array) ? entry[0] : entry
      data = (move ? $cache.moves[move] : nil)
      return unless data && PokeAccess::Cursor.changed?(scene, :rv_tutor, [list.index, entry])
      PokeAccess.speak(PokeAccess.sentences(details(data, entry.is_a?(Array))), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The type and PP as painted, whether it is still to be paid for, then who in the party can learn the move and who
    # knows it, or that nobody can.
    def self.details(data, paid = false)
      parts = []
      ty = PokeAccess::Data.type_name(data.type)
      parts.push(PokeAccess::I18n.t(:mv_type, :t => ty)) if ty
      parts.push(PokeAccess::I18n.t(:mv_pp, :pp => data.maxpp, :tot => data.maxpp)) if data.maxpp.to_i > 0
      parts.push(PokeAccess::I18n.t(:rv_tutor_paid)) if paid
      marks = PokemonBag.pbPartyCanLearnThisMove?(data.move)
      can = names_with(marks, ABLE)
      knows = names_with(marks, KNOWN)
      parts.push(PokeAccess::I18n.t(:tut_can_list, :names => can.join(", "))) unless can.empty?
      parts.push(PokeAccess::I18n.t(:tut_knows_list, :names => knows.join(", "))) unless knows.empty?
      parts.push(PokeAccess::I18n.t(:tut_nobody)) if can.empty? && knows.empty? && marks.include?(UNABLE)
      parts
    end

    # The names of the party members whose mark is code.
    def self.names_with(marks, code)
      out = []
      $Trainer.party.each_with_index { |pk, i| out.push(PokeAccess.clean(pk.name.to_s)) if pk && marks[i] == code }
      out
    end
  end
end
