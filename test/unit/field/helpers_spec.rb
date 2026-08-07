# Field overlay readers (mail, itemfinder, money, berry, dex, books, achievements): each is a pure helper
# turning a game object or globals into a spoken line, with an explicit nil for the empty/guarded case.
# Spoken fragments are asserted through I18n, never against a hardcoded language literal.
Suite.define("field: mail and money overlays") do
  mailobj = Struct.new(:message, :sender)
  eq "mail body and sender",
     PokeAccess.mail_text(mailobj.new("Hola", "Rojo")),
     "Hola. #{PokeAccess::I18n.t(:mail_from, :name => 'Rojo')}"
  truthy "empty mail is nil", PokeAccess.mail_text(mailobj.new("", "")).nil?

  winobj = Struct.new(:text)
  eq "money window text",
     PokeAccess.money_window_text(winobj.new("Money:\n<ar>$1,234</ar>")), "Money: $1,234"
  truthy "empty money window is nil", PokeAccess.money_window_text(winobj.new("")).nil?
end

# Itemfinder: direction + distance to the nearest hidden item, or "underfoot" when on the same tile.
Suite.define("field: itemfinder direction and distance") do
  ev_if = Struct.new(:x, :y)
  old_pl = $game_player
  $game_player = ev_if.new(5, 5)
  eq "three steps up",
     PokeAccess.hidden_item_text(ev_if.new(5, 2)),
     PokeAccess::I18n.t(:if_direction, :n => 3, :dir => PokeAccess::I18n.t(:dir_up))
  eq "right underfoot",
     PokeAccess.hidden_item_text(ev_if.new(5, 5)), PokeAccess::I18n.t(:if_underfoot)
  $game_player = old_pl
end

# Berry plant state-at-a-glance: the normalizer flattens the two storage shapes (modern object, gen-6 array)
# to [stage, berry_id, moisture, new_mechanics?]; empty soil yields a nil/zero stage and no state suffix.
Suite.define("field: berry plant state normalization") do
  modberry = Class.new do
    def initialize(s, m); @s = s; @m = m; end
    def growth_stage; @s; end
    def planted?; @s > 0; end
    def new_mechanics; true; end
    def moisture_stage; @m; end
    def berry_id; :ORAN; end
  end
  fakeev = Struct.new(:variable)
  eq "modern reads stage, berry, moisture", PokeAccess::Berry.read(modberry.new(5, 2)), [5, :ORAN, 2, true]
  truthy "modern empty has no stage", PokeAccess::Berry.read(modberry.new(0, 0))[0].nil?
  eq "gen-6 gen4 wet", PokeAccess::Berry.read([4, 7, 1000, 1, 60, 0, 0, 0]), [4, 7, 2, true]
  eq "gen-6 gen3 no moisture", PokeAccess::Berry.read([2, 7, false, 1, 0, 0]), [2, 7, nil, false]
  eq "nil is empty soil", PokeAccess::Berry.read(nil), [nil, nil, nil, false]
  eq "empty soil has no suffix",
     PokeAccess::Berry.state_suffix(fakeev.new([0, 0, 0, 0, 0, 0, 0, 0])), ""
  suffix = PokeAccess::Berry.state_suffix(fakeev.new([4, 0, 1000, 1, 60, 0, 0, 0]))
  truthy "suffix starts with the stage",
         suffix.start_with?(", #{PokeAccess::I18n.t(:berry_flowering)}")
end

# Spoken cues that have no live engine in the harness: the reflex wrap, the phone rematch and the fishing
# bite still resolve to a real localized string (never the bare key), and readiness guards to false.
Suite.define("field: guarded cues resolve real localized strings") do
  truthy "fishing bite cue is translated",
         PokeAccess::I18n.t(:fish_bite) != "fish_bite" && !PokeAccess::I18n.t(:fish_bite).empty?
  eq "phone rematch without a scene is not ready", PokeAccess::Phone.rematch_ready?(0), false
  truthy "phone rematch suffix is translated",
         PokeAccess::I18n.t(:phone_rematch) != "phone_rematch" && !PokeAccess::I18n.t(:phone_rematch).empty?
