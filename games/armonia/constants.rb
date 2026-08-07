# Pokemon Armonia constants: vanilla Essentials 16.3, the same gen-6 base as the core defaults, so this
# only relabels the field button the remap menu shows (everything generic is already covered by core).
#
# X en el MAPA cambia al Pokemon seguidor anterior (FOLLOW_KEY_PREVIOUS del script del follow). El DexNav
# tambien esta en X, pero solo DENTRO del menu de pausa, asi que rotularlo como DexNav en el menu de teclas
# describia una accion que esa tecla no hace donde el jugador la va a pulsar.
PokeAccess::Game.define("armonia") do
  button_labels :x => :arm_btn_x
end
