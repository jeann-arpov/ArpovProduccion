import { api, track, LightningElement } from 'lwc';

export default class prueba extends LightningElement {

    @api recordId;
    @api objectApiName;

    // This is an example of a variable tracked by LWC
    // the layout is rerendered if any tracked variable is changed
    @track variable = null;

    /**
     * Executed when the component is added to the DOM.
     * @returns {Promise<void> | void} 
     */
    async connectedCallback() {
        // Todo: remove me or add code
    }

    /**
     * Executed by the framework when the LWC component is removed 
     * from the DOM; use this to put any clean-up code when required
     * @returns {Promise<void> | void} 
     */
    disconnectedCallback() {
        // Todo: remove me or add code
    }
}