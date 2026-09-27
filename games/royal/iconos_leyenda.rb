# Royal's move-flag legend (IconosLeyenda_Scene, D on the move menu), a static image: its transcription in lang/
# (royal_icon_legend, from iconos_leyenda.png) is said as it opens.
PokeAccess::Game.define("royal") do
  read_on_open("IconosLeyenda_Scene") { |_s| PokeAccess::I18n.t(:royal_icon_legend) }
end
