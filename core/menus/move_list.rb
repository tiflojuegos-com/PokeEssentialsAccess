module PokeAccess
  # Hand-drawn move lists (@pokemon, @moves, a "commands" sprite holding the cursor), shared by the relearners and
  # plugin screens of that shape: the focused move and its spoken detail.
  module MoveList
    # The move id under the cursor, unwrapping BetterMoveRelearner's [id, tag] pairs, or nil.
    def self.focused_id(scene)
      moves = PokeAccess.ivar(scene, :@moves)
      idx = (PokeAccess.sprite(scene, "commands").index rescue nil)
      return nil unless moves.is_a?(Array) && idx && idx >= 0 && idx < moves.length
      m = moves[idx]
      m.is_a?(Array) ? m[0] : m
    rescue StandardError
      nil
    end

    # The tag a row paints beside its move (BetterMoveRelearner's "MT" on a machine move), or "" for a plain row.
    def self.focused_tag(scene)
      moves = PokeAccess.ivar(scene, :@moves)
      idx = (PokeAccess.sprite(scene, "commands").index rescue nil)
      return "" unless moves.is_a?(Array) && idx && idx >= 0 && idx < moves.length && moves[idx].is_a?(Array)
      PokeAccess.clean(moves[idx][1].to_s)
    rescue StandardError
      ""
    end

    # Speaks the focused move's detail at the learn move reading's level, led once per scene by its title where a
    # profile gives one; the info key keeps the move whole. A list with no Pokemon reads the move's own data.
    def self.detail(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      id = focused_id(scene)
      return unless id
      d = (GameData::Move.get(id) rescue nil)
      return unless d
      nm = (d.name rescue PokeAccess::I18n.t(:info_move))
      ty = (GameData::Type.get((d.display_type(pk) rescue d.type)).name rescue nil)
      pw = (d.display_damage(pk) rescue PokeAccess.attr_of(d, :power, :base_damage))
      pw = pw.to_i if pw
      acc = (d.display_accuracy(pk) rescue (d.accuracy rescue nil))
      acc = acc.to_i if acc
      tot = PokeAccess.attr_of(d, :total_pp, :totalpp)
      desc = (d.description rescue "")
      cat = PokeAccess::MoveInfo.category_word((d.display_category(pk) rescue (d.category rescue nil)))
      opts = { :cat => cat, :pp => tot, :total_pp => tot, :desc => desc }
      PokeAccess::Info.set_info(:text, PokeAccess::MoveInfo.line(nm.to_s, ty, pw, acc, opts))
      line = PokeAccess::MoveInfo.leveled(:learn_move, nm.to_s, ty, pw, acc, opts)
      head = title(scene)
      line = "#{head}. #{line}" if head && !head.empty? && PokeAccess::Cursor.changed?(scene, :move_list_title, head)
      PokeAccess.speak(line, true)
    rescue StandardError
      nil
    end

    # The list's painted title, said ahead of its first move, or nil: core reads none, a profile overrides it.
    def self.title(_scene)
      nil
    end
  end
end
