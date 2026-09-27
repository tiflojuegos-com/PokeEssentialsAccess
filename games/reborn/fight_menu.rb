# Reborn's fight menu: the move line says the type the move will really have (Reborn's pbType: the field, abilities,
# crests), a second type the field adds, and whether the field boosts or weakens it, as the game's own pbFieldNotesBattle
# works it out for the button's highlight; with Z-Move on, the Z-move takes the move's place. Z-Move sits on its own
# zButton, beside the mega and ultra ones core already reads.
module PokeAccess
  module RebornFight
    # Whether the Z-Move button is on and the focused move has a Z-move to become.
    def self.z_on?(disp, b, idx)
      (disp.zButton rescue 0) == 2 && (b.pbCompatibleZMoveFromMove?(idx, true) rescue false) ? true : false
    end

    # The move line for the focused slot, said when the slot or the Z-Move switch changes.
    def self.read(disp, interrupt = true)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      base = (b.moves[idx] rescue nil)
      return unless base && PokeAccess::MoveInfo.real_id?(PokeAccess::MoveInfo.id_of(base))
      z = z_on?(disp, b, idx)
      m = z ? b.zmoves[idx] : base
      PokeAccess::Cursor.on_change(disp, :fight_move, [idx, z]) do
        PokeAccess.speak_clean(PokeAccess::Verbosity.line(:battle_move, parts(b, m, base, z), ". "), interrupt, :menu)
        PokeAccess::Info.set_info(:move, m)
      end
    rescue StandardError
      nil
    end

    # The line's parts at their verbosity levels; a Z-move has no PP of its own.
    def self.parts(b, m, base, z)
      id = PokeAccess::MoveInfo.id_of(m)
      ty = PokeAccess::Data.type_name((m.pbType(b) rescue nil) || m.type)
      pp = z ? nil : PokeAccess::I18n.t(:mv_pp, :pp => m.pp, :tot => PokeAccess.attr_of(m, :totalpp, :total_pp))
      [[(PokeAccess::Data.move_name(id) || m.name).to_s, :brief],
       [ty ? PokeAccess::I18n.t(:mv_type, :t => ty) : nil, :medium],
       [second_type(b, m), :medium],
       [PokeAccess::MoveInfo.category_word(PokeAccess::MoveInfo.category_of(m)), :full],
       [pp, :brief],
       [field_word(base), :medium]]
    end

    # The type the field adds to the move, as Reborn's own reader words it: a random one on Rainbow, a crystal one on
    # Crystal Cavern (Flying Press excepted, whose second type is its own), else the types themselves unless they
    # repeat the move's; nil when it adds none.
    def self.second_type(b, m)
      extra = (m.getSecondaryType(b) rescue nil)
      return nil if extra.nil? || extra.empty?
      press = PokeAccess::MoveInfo.id_of(m) == :FLYINGPRESS
      fe = (b.battle.FE rescue nil)
      return PokeAccess::I18n.t(:reb_move_random_type) if fe == :RAINBOW && !press
      return PokeAccess::I18n.t(:reb_move_crystal_type) if fe == :CRYSTALCAVERN && !press
      return nil if extra.include?((m.pbType(b) rescue nil))
      names = extra.map { |t| PokeAccess::Data.type_name(t) }.compact
      names.empty? ? nil : PokeAccess::I18n.t(:reb_move_also_type, :t => names.join(", "))
    end

    # Boosted or weakened by the field, by the game's own pbFieldNotesBattle (0 when the player has not yet read the
    # field's notes, or has the highlights off).
    def self.field_word(move)
      case (pbFieldNotesBattle(move) rescue 0)
      when 1 then PokeAccess::I18n.t(:reb_move_boosted)
      when 2 then PokeAccess::I18n.t(:reb_move_weakened)
      end
    end

    # The Z-Move button: available when it comes up, on and off as it toggles, and the move re-read as it changes.
    def self.z_button(disp, v)
      last = disp.instance_variable_get(:@access_z)
      disp.instance_variable_set(:@access_z, v) if v.is_a?(Integer)
      if PokeAccess::Battle.mega_reveal?(last, v)
        PokeAccess.speak(PokeAccess::Battle.ready_text(:zmove), false)
        return
      end
      k = PokeAccess::Battle.zud_key(:zmove, last, v)
      return unless k.is_a?(Array)
      PokeAccess.speak(PokeAccess::I18n.t(k[0], :name => PokeAccess::I18n.t(k[1])), true)
      read(disp, false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  override("PokeAccess::Battle", :read_fight_move) do |_mod, _original, args|
    PokeAccess::RebornFight.read(args[0], args.length > 1 ? args[1] : true)
  end
  after("FightMenuDisplay", :zButton=, :optional => true) { |disp, _r, args| PokeAccess::RebornFight.z_button(disp, args[0]) }
end
