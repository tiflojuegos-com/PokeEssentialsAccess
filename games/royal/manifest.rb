# Load order for the royal game modules (no .rb), loaded after core. Edit to add/reorder.
# Five of this game's screens come from THIRD-PARTY plugins other fangames ship too (the berry dex, the
# Hall of Fame PC viewer, the photo album and the secret-base decorating flow), so their readers live in
# plugins/ and are declared below instead of being copied here. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    selectors
    currydex
    curry_select
    menu_parrilla
    gacha
    tarjetas_liga
    tarjeta_entrenador
    mep_exp
    curry_result
    iconos_leyenda
    puntos
    rhythm
  ],
  :plugins => %w[berrydex hall_of_fame_bw photo_album secret_bases]
}
