import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { trackEvent } from "c/utils";

export default class CrearCesionPph extends NavigationMixin(LightningElement) {
  redirect(event) {
    trackEvent("cesion_iniciada");
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
