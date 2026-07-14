import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';   
export default class BotoneraScreenFlow extends LightningElement {

    @api continue;

    handleCancel(event) {
        this.continue = false;
        this.dispatchAttributeChange();
        this.handleNext();
    }

    handleGoNext(event){
        this.continue = true;
        this.dispatchAttributeChange();
        this.handleNext();
    }

    dispatchAttributeChange(){
        const attributeChangeEvent = new FlowAttributeChangeEvent('continue', this.continue);
        this.dispatchEvent(attributeChangeEvent);
    }

    handleNext(){
        const navigateNextEvent = new FlowNavigationNextEvent();
        this.dispatchEvent(navigateNextEvent);
    }

}