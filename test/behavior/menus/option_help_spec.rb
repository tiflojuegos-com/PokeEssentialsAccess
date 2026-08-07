# La ayuda por opcion de la pantalla de Ajustes, y el widget que se le parece y no lo es.
#
# @sprites["textbox"] es una caja de ayuda en unos juegos y la MUESTRA DEL MARCO DE DIALOGO en la mayoria
# de los gen-6: cuatro escriben ahi "Marco de dialogo N", uno un rotulo fijo y otro no tiene el sprite. Con
# el raspado a secas la tecla de info contestaba esa constante sobre cualquier opcion, que es una frase que
# no describe lo que hay bajo el cursor.
module OptHelpRig
  class Box
    attr_accessor :text
    def initialize(t); @text = t; end
  end

  # El valor de cada opcion se guarda en la propia ventana, indexada por opcion, como hacen estas escenas.
  class Opt
    attr_accessor :index
    def initialize(i); @index = i; @vals = Hash.new(0); end
    def [](k); @vals[k]; end
    def []=(k, v); @vals[k] = v; end
  end

  class Scene
    def initialize(text, idx)
      @sprites = { "textbox" => Box.new(text), "option" => Opt.new(idx) }
    end

    def at(text, idx, val = nil)
      @sprites["textbox"].text = text
      @sprites["option"].index = idx
      @sprites["option"][idx] = val unless val.nil?
      self
    end
  end
end

Suite.define("menus: la muestra del marco de dialogo no se ofrece como ayuda") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 0)

  # Sobre la primera opcion todavia no se sabe nada, asi que no se guarda: el silencio es la respuesta
  # honesta hasta que el widget demuestre que cambia con la opcion.
  PokeAccess::OptionHelp.read(s)
  falsy("nada guardado con una sola muestra", PokeAccess::Info.info_text.to_s.include?("Marco"))

  # Y con el cursor en otra opcion sigue diciendo lo mismo: eso lo delata como rotulo, no como ayuda.
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 1))
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 2))
  falsy("un texto constante nunca se ofrece", PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: cambiar el marco de dialogo tampoco lo acredita") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 3)
  s.at("Marco de dialogo 1.", 3, 0)

  # Sobre la propia opcion del marco, moverla reescribe la muestra. El texto cambia sin que el cursor se
  # mueva, que es la otra via de acreditacion -- pero el VALOR cambia con el, asi que no cuenta.
  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 2.", 3, 1))
  falsy("el texto cambia porque cambio el valor, no porque sea ayuda",
        PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: una ayuda de verdad si llega a la tecla de info") do
  PokeAccess::Info.set_info(:text, nil)
  s = OptHelpRig::Scene.new("Velocidad del texto del juego.", 0)

  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Activa o desactiva el sonido.", 1))
  truthy("dos opciones con textos distintos lo acreditan",
         PokeAccess::Info.info_text.to_s.include?("sonido"))

  # Acreditado ya, sigue actualizandose en cada opcion, repetidos incluidos.
  PokeAccess::OptionHelp.read(s.at("Marco de dialogo 1.", 2))
  truthy("y a partir de ahi se ofrece siempre", PokeAccess::Info.info_text.to_s.include?("Marco"))
end

Suite.define("menus: la ayuda de la PRIMERA opcion tambien se lee") do
  PokeAccess::Info.set_info(:text, nil)
  # La forma exacta del fork que si tiene ayuda: la caja nace con la muestra del marco y un frame despues
  # la sobrescribe la descripcion real, sin que el jugador haya tocado nada. Sobre la regla del indice a
  # secas, la opcion en la que abre la pantalla se quedaba sin leer hasta mover el cursor.
  s = OptHelpRig::Scene.new("Marco de dialogo 1.", 0)
  s.at("Marco de dialogo 1.", 0, 0)
  PokeAccess::OptionHelp.read(s)
  PokeAccess::OptionHelp.read(s.at("Ajusta el volumen de la musica del juego", 0, 0))
  truthy("mismo indice y mismo valor, texto distinto: es ayuda",
         PokeAccess::Info.info_text.to_s.include?("volumen"))
end
