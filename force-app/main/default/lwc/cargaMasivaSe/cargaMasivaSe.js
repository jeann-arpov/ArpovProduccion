import { LightningElement } from 'lwc';

export default class CargaMasivaSe extends LightningElement {
    seccion = 'casos';

    verCasos() {
        this.seccion = 'casos';
    }

    verGestiones() {
        this.seccion = 'gestiones';
    }

    get esCasos() {
        return this.seccion === 'casos';
    }

    get esGestiones() {
        return this.seccion === 'gestiones';
    }

    get claseCasos() {
        return this.esCasos ? 'tab activo' : 'tab';
    }

    get claseGestiones() {
        return this.esGestiones ? 'tab activo' : 'tab';
    }

    get panelCasos() {
        return this.esCasos ? 'panel' : 'panel oculto';
    }

    get panelGestiones() {
        return this.esGestiones ? 'panel' : 'panel oculto';
    }
}
