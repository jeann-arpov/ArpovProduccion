import { LightningElement, track, api } from 'lwc';

import getBatchJobs from '@salesforce/apex/BatchApexMonitorAuraService.getBatchJobs';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class BatchApexMonitor extends LightningElement {
    
    @track progress = 0;
    @track status;
    

    connectedCallback() {
        // Just to show that is moving
        this.progress = 10;
    }

    @track _value
    @api
    get value () { 
        return this._value 
    }
    set value (val) {
        this._value = val
        if (val) {
            this.checkBatchStatus()
        }
    }

    checkBatchStatus(){

        const thisReference = this;

        getBatchJobs({
            batchId : this._value
        }).then(result => {
            console.log(result);
            this.progress = (result[0].percentComplete >= this.progress) ? result[0].percentComplete : this.progress;
            this.status = result[0].status;

            if(result[0].status != "Completed"){
            
                setTimeout(
                    function() {
                        thisReference.checkBatchStatus();
                    }, 
                    5000
                );
            
            }else{

                this.dispatchEvent(new CustomEvent('completed'));
            
            }

        })
        .catch(error => {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!!',
                    message: JSON.stringify(error),
                    variant: 'error',
                }),
            );     
        });   

    }

    get progressWidth(){
        return 'width:'+this.progress+'%';
    }

}