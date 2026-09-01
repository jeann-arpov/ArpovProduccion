import { LightningElement, wire } from "lwc";
import logows from "@salesforce/resourceUrl/logows";
import getFooterCtaConfig from "@salesforce/apex/FooterContactController.getFooterCtaConfig";

export default class FooterContact extends LightningElement {
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

  handleWhatsapp() {
    const phone = "5491131172022"; // Número con código de país, sin signos
    const message = "Hola, quiero más información";
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
    window.open(url, "_blank");
  }

  handleResolveDuda() {
    window.open(this.urlCta, "_blank");
  }
}
