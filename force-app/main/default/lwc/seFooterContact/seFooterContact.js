import { LightningElement, wire } from "lwc";
import logows from "@salesforce/resourceUrl/logows";
import getFooterCtaConfig from "@salesforce/apex/FooterContactController.getFooterCtaConfig";

export default class SeFooterContact extends LightningElement {
  iconContactenosUrl = logows;

  mostrarCta = false;
  textoCta = "¡Resolvé tu duda!";
  urlCta = "";
  mostrarBadgeNuevo = false;

  @wire(getFooterCtaConfig)
  wiredConfig({ error, data }) {
    if (data) {
      this.mostrarCta = data.mostrar;
      this.textoCta = data.texto;
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
    const phone = "5491131172022";
    const message = "Hola, quiero más información";
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
    window.open(url, "_blank");
  }

  handleResolveDuda() {
    window.open(this.urlCta, "_blank");
  }
}