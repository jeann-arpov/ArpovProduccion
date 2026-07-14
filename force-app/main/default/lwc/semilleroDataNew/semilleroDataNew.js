import { LightningElement, api } from 'lwc';
import icons from 'c/icons';

export default class SemilleroDataNew extends LightningElement {
    _semilleroData;

    @api semilleros;
    @api missingConfirmData;
    @api disabled = false;
    @api placeholder = "Seleccionar marca";

    icons = icons.compraVenta;

    // Setter que se dispara cada vez que el padre asigna semilleroData
    @api
    set semilleroData(value) {
        this._semilleroData = value;
        console.log(' semilleroData seteado', JSON.stringify(value));

        // Cuando ya llega el valor, intentamos notificar
        this.notifyIcon();
    }
    get semilleroData() {
        return this._semilleroData;
    }

    semilleroSelected(event) {
        const value = event.target.value;

        this.dispatchEvent(new CustomEvent('semilleroselectedejecuto', { 
            detail: value, 
            bubbles: true, 
            composed: true 
        }));

        this.dispatchEvent(new CustomEvent('semilleroselected', { detail: event.target.value }));

        this.dispatchEvent(new CustomEvent('confirm'));
        console.log('event.target.value en semillero', JSON.stringify(value));
    }

    openCondicionesComerciales() {
        this.dispatchEvent(new CustomEvent('opencondicionescomerciales'));
    }

    redirectMisLicencias() {
        this.dispatchEvent(new CustomEvent('redirectmislicencias'));
    }

    get icono() {
        return this._semilleroData?.semillero?.Id_Obtentor__c
            ? icons.semilleros[this._semilleroData.semillero.Id_Obtentor__c]
            : null;
    }

    notifyIcon() {
        const idObtentor = this._semilleroData?.semillero?.Id_Obtentor__c;
        if (idObtentor && icons.semilleros[idObtentor]) {
            console.log(' Icono encontrado:', icons.semilleros[idObtentor]), idObtentor;
            this.dispatchEvent(new CustomEvent('semilleroiconready', {
                detail: icons.semilleros[idObtentor],
                bubbles: true,
                composed: true
            }));
        } else {
            console.warn(' Icono no disponible todavía');
            // Igual notifico null para que el padre pueda reaccionar
            this.dispatchEvent(new CustomEvent('semilleroiconready', {
                detail: null,
                bubbles: true,
                composed: true
            }));
        }
    }
}