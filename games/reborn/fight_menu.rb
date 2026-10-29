# Reborn's fight menu: the move line says the type the move will really have (Reborn's pbType), a second type the field
# adds and whether the field boosts or weakens it, as pbFieldNotesBattle works it out; with the Z-Move button on
# (rv_common's FightRV), the Z-move takes the move's place.
module PokeAccess
  module RebornFight
    # The move line for the focused slot, said when the slot or the Z-Move switch changes; the info key keeps the move,
    # Ctrl+T the line whole.
    def self.read(disp, interrupt = true)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      base = (b.moves[idx] rescue nil)
      return unless base && PokeAccess::MoveInfo.real_id?(PokeAccess::MoveInfo.id_of(base))
      zm = PokeAccess::FightRV.z_move(disp, b, idx)
      z = !zm.nil?
      m = zm || base
      PokeAccess::Cursor.on_change(disp, :fight_move, [idx, z]) do
        said = parts(b, m, base, z)
        PokeAccess.speak_clean(PokeAccess::Verbosity.line(:battle_move, said, ". "), interrupt, :menu)
        PokeAccess::Info.set_info(:move, m, PokeAccess::Verbosity.full_line(said, ". "))
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The line's parts at their verbosity levels: core's fight line, with the type the field adds after the move's own
    # and the field's boost last, both from medium; a Z-move has no PP of its own.
    def self.parts(b, m, base, z)
      id = PokeAccess::MoveInfo.id_of(m)
      ty = PokeAccess::Data.type_name(PokeAccess::FightRV.painted_type(m, b))
      pp = z ? nil : PokeAccess::Battle.fight_pp(m)
      line = PokeAccess::Battle.fight_parts(m, PokeAccess::Data.move_name(id) || m.name, ty, pp)
      line.insert(2, [second_type(b, m), :medium]).push([field_word(base), :medium])
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
  end
end

PokeAccess::Game.define("reborn") do
  override("PokeAccess::Battle", :read_fight_move) do |_mod, _original, args|
    PokeAccess::RebornFight.read(args[0], args.length > 1 ? args[1] : true)
  end
end
