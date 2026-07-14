import { LightningElement, api, track } from 'lwc';

export default class RadioGroup extends LightningElement {

    @api label = '';
    @api value = '';
    @api name = 'CustomRadioGroup';
    @api options = [];
    @api disabled = false;
    @api orientation = 'vertical';
    @track _options = [];
    @track _value = '';
    connectedCallback(){
        this._value = this.value;
        this._options = this.options.map((opt, ind) => ({
            label: opt.label,
            value: opt.value,
            checked: this.value == opt.value,
            key: ind,
            inputClass: `radio-input-${ind}`
        }));
    }
    handleClick(event) {
        if (this.disabled) {
            return;
        }
        let key = event.currentTarget.dataset.key;
        if (!key && key !== 0) {
            return;
        }
        let input = this.template.querySelector(`.radio-input-${key}`);
        if (!input) {
            return;
        }

        //make the input checked
        input.checked = true;
        this._value = input.value;
        
        this.dispatchChange(input.value);
    }
    get radioClass(){
        return `slds-radio ${this.orientation == 'horizontal' ? 'horizontal' : ''}`;
    }

    @api setValue(value){
        this._options = this._options.map(o => ({...o, checked: o.value == value}));
    }

    dispatchChange(value){
        const change = new CustomEvent('change', {
            detail: {
                value: value
            }
        });
        this.dispatchEvent(change);
    }



}