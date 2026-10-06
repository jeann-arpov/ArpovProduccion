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

  handleButtonClick() {
    if (this.buttonUrl) {
      window.location.href = this.buttonUrl;
    }
  }
}
