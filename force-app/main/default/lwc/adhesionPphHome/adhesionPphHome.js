import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/AdhesionPPHHome.getLoadData';
import rectificarAdhesion from '@salesforce/apex/AdhesionPPH.rectificarAdhesion';
import rectificarAdhesion2 from '@salesforce/apex/AdhesionPPH.rectificarAdhesion2';

import { errorEvent } from 'c/utils';
import SVG_ICONS from '@salesforce/resourceUrl/iconos_SE';

export default class AdhesionPphHome extends NavigationMixin(LightningElement) {

    data;
    parametros = [];

    icons = {
        'file': SVG_ICONS + '/iconos/venta/Icon-feather-file.svg#Icon_feather-file'
    };

    initialized = false;
    loaded = false;

    rectificacionTooltip = 'Tenés una rectificación de PPH sin finalizar. Ingresá, completá tu plan de siembra y aceptá los términos y condiciones.';

    async init(){
        this.initialized = true;

        try {
            const data = await getLoadData();
            console.log(data);
            this.data = data;
            this.data.forEach(w => {
                w.parametros.forEach(wParam => {
                    wParam.actionName = this.getActionName(wParam);
                    wParam.rangoAdhesion = `Adhesión de ${this.getLocaleDateString(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c)} a ${this.getLocaleDateString(wParam.parametro.Fecha_Fin_Adhesion_PPH__c)}`;
                    wParam.estadoClass = 'estado ' + this.getEstadoClass(wParam.planSiembra?.Estado__c);
                    wParam.estadoLabel = wParam.planSiembra
                        ? this.getEstadoLabel(wParam.planSiembra.Estado__c)
                        : 'Sin Adherir';
                    wParam.showRectificacionInfo = wParam.planSiembra?.Estado__c === 'Rectificado';
                    wParam.estadoWrapperClass = wParam.showRectificacionInfo ? 'estado-tooltip' : 'estado-wrapper';
                    wParam.disableAction = this.getDisableAction(wParam);
                    this.parametros.push(wParam);
                });
            })
            this.loaded = true;
        } catch (error) {
            this.onError(error);
        }
    }

    getDisableAction(wParam){
        let disable = false;
        if(wParam.actionName == 'Adherir' || wParam.actionName == 'Continuar'){
            const hoy = new Date();
            if(!wParam.planSiembra || wParam.planSiembra.Estado__c == 'Sin adherir' || wParam.planSiembra.Estado__c == 'En Preparación'){
                if(new Date(wParam.parametro.Fecha_Inicio_Adhesion_PPH__c) > hoy){
                    disable = true;
                    wParam.disabledCause = 'El período de adhesión no ha comenzado';
                }
                if(new Date(wParam.parametro.Fecha_Fin_Adhesion_PPH__c) < hoy){
                    disable = true;
                    wParam.disabledCause = 'El período de adhesión ya ha finalizado';
                }
            }
        }
        return disable;
    }

    getLocaleDateString(date){
        const newDate = new Date(date);
        newDate.setHours(newDate.getHours() + 3);
        return newDate.toLocaleDateString();
    }

    async doAction(event){
        const cultivoId = event.target.dataset.cultivo;
        const paramId = event.target.dataset.param;
        
        const wParam = this.data.find(w => w.cultivo.Id == cultivoId).parametros.find(wp => wp.parametro.Id == paramId);
        console.log(wParam);

        if(wParam.actionName == 'Adherir' || wParam.actionName == 'Continuar' || wParam.actionName == 'Ver'){
            this.redirectToParam(paramId);
        }
    }

    getActionName(wParam){
        let actionName = '';
        const estado = wParam.planSiembra?.Estado__c;
        if(estado == null || estado == 'Sin adherir'){
            actionName = 'Adherir';
        }
        if(estado == 'Adherido' || estado == 'Rechazado' || estado == 'Vencido'){
            actionName = 'Ver';
        }
        if(estado == 'En Preparación' || estado == 'Rectificado'){
            actionName = 'Continuar';
        }

        return actionName;
    }

    getEstadoLabel(estado) {
        if (estado === 'Rectificado') {
            return 'En rectificación';
        }
        return estado;
    }

    getEstadoClass(estado){
        let estadoClass = '';
        if(estado == null || estado == 'Sin adherir'){
            estadoClass = 'no-adherido';
        }
        if(estado == 'Adherido'){
            estadoClass = 'adherido';
        }
        if(estado == 'Rectificado'){
            estadoClass = 'rectificado';
        }
        if(estado == 'Rechazado'){
            estadoClass = 'rechazado';
        }
        if(estado == 'En Preparación'){
            estadoClass = 'preparacion';
        }
        if(estado == 'Vencido'){
            estadoClass = 'vencido';
        }
        return estadoClass;
    }

    redirectToParam(paramId){
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'adhesion-pph',
            }
        }).then(url => {
            window.open(`${url}?recordId=${paramId}`, '_self');
        });
    }

    showTerminos(event){
        const id = event.target.dataset.id;
        const documentId = this.parametros.find(w => w.parametro.Id == id).contentDocumentId;
        this.template.querySelector('c-pdf-reader').show({
            documentId: documentId,
            title:'Términos y Condiciones'
        });
    }

    renderedCallback(){
        if(!this.initialized){
            this.init();
        }
    }

    onError(e){
        this.dispatchEvent(errorEvent(e));
    }

}