module PokeAccess
  # Realidea's sticker album (Albumfotos), read on each inputs frame: a 2x3 card grid (@selec 0..5 on page
  # @pagina of @paginas), a card's detail (@sprites["foto"]) and its back (@girado), which names the illustrator.
  module RealideaAlbum
    # The album state to dedup on: detail-vs-grid, cursor, page and flip.
    def self.state(scene)
      detail = (scene.instance_variable_get(:@sprites)["foto"].visible rescue false)
      [detail,
       PokeAccess.ivar(scene, :@selec),
       PokeAccess.ivar(scene, :@pagina),
       (scene.instance_variable_get(:@girado) rescue false)]
    rescue StandardError
      nil
    end

    # A page counter as a number the sentence can carry: anything nil, zero or negative becomes 1.
    def self.positive_or(v)
      n = v.to_i
      n > 0 ? n : 1
    rescue StandardError
      1
    end

    # The spoken line for the current focus; @paginas stays nil until the album holds a photo (positive_or).
    def self.line(scene)
      sel = (scene.instance_variable_get(:@selec) rescue 0).to_i
      page = positive_or(PokeAccess.ivar(scene, :@pagina))
      pages = positive_or(PokeAccess.ivar(scene, :@paginas))
      sprites = PokeAccess.ivar(scene, :@sprites)
      detail = (sprites && sprites["foto"].visible rescue false)
      card = (sel + 1) + (page - 1) * 6
      if detail
        if (scene.instance_variable_get(:@girado) rescue false)
          info = PokeAccess.ivar(scene, :@info1)
          author = (info && info[card - 1]) ? info[card - 1].to_s : ""
          return PokeAccess.clean(author)
        end
        return PokeAccess::I18n.t(:album_card, :n => card)
      end
      filled = (sprites && sprites["fotito#{sel + 1}"] && sprites["fotito#{sel + 1}"].visible rescue false)
      st = filled ? PokeAccess::I18n.t(:album_have) : PokeAccess::I18n.t(:album_empty)
      return "#{PokeAccess::I18n.t(:album_card, :n => card)}, #{st}" unless PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess::I18n.t(:album_slot, :n => card, :page => page, :pages => pages, :state => st)
    rescue StandardError
      nil
    end

    # Reads the focus when it changes.
    def self.announce(scene)
      st = state(scene)
      return unless PokeAccess::Cursor.changed?(scene, :album_state, st)
      t = line(scene)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  after("Albumfotos", :inputs) { |scene, _result, _args| PokeAccess::RealideaAlbum.announce(scene) }
end
