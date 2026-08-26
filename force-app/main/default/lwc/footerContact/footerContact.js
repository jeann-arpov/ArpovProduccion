import { LightningElement } from "lwc";
import logows from "@salesforce/resourceUrl/logows";
import MESA_AYUDA_EMAIL from "@salesforce/label/c.Mesa_Ayuda_Email";

export default class FooterContact extends LightningElement {
  iconContactenosUrl = logows;
  mesaAyudaEmail = MESA_AYUDA_EMAIL;

  handleWhatsapp() {
    const phone = "5491131172022"; // Número con código de país, sin signos
    const message = "Hola, quiero más información";
    const url = `https://wa.me/${phone}?text=${encodeURIComponent(message)}`;
    window.open(url, "_blank");
  }
}
