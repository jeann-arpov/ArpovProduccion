import { LightningElement, api } from "lwc";

export default class CampaignBanner extends LightningElement {
  @api title = "PRECAMPAÑA SOJA 26/27";
  @api highlightText = "¡Comprá antes, pagá menos!";
  @api description =
    "Adquirí tus HT Futuras con anticipación y accedé a un valor preferencial.";
  @api buttonText = "Comprá tus HT Futuras";
  @api buttonUrl = "";
  @api startDate;
  @api endDate;

  get isVisible() {
    if (this.esPrecampanaSoja) return false;
    if (!this.startDate) return false;

    const now = new Date();
    const start = new Date(this.startDate);

    if (isNaN(start.getTime()) || now < start) return false;

    if (this.endDate) {
      const end = new Date(this.endDate);
      if (!isNaN(end.getTime()) && now > end) return false;
    }

    return true;
  }

  get esPrecampanaSoja() {
    const texto = `${this.title || ''} ${this.highlightText || ''} ${this.description || ''}`
      .replace(/<[^>]+>/g, ' ')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toUpperCase();
    return texto.includes('SOJA') && texto.includes('PRECAMPANA');
  }

  handleButtonClick() {
    if (this.buttonUrl) {
      window.location.href = this.buttonUrl;
    }
  }
}
