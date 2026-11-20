import { LightningElement, wire } from "lwc";
import getFooterCtaConfig from "@salesforce/apex/FooterContactController.getFooterCtaConfig";
import { trackGa4Event, resolveModuloFromPath } from "c/portalGa4Events";

export default class SeFooterContact extends LightningElement {
  mostrarCta = false;
  textoCta = "¡Resolvé tu duda!";
  urlCta = "";
  mostrarBadgeNuevo = false;

  @wire(getFooterCtaConfig)
  wiredConfig({ error, data }) {
    if (data) {
      this.mostrarCta = data.mostrar;
      this.textoCta = this.textoSinTildePronombre(data.texto || this.textoCta);
      this.urlCta = data.url;
      this.mostrarBadgeNuevo = data.mostrarBadgeNuevo;
    } else if (error) {
      console.error(error);
    }
  }

  renderedCallback() {
    const pin = document.documentElement.classList.contains("se-chrome");
    const home = document.documentElement.classList.contains("se-home");
    const inner = document.documentElement.classList.contains("se-inner");
    this.classList.toggle("se-footer-pin", pin);
    this.classList.toggle("se-footer-home", pin && home);
    this.classList.toggle("se-footer-inner", pin && inner && !home);
  }

  handleWhatsapp() {
    this.trackContactoGa4("whatsapp");
    const phone = "5491131172022";
    const message = "Hola, quiero más información";
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
    window.open(url, "_blank");
  }

  handleResolveDuda() {
    this.trackContactoGa4("preguntas_frecuentes");
    window.open(this.urlCta, "_blank");
  }

  trackContactoGa4(canal) {
    trackGa4Event("contacto_click", {
      canal,
      modulo: resolveModuloFromPath()
    });
  }

  textoSinTildePronombre(texto) {
    return String(texto || "").replace(/tú/gi, "tu");
  }
}