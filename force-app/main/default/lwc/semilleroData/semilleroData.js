import { LightningElement, api } from 'lwc';
import icons from 'c/icons';

export default class SemilleroData extends LightningElement {
    @api semilleroData;
    @api semilleros;
    @api missingConfirmData;
    @api disabled = false;
    @api placeholder = "Seleccionar marca";

    icons = icons.compraVenta;

    semilleroSelected(event) {
        this.dispatchEvent(new CustomEvent('semilleroselected', {detail: event.target.value}));
    }

    openCondicionesComerciales(event) {
        this.dispatchEvent(new CustomEvent('opencondicionescomerciales'));
    }

    redirectMisLicencias() {
        this.dispatchEvent(new CustomEvent('redirectmislicencias'));
    }

    confirm(event) {
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    get icono() {
        return icons.semilleros[this.semilleroData.semillero.Id_Obtentor__c];
    }
}