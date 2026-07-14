import { LightningElement, api } from 'lwc';
import getTemplates from '@salesforce/apex/LWCSendWhatsapp.getTemplates';
import sendTemplate from '@salesforce/apex/LWCSendWhatsapp.sendTemplate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import {reduceErrors} from 'c/utils';

export default class LWCSendWhatsapp extends LightningElement {
    templates = [];
    loading = false;
    @api recordId;

    renderedCallback() {
        if (!this.init) {
            this.init = true;
            getTemplates().then(t => this.setupTemplates(t)).catch(e => this.error(e));
        }
    }

    error(e) {
        console.error(e);

        const event = new ShowToastEvent({
            title: 'Error',
            variant: 'error',
            message: reduceErrors(e).join('\n'),
        });

        this.dispatchEvent(event)
    }

    setupTemplates(templates) {
        for (const t of templates) {
            t.selected = false;
        }

        this.templates = templates;
    }

    select(e) {
        if (e.target.checked) {
            for (const t of this.template.querySelectorAll('lightning-input')) {
                if (t !== e.target) t.checked = false;
            }
        }

        this.template.querySelector('lightning-button').disabled = !e.target.checked;
    }

    get selected() {
        const input = Array.from(this.template.querySelectorAll('lightning-input')).find(i => i.checked);
        return input ? this.templates.find(t => t.Id == input.dataset.id) : null;
    }

    send() {
        this.loading = true;

        sendTemplate({contactId: this.recordId, template: this.selected.DeveloperName}).then(_ => this.close()).catch(e => this.error(e)).finally(r => this.loading = false);
    }

    close() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}