end

# Pokedex / ribbon formatting helpers: one-decimal formatting follows the active language's decimal_sep
# (comma in Spanish, point in English) on both fmt_float (real units) and fmt_dec (tenth units); a nil
# ribbon id is guarded (modern-only; no GameData::Ribbon in the gen-6 harness).
Suite.define("field: dex one-decimal and ribbon guard") do
  prev = PokeAccess::Config.language
  begin
    PokeAccess::Config.language = :es
    truthy "Spanish speaks a comma",
           PokeAccess::Pokedex.fmt_float(60.5) == "60,5" && PokeAccess::Pokedex.fmt_dec(15) == "1,5"
    PokeAccess::Config.language = :en
    truthy "English speaks a point",
           PokeAccess::Pokedex.fmt_float(60.5) == "60.5" && PokeAccess::Pokedex.fmt_dec(15) == "1.5"
  ensure
    PokeAccess::Config.language = prev
  end
  truthy "nil ribbon id is guarded", PokeAccess::RibbonsV21.ribbon_text(nil).nil?
end

# Tip cards (tutorial-card addon): reads the focused card's title + body via the game's _INTL + Settings
# table (stubbed here), stripping markup; an out-of-range index yields nil.
Suite.define("field: tip card title and body") do
  def _INTL(s, *_a); s; end
  module ::Settings
    TIP_CARDS_CONFIGURATION = { :swim => { :Title => "Como nadar", :Text => "Usa <b>Surf</b> en el agua." } }
  end unless defined?(::Settings::TIP_CARDS_CONFIGURATION)
  tipscene = Object.new
  tipscene.instance_variable_set(:@tips, [:swim]); tipscene.instance_variable_set(:@index, 0)
  eq "title and cleaned body", PokeAccess.tip_card_text(tipscene), "Como nadar. Usa Surf en el agua."
  tipscene.instance_variable_set(:@index, 5)
  truthy "out-of-range index is nil", PokeAccess.tip_card_text(tipscene).nil?
end

# Book reader: the current page's text, cleaned of markup; an out-of-range or nil page yields nil.
Suite.define("field: book page reader") do
  libro = ["Pagina uno con <b>negrita</b>.", "Pagina dos."]
  eq "page cleaned of markup", PokeAccess.book_text(libro, 0), "Pagina uno con negrita."
  truthy "out-of-range page is nil", PokeAccess.book_text(libro, 9).nil?
  truthy "nil book is nil", PokeAccess.book_text(nil, 0).nil?
end

# Indexed achievements: name, status and description, whatever the entry hands over. Status constants are
# absent in the harness, so the helper falls back to 3/2/1 (done / pending / locked).
#
# The locked case keeps its description ON PURPOSE. Whether an unearned achievement withholds its text is
# the game's decision, and each copy has already taken it inside name/desc -- one substitutes a placeholder
# there, the others hand over the real strings and paint them -- so a second layer of hiding in the reader
# would silence the copies that hide nothing.
Suite.define("field: indexed achievement status") do
  flogro = Struct.new(:name, :status, :desc)
  eq "completed shows description",
     PokeAccess.logro_indexed_text(flogro.new("Campeon", 3, "Vence a la Liga.")),
     "Campeon, #{PokeAccess::I18n.t(:ach_done)}. Vence a la Liga."
  eq "locked keeps the description the screen is showing",
     PokeAccess.logro_indexed_text(flogro.new("Primera medalla", 1, "Consigue tu primera medalla.")),
     "Primera medalla, #{PokeAccess::I18n.t(:ach_locked)}. Consigue tu primera medalla."
  eq "and repeats the placeholder when the game is the one hiding it",
     PokeAccess.logro_indexed_text(flogro.new("????", 1, "Logro no disponible.")),
     "????, #{PokeAccess::I18n.t(:ach_locked)}. Logro no disponible."
  eq "active is pending with description",
     PokeAccess.logro_indexed_text(flogro.new("Pescador", 2, "Pesca 10.")),
     "Pescador, #{PokeAccess::I18n.t(:ach_pending)}. Pesca 10."
end
