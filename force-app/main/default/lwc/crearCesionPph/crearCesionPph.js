import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { trackGa4Event } from "c/portalGa4Events";

export default class CrearCesionPph extends NavigationMixin(LightningElement) {
  redirect(event) {
    trackGa4Event("cesion_iniciada");
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: {
        pageName: "cesion-pph"
      },
      state: {
        recordId: "new",
        type: event.target.dataset.name
      }
    });
  }
}
