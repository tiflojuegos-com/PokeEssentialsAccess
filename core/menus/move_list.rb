module PokeAccess
  # A move list drawn by hand: the focused move's name reaches the screen as a bitmap and its detail --
  # type, power, accuracy, pp, description -- is not spoken at all. Two screens share that exact shape
  # (@pokemon, @moves, a "commands" sprite holding the cursor): the v21 Move Relearner and the egg-move
  # tutor a plugin adds.
  #
  # Named after the job rather than after whichever screen needed it first, and in the shared layer rather
  # than in the fork's folder, so a core reader calling it is not one version crossing into another and the
  # coupling check needs no whitelist entry for it.
  module MoveList
    # The move id under the cursor, or nil when there is no usable selection.
    #
    # The traversal is the same on every one of these screens -- @moves, the "commands" sprite, its index --
    # and it was written out three times: here, in the gen-6 relearner and in a profile's own copy. The
    # [id, tag] unwrap comes from the gen-6 one, where BetterMoveRelearner pairs each id with a tag; it is
    # inert on a plain list, so one implementation serves all three instead of the newest screen quietly
    # lacking a case the oldest already handled.
    def self.focused_id(scene)
      moves = PokeAccess.ivar(scene, :@moves)
      idx = (PokeAccess.sprite(scene, "commands").index rescue nil)
      return nil unless moves.is_a?(Array) && idx && idx >= 0 && idx < moves.length
      m = moves[idx]
      m.is_a?(Array) ? m[0] : m
    rescue StandardError
      nil
    end

    # Speaks the full detail of the move under the cursor. param scene any hand-drawn move list
    def self.detail(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      id = focused_id(scene)
      return unless pk && id
      d = (GameData::Move.get(id) rescue nil)
      return unless d
      nm = (d.name rescue PokeAccess::I18n.t(:info_move))
      ty = (GameData::Type.get(d.display_type(pk)).name rescue nil)
      pw = (d.display_damage(pk) rescue PokeAccess.attr_of(d, :power, :base_damage)).to_i
      acc = (d.display_accuracy(pk) rescue (d.accuracy rescue 0)).to_i
      tot = PokeAccess.attr_of(d, :total_pp, :totalpp)
      desc = (d.description rescue "")
      s = PokeAccess::MoveInfo.line(nm.to_s, ty, pw, acc, :pp => tot, :total_pp => tot, :desc => desc)
      PokeAccess.speak(s, true)
    rescue StandardError
      nil
    end
  end
end
