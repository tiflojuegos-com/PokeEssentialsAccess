# Africanvs's picture-only screens: the character choice's portraits, the Carthage arm wrestling's keys and marker,
# the INFORMACION bar, the credits and the Union of Amat's map.
PokeAccess::Game.define("africanus") do
  picture_texts("Protas1" => :afr_vir, "Protas2" => :afr_femina)
end

module PokeAccess
  module AfricanusPictures
    # The arm wrestling's key pictures: the button the event reads for each (Map059 ev16, buttons 11, 15, 14, 17 and
    # 13) and the letter the picture paints.
    PULSE_KEYS = { "Tecla1" => [:a, "Z"], "Tecla2" => [:y, "S"], "Tecla3" => [:x, "A"], "Tecla4" => [:l, "Q"],
                   "Tecla5" => [:c, "C"] }
    # Where and while the wrestling runs (Map059 ev14 p2): its map and switch, the variable holding the marker's x,
    # the value that loses it and the span above it that wins it (425), and the steps the tick divides that span into.
    PULSE_MAP = 59
    PULSE_SWITCH = 289
    PULSE_VAR = 92
    PULSE_LOSE = 70
    PULSE_SPAN = 355
    PULSE_STEPS = 20
    # The information bar (Maps 022 and 091, variable 35): its pictures, the label they paint, the same Spanish
    # picture in both builds (the _eng ones are never shown), and the thirds that fill it.
    INFO_BAR = /\Ainformacion (\d)\z/
    INFO_LABEL = "Información"
    INFO_THIRDS = 3
    # The credits pictures (Maps 249, 211, 245, 256, 247, 257, 248, 244 and 246, then Map016's closing ones),
    # transcribed; a room's card paints its name in capitals twice, said once.
    CREDITS = {
      "CreditosTeamCW" => "Arkeh, Alex170kc",
      "Creditos1" => "Aitxol, Difusor, Karuta, Trinxat",
      "CreditosBezier" => "Bezier",
      "Creditos2" => "Dewy, Georaptor, Pablus, Vaz",
      "Creditosextra" => "Clara, Okvo, Scept, Eus",
      "CreditosDan" => "Dan",
      "Creditos3" => "Aveontrainer, Cero1533, ChaoticCherryCake, Ditto209",
      "CreditosSpriters" => "Hellfire, Divaruta",
      "Creditos4" => "Derfischae, Eduar, Ericlostie, Evolina",
      "CreditosIrene" => "Ireneide",
      "Creditos5" => "Hek, Hydrargium, Jotaaz, Kid",
      "CreditosPano" => "Pano",
      "Creditos6" => "kidkatt, Kloraka, Logiedant, Marin",
      "CreditosRegreso" => "ElRegresoDeXD",
      "Creditos7" => "Magiscarf, Mej71, PeekyChew, Phyromantical",
      "CreditosRena" => "Rena",
      "Creditos8" => "Princessphoenix, skyflyer, Thatwelsone, Vulvoch",
      "CreditosWings" => "WingsOfDragons",
      "Creditos9" => "Warox1994, Wolfpp, Zatavares, Zero",
      "Creditos10" => "Agradecimientos: Asier, Cheka's Art Productions, Elena, Team Clone Wars, Pokégremio",
      "CREDITOSFIN" => "Creado por El Camid",
      "CREDITOSFIN_eng" => "Game by El Camid",
      "Fin" => "Fin",
      "Fin_eng" => "The End"
    }
    # The Union of Amat's map and its crosses, as [picture, the point's name in townmap.txt, :name or :poi (a point's
    # description)].
    CULT_MAP = "mapa con cultistas"
    CULT_MARKS = [["Cruz1", "Cantera de Slowpokes", :name], ["Cruz2", "Iol", :name], ["Cruz3", "Tarraco", :name],
                  ["Cruz4", "Pisae", :name], ["Cruz5", "Carales", :name], ["Cruz6", "Etna", :poi],
                  ["Cruz7", "Útica", :poi]]

    @last = nil
    @tick_at = nil

    # Says a key, bar, credits or cult map picture the first time it is shown (its event re-shows it every frame): a
    # key cuts the one before, the rest wait for what is being said.
    def self.on_picture(name)
      n = name.to_s
      return if n == @last
      t = text_for(n)
      return if t.nil?
      @last = n
      PokeAccess.speak(t, PULSE_KEYS.has_key?(n))
    end

    # A picture's line: the bound key for a key picture, the bar's label and thirds, the credits' transcription, the
    # cult map's marked places or the place a cross picture strikes out.
    def self.text_for(name)
      key = PULSE_KEYS[name]
      return PokeAccess::KeyHints.key(key[0], key[1]) if key
      m = INFO_BAR.match(name)
      return PokeAccess::I18n.t(:afr_info_bar, :label => INFO_LABEL, :n => m[1].to_i, :total => INFO_THIRDS) if m
      return PokeAccess::I18n.t(:afr_cult_map, :places => cult_places.join(", ")) if name == CULT_MAP
      mark = CULT_MARKS.find { |c| c[0] == name }
      return PokeAccess::I18n.t(:afr_cult_cross, :place => place_name(mark[1], mark[2])) if mark
      CREDITS[name]
    end

    # The cult map's seven marked places, in the order of their cross pictures.
    def self.cult_places
      CULT_MARKS.map { |c| place_name(c[1], c[2]) }
    end

    # A town map point's name as the game's own PlaceNames (or, for :poi, PlaceDescriptions) table gives it in the
    # running language, else as townmap.txt spells it.
    def self.place_name(raw, kind)
      type = kind == :poi ? ::MessageTypes::PlaceDescriptions : ::MessageTypes::PlaceNames
      t = pbGetMessageFromHash(type, raw)
      (t.nil? || t.to_s.empty?) ? raw : t.to_s
    rescue StandardError
      raw
    end

    # Forgets the last picture, so an erased key (the wrestling over) or a map entered anew speaks again.
    def self.reset; @last = nil; end

    # While the wrestling runs, ticks as the marker crosses each step toward the win (higher) or the loss (lower);
    # a marker trembling on a step's edge stays quiet until it has moved a full step.
    def self.pulse_poll
      unless pulse_running?
        @tick_at = nil
        return
      end
      v = ($game_variables[PULSE_VAR] rescue nil)
      return if v.nil?
      return if @tick_at && (v.to_f - @tick_at).abs < PULSE_SPAN / PULSE_STEPS.to_f
      @tick_at = v.to_f
      PokeAccess::Spatial.gauge((v.to_f - PULSE_LOSE) / PULSE_SPAN)
    end

    # True on the wrestling's map while its switch is on.
    def self.pulse_running?
      on_map = ($game_map.map_id == PULSE_MAP rescue false)
      on_map && ($game_switches[PULSE_SWITCH] rescue false) ? true : false
    end
  end
end

PokeAccess::Caches.register(:afr_pictures) { PokeAccess::AfricanusPictures.reset }

PokeAccess::Game.define("africanus") do
  on_picture { |name, _args| PokeAccess::AfricanusPictures.on_picture(name) }
  after("Game_Picture", :erase) { PokeAccess::AfricanusPictures.reset }
  poll_each_frame { PokeAccess::AfricanusPictures.pulse_poll }
end
