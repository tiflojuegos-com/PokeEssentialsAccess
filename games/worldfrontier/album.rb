# World Frontier's trainer album ([WF] Album Entrenadores): a grid of the trainers of one generation and the card of
# one of them. The grid says its title, generation and seen count as it opens or changes generation, then the focused
# trainer as painted (the name, or ??? before the first battle) and its place; the card says what it paints.
module PokeAccess
  module WfAlbum
    # The focused trainer's grid line: the name the cell paints and its place in the generation's list.
    def self.cell_line(scene)
      list = PokeAccess.ivar(scene, :@list)
      idx = PokeAccess.ivar(scene, :@index)
      return nil unless list.is_a?(Array) && idx.is_a?(Integer) && list[idx]
      t = list[idx]
      name = seen?(t) ? (AlbumEntrenadores.display_name(t) rescue "").to_s : "???"
      PokeAccess::Verbosity.list_entry(name, idx + 1, list.length)
    end

    # True once the player has fought the trainer.
    def self.seen?(trainer)
      (AlbumEntrenadores.seen?(trainer.id) rescue false) ? true : false
    end

    # The header the grid paints: the generation and how many of its trainers were seen.
    def self.header(scene)
      gen = (scene.current_gen rescue nil)
      return nil unless gen
      seen = (AlbumEntrenadores.seen_count(gen) rescue 0)
      total = (AlbumEntrenadores.total_count(gen) rescue 0)
      "#{_INTL('Gen. {1}', gen)}, #{_INTL('{1}/{2}', seen, total)}"
    end

    # After each repaint of the grid: the title and header when it opens, the header again when the generation
    # changes, and the focused trainer whenever it moves; the info key holds the trainer's card.
    def self.grid(scene)
      opening = PokeAccess::Cursor.pending?(scene, :wf_album_gen)
      gen = PokeAccess.ivar(scene, :@gen_index)
      if PokeAccess::Cursor.changed?(scene, :wf_album_gen, gen)
        head = header(scene)
        head = PokeAccess.sentences([_INTL("ÁLBUM DE ENTRENADORES"), head]) if opening
        PokeAccess.speak_clean(head, !opening) if head
        PokeAccess::Cursor.reset(scene, :wf_album)
      end
      list = PokeAccess.ivar(scene, :@list)
      t = (list.is_a?(Array) && PokeAccess.ivar(scene, :@index).is_a?(Integer)) ? list[PokeAccess.ivar(scene, :@index)] : nil
      PokeAccess::Info.set_info(:text, card_text(t, nil, nil)) if t
      said = PokeAccess::Cursor.announce(scene, :wf_album, [gen, PokeAccess.ivar(scene, :@index)], true, false) do
        cell_line(scene)
      end
      footer(scene) if opening && said
    end

    # The keys the grid's footer paints, while hints are said.
    def self.footer(scene)
      keys = [:AUX1, :AUX2, :USE, :BACK].map { |k| (scene.key_name(k) rescue "?") }
      PokeAccess::WfHint.say(_INTL("[{1}]/[{2}]: Generación     [{3}]: Ficha     [{4}]: Salir", *keys))
    end

    # A team member as the card's icon shows it: the species with the form its ace shows, and the battle mechanic its
    # tint or outline marks.
    def self.member(entry)
      form = (AlbumEntrenadores.party_icon_form(entry) rescue entry[:form])
      name = PokeAccess::WfSpecies.name(entry[:species], form)
      mark = mechanic_word(entry)
      mark ? "#{name}, #{mark}" : name
    end

    # The word for the mechanic an icon's tint or outline shows, or nil.
    def self.mechanic_word(entry)
      case (AlbumEntrenadores.entry_mechanic(entry) rescue nil)
      when :tera
        t = entry[:tera_type] || (AlbumEntrenadores.species_primary_type(entry[:species], entry[:form]) rescue nil)
        word = PokeAccess::I18n.t(:bt_m_tera)
        t ? "#{word}, #{PokeAccess::I18n.t(:mv_type, :t => PokeAccess::Data.type_name(t))}" : word
      when :dynamax, :gmax then PokeAccess::I18n.t(:bt_m_dynamax)
      when :zmove then PokeAccess::I18n.t(:bt_m_zmove)
      end
    end

    # A trainer's card as painted: the name (??? unseen), the place, the battles, the type of a monotype trainer and
    # the team, the team as silhouettes before the first battle.
    def self.card_text(t, idx, total)
      seen = seen?(t)
      parts = [seen ? (AlbumEntrenadores.full_name(t) rescue "").to_s : "???"]
      parts.push(PokeAccess::Verbosity.position(idx + 1, total)) if idx && total
      parts.push(battles(t, seen))
      team = (AlbumEntrenadores.party_entries(t) rescue [])
      type = seen ? (AlbumEntrenadores.monotype_of(t) rescue nil) : nil
      parts.push(PokeAccess::I18n.t(:mv_type, :t => PokeAccess::Data.type_name(type))) if type
      parts.push(team_line(team, seen)) unless team.empty?
      PokeAccess.sentences(parts.compact)
    end

    # The card's team: each member as its icon shows it, or how many silhouettes stand for it before the first battle.
    def self.team_line(team, seen)
      return PokeAccess::I18n.t(:wf_album_team_hidden, :n => team.length) unless seen
      PokeAccess::I18n.t(:wf_album_team, :list => team.map { |e| member(e) }.join("; "))
    end

    # The battles line the card paints.
    def self.battles(t, seen)
      return _INTL("Enfrentamientos: -   Victorias: -") unless seen
      _INTL("Enfrentamientos: {1}   Victorias: {2}", (AlbumEntrenadores.battle_count(t.id) rescue 0),
            (AlbumEntrenadores.win_count(t.id) rescue 0))
    end

    # After each repaint of the card: the trainer it shows, the title first as it opens and the keys after while
    # hints are said; the info key holds it whole.
    def self.card(scene)
      list = PokeAccess.ivar(scene, :@list)
      idx = PokeAccess.ivar(scene, :@index)
      return unless list.is_a?(Array) && idx.is_a?(Integer) && list[idx]
      opening = PokeAccess::Cursor.pending?(scene, :wf_album_card)
      text = card_text(list[idx], idx, list.length)
      PokeAccess::Info.set_info(:text, PokeAccess.clean(text))
      return unless PokeAccess::Cursor.changed?(scene, :wf_album_card, idx)
      line = text
      if opening
        hint = _INTL("Izq./Der.: Cambiar        [{1}]: Volver", (scene.key_name(:BACK) rescue "X"))
        line = PokeAccess::WfHint.after(PokeAccess.sentences([_INTL("FICHA DE ENTRENADOR"), text]), hint)
      end
      PokeAccess.speak_clean(line, !opening)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("AlbumEntrenadores_Scene", :refresh) { |scene, _r, _a| PokeAccess::WfAlbum.grid(scene) }
  # Back from a card the grid repaints: its trainer is said again, queued.
  before("AlbumEntrenadores_Scene", :open_detail) { |scene, _a| PokeAccess::Cursor.reset(scene, :wf_album) }
  after("AlbumEntrenadores_DetailScene", :refresh) { |scene, _r, _a| PokeAccess::WfAlbum.card(scene) }
end
