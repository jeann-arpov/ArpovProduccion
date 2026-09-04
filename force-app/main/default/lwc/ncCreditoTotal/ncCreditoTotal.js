import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";

export default class NcCreditoTotal extends NavigationMixin(LightningElement) {
  @api recordId;

  @wire(CurrentPageReference)
  getPageRef(pageRef) {
    if (pageRef?.state?.c__recordId) {
      this.recordId = pageRef.state.c__recordId;
    }
  }

  get flowInputs() {
    return this.recordId
      ? [
          {
            name: "recordId",
            type: "String",
            value: this.recordId
          }
        ]
      : [];
  }

  handleStatusChange(event) {
    if (event.detail.status === "FINISHED") {
      const listUrl = `${basePath}/venta-ht/Venta_HT__c/Default`;
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: { url: listUrl }
      });
    }
  }
}
