import { LightningElement } from 'lwc';
import getAdhesion from '@salesforce/apex/CuentaGranaria.getAdhesion';
// import getToneladas from '@salesforce/apex/CuentaGranaria.getToneladas'; // COMENTADO - flujo por biotecnología
// import getCampanas from '@salesforce/apex/CuentaGranaria.getCampanas'; // COMENTADO - reemplazado por getCampanasConTotales
import getCampanasConTotales from '@salesforce/apex/CuentaGranaria.getCampanasConTotales';
import getToneladasByCampana from '@salesforce/apex/CuentaGranaria.getToneladasByCampana';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getDetalleBT from '@salesforce/apex/CuentaGranaria.getDetalleBT';
import IMAGENES from '@salesforce/resourceUrl/CuentaGranariaIcons';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import { doRequest, errorEvent, warningEvent } from 'c/utils';

export default class CuentaGranariaNew extends LightningElement {

    // ====== DATA PRINCIPAL ======
    cultivos;
    cultivo;
    cultivoSeleccionadoId; // para marcar seleccionado en step 1
    toneladas;
    totales;
    adhesion;
    biotecnologia;

    // ====== CAMPAÑAS ======
    campanas; // lista de campañas disponibles para el cultivo seleccionado
    campanaSeleccionada; // Id de la campaña seleccionada

    // ====== ICONOS CULTIVOS ======
    iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
    iconSojaHTUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
    iconTrigoHTUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;

    // ====== ICONOS ADICIONALES ======
    images = {
        cultivo: IMAGENES + '/cultivo.svg',
        tecnologia: IMAGENES + '/tecnologia.png',
        pph: IMAGENES + '/PPH2.png'
    }

    /* COMENTADO - se restauró tecnologías como paso 2 */
    // ====== TECNOLOGÍAS ======
    tecnologias = {
        SOJA: [
            { label: 'Enlist / Conkesta', value: 'Enlist E3/Conkesta E3' },
            { label: 'Aporte Genético', value: 'RR1/RR2 - BT/Convencional' }
        ],
        TRIGO: [
            { label: 'Aporte Genético', value: 'RR1/RR2 - BT/Convencional' }
        ],
        CEBADA: [
            { label: 'Convencional', value: 'RR1/RR2 - BT/Convencional' }
        ]
    }

    initialized;
    loading = false;

    // ====== STEPS ======
    step = 1;

    get step1Class() {
        return 'step' + (this.step === 1 ? ' active' : this.step > 1 ? ' completed' : '');
    }
    get step2Class() {
        return 'step' + (this.step === 2 ? ' active' : this.step > 2 ? ' completed' : '');
    }
    get step3Class() {
        return 'step' + (this.step === 3 ? ' active' : '');
    }

    get isStep1Active() { return this.step === 1; }
    get isStep2Active() { return this.step === 2; }
    get isStep3Active() { return this.step === 3; }

    handleStepClick(event) {
        const clickedStep = Number(event.currentTarget.dataset.step);
        if (clickedStep <= this.step) {
            this.step = clickedStep;
        }
    }

    // ====== INIT ======
    get paramCultivo() {
        return new URL(window.location.href).searchParams.get("cultivoId");
    }

    init() {
        this.initialized = true;

        doRequest.call(this, async _ => {
            const data = await getLoadData();
            this.cultivos = data.cultivos;
            if (this.paramCultivo) {
                this.cultivo = this.paramCultivo;
                this.verificarAdhesion();
            }
        });
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
        if (this._scrollToResumen) {
            const el = this.template.querySelector('.resumen-toneladas');
            if (el) {
                this._scrollToResumen = false;
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
    }

    // ====== CULTIVOS CON ICONOS ======
    get decoratedCultivos() {
        return (this.cultivos || []).map(c => {
            const nombre = c.Name;
            const id = c.Id;
            return {
                ...c,
                nombre,
                id,
                icono: this.getIcon(nombre),
                cssClass: 'item' + (this.cultivoSeleccionadoId === id ? ' selected' : '')
            };
        });
    }

    getIcon(nombre) {
        switch ((nombre || '').toLowerCase()) {
            case 'soja':
                return this.iconSojaHTUrl;
            case 'trigo':
                return this.iconTrigoHTUrl;
            case 'cebada':
                return this.iconCebadaUrl;
            default:
                return '';
        }
    }

    handleSelectCultivo(event) {
        const cultivoId = event.currentTarget.dataset.id;
        const cultivoName = event.currentTarget.dataset.nombre;
        this.cultivo = cultivoId;
        this.cultivoSeleccionadoId = cultivoId;
        this.reset();
        this.verificarAdhesion();
        this.step = 2;

        console.log('Cultivo seleccionado:', cultivoName, cultivoId);
    }

    // ====== ADHESIÓN ======
    verificarAdhesion() {
        doRequest.call(this, async _ => {
            this.adhesion = await getAdhesion({ cultivoId: this.cultivo });
            console.log('Adhesiones obtenidas:', JSON.stringify(this.adhesion));
            if (this.adhesion && Array.isArray(this.adhesion)) {
                const campanas = this.adhesion.map(a => a.Parametro_PPH__r?.Campana__c).filter(c => c);
                console.log('Campañas con adhesión:', campanas);
            }
        });
    }

    // ====== CAMPAÑAS ======
    cargarCampanas(cultivoId) {
        doRequest.call(this, async _ => {
            const result = await getCampanasConTotales({ cultivoId, tecnologias: this.biotecnologia });
            console.log('Campañas con totales:', JSON.stringify(result));
            this.campanas = result;
        });
    }

    // Genera el nombre corto de campaña, ej: SOJA '2025' -> '24/25', otros '2025' -> '2025'
    getCampanaPeriod(ano) {
        const year = parseInt(ano, 10);
        if (isNaN(year)) return ano;
        if (this.cultivoName === 'SOJA') {
            const next = String(year + 1).slice(-2);
            const curr = String(year).slice(-2);
            return `${curr}/${next}`;
        }
        return String(year);
    }

    // Devuelve el nombre del cultivo seleccionado
    get cultivoName() {
        if (!this.cultivos || !this.cultivo) return '';
        const c = this.cultivos.find(c => c.Id === this.cultivo);
        return c ? c.Name.toUpperCase() : '';
    }


    get decoratedCampanas() {
        if (!this.campanas) return [];
        const sorted = this.campanas.slice().sort((a, b) => parseInt(a.ano, 10) - parseInt(b.ano, 10));
        
        // Obtener set de campañas con adhesión
        const campanasConAdhesion = new Set();
        if (this.adhesion && Array.isArray(this.adhesion)) {
            this.adhesion.forEach(plan => {
                if (plan.Parametro_PPH__r?.Campana__c) {
                    campanasConAdhesion.add(plan.Parametro_PPH__r.Campana__c);
                }
            });
        }
        
        console.log('Campañas disponibles:', sorted.map(c => ({ id: c.id, name: c.name })));
        console.log('Campañas con adhesión:', Array.from(campanasConAdhesion));
        
        return sorted.map((c, idx) => {
            let isLast = (idx === sorted.length - 1);
            const hasAdhesion = campanasConAdhesion.has(c.id) || c.pphAdherida === true;
            if (hasAdhesion) {
                console.log('✓ Campaña ' + c.name + ' (' + c.id + ') tiene adhesión');
            }
            const showPPH =  hasAdhesion && this.adhesion && this.adhesion.length > 0;
            // Si es última campaña y tiene PPH, deshabilitar

            const isDisabled = isLast && showPPH;
            console.log('Campaña ' + c.name + ' (' + c.id + '): isLast=' + isLast + ', hasAdhesion=' + hasAdhesion + ', showPPH=' + showPPH );
            isLast = isLast && !hasAdhesion; // Si tiene adhesión, no considerarla última para selección
            return {
                ...c,
                period: this.getCampanaPeriod(c.ano),
                displayName: this.cultivoName,
                cssClass: 'campana-item' + (this.campanaSeleccionada === c.id ? ' selected' : '') + (isLast ? ' campana-activa' : ' campana-disabled') + (isDisabled ? ' campana-disabled' : ''),
                isLast,
                showPPH,
                hideToneladas: showPPH,
                hasAdhesion,
                isDisabled,
                adhesionVencimiento: hasAdhesion && this.adhesion?.[0] ? this.adhesion[0].Parametro_PPH__r?.Fecha_Vencimiento_PPH__c : null,
                // Nuevos campos para mostrar saldo y valor original
                saldoCuentaGranaria: c.saldoCuentaGranaria || 0,
                totalToneladasOriginal: c.totalToneladas || 0
            };
        });
    }

    handleSelectCampana(event) {
        // Solo permitir selección si es la última campaña Y no tiene adhesión
        const index = event.currentTarget.getAttribute('data-index');
        const camp = this.decoratedCampanas[index];
        
        // Validar: debe ser última campaña
        if (index != this.decoratedCampanas.length - 1) {
            return;
        }
        
        // Validar: NO debe tener adhesión/PPH
        if (camp.showPPH) {
            console.log('✗ No se puede seleccionar - campaña con PPH adhesión');
            return;
        }
        
        const campanaId = event.currentTarget.dataset.id;
        this.campanaSeleccionada = campanaId;
        this._scrollToResumen = true;
        this.getData();
        console.log('Campaña seleccionada:', campanaId);
    }

    /* COMENTADO - selector tipo combobox
    get campanaOptions() {
        return (this.campanas || []).map(c => ({
            label: c.Name + (c.Estado__c === 'Activa' ? ' (Actual)' : ''),
            value: c.Id
        }));
    }

    selectCampana(event) {
        this.campanaSeleccionada = event.detail.value;
        this.getData();
    }
    */

    // ====== TECNOLOGÍA ======
    selectTech(event) {
        this.biotecnologia = event.detail.value;
        console.log('Biotecnología seleccionada:', this.biotecnologia);
        this.cargarCampanas(this.cultivo);
        this.step = 3;
    }

    /* COMENTADO - selectTech original que llamaba getData directamente
    selectTech(event) {
        this.biotecnologia = event.detail.value;
        this.getData();
    }
    */

    // ====== TONELADAS Y TOTALES ======
    getData() {
        doRequest.call(this, async _ => {
            const results = await getToneladasByCampana({ cultivoId: this.cultivo, campanaId: this.campanaSeleccionada, tecnologias: this.biotecnologia });
            console.log(results);

            this.toneladas = results;
            const totales = {};
            console.log('toneladas',JSON.stringify(results));
            for (const tn of results) {
                let key = tn.Origen__c;
                if (key == 'Semilla Original' || key == 'Semilla Pre Básica') key = 'Compra SF';
                if (key == 'Consumo') key = 'Compra HT';

                if (!totales[key] && !['Regalía Enlist', 'BolsaTech', 'Balance Anual', 'Transferencia'].includes(key)) {
                    totales[key] = { label: this.origenLabels[key], value: 0, origen: key };
                }

                if (totales[key]) totales[key].value += tn.Cantidad_con_Signo__c;
            }

            for (const origen in this.origenLabels) {
                if (!['BolsaTech', 'Balance Anual', 'Transferencia'].includes(origen) && !totales.hasOwnProperty(origen)) {
                    totales[origen] = { label: this.origenLabels[origen], value: 0 };
                }
            }
            console.log('totales',JSON.stringify(totales));

            this.totales = Object.values(totales);
        });
    }

    descargarDetalle(event) {
        const origen = event.currentTarget.dataset.name;
        const ids = this.toneladas.filter(tn => tn.Origen__c == origen).map(tn => tn.Id);

        if (ids.length) {
            doRequest.call(this, async _ => {
                const result = await getDetalleBT({ toneladasIds: ids });
                const downLink = document.createElement('a');
                downLink.href = 'data:text/csv;charset=utf-8,' + encodeURI(result);
                downLink.target = '_blank';
                downLink.download = `detalle_toneladas_${origen}.csv`.toLowerCase().replace(' ', '_');
                downLink.click();
            });
        } else {
            this.dispatchEvent(warningEvent(new Error('No hay registros de toneladas para descargar')));
        }
    }

    handleComprarHT(event) {
        // Redirigir a FormularioNuevaVentaHT preservando el prefijo del portal actual
        // Ej: /Productores/s/cuentagranarianew -> /Productores/s/FormularioNuevaVentaHT
        const portalBase = window.location.pathname.split('/s/')[0];
        window.location.href = portalBase + '/s/FormularioNuevaVentaHT';
    }

    // ====== UTILS ======
    reset() { 
        this.totales = null; 
        this.campanaSeleccionada = null;
        this.campanas = null;
        this.biotecnologia = null;
    }

    onError(e) { 
        this.dispatchEvent(errorEvent(e)); 
    }

    // ====== GETTERS TOTALES ======
    get cultivoOptions() {
        console.log('Cultivo options:', this.cultivos);
        return this.cultivos.map(c => ({ label: c.Name, value: c.Id }));
    }

    get origenLabels() {
        return {
            'Compra SF': 'Semilla Fiscalizada',
            'Cesión HT': 'Cesión',
            'Compra HT': 'Compra de Hectáreas Tecnológicas',
            // 'Consumo': 'Compra de Hectáreas Tecnológicas',
            'Ensayo': 'Ensayos',
            'Transferencia': 'Transferencia de campaña',
            'BolsaTech': 'Entregas Bolsatech',
            'Balance Anual': 'Saldo Campaña Anterior'
        };
    }

    // Muestra el selector de campaña cuando hay biotecnología seleccionada y sin adhesión
    get showCampanaSelector() { return this.cultivo && this.biotecnologia && this.campanas && this.campanas.length > 0; }

    get campanaSeleccionadaPeriod() {
        if (!this.campanas || !this.campanaSeleccionada) return '';
        const camp = this.campanas.find(c => c.id === this.campanaSeleccionada);
        return camp ? this.getCampanaPeriod(camp.ano) : '';
    }

    get showFilterTech() { return this.cultivo; }

    // HT Disponibles: datos de Compra HT de la campaña activa (última)
    get campanaActiva() {
        if (!this.campanas || this.campanas.length === 0) return null;
        const sorted = this.campanas.slice().sort((a, b) => parseInt(a.ano, 10) - parseInt(b.ano, 10));
        return sorted[sorted.length - 1];
    }

    get equivalenteToneladas() {
        const camp = this.campanaActiva;
        return camp ? (camp.totalCompraHT || 0) : 0;
    }

    get htDisponibles() {
        return Math.round(this.equivalenteToneladas / 3);
    }

    get htEquivalenteRowClass() {
        return 'ht-info-row' + (this.equivalenteToneladas === 0 ? ' ht-info-row--zero' : ' ht-info-row--zero');
    }

    get showHTInfo() {
        return this.showCampanaSelector;
    }

    get showInfoRegaliaEnlist(){
        return this.biotecnologia == 'Enlist E3/Conkesta E3';
    }

    get biotecnologias() {
        console.log('Tecnologías disponibles para cultivo', this.cultivoName, ':', this.cultivoOptions.find(c => c.value == this.cultivo).label);
        console.log('Cultivo seleccionado:', this.cultivo);


        return this.tecnologias[this.cultivoOptions.find(c => c.value == this.cultivo).label];
    }

    get biotecnologiaLabel() {
        if (!this.biotecnologia) return '';
        const opciones = this.biotecnologias || [];
        const opcion = opciones.find(t => t.value === this.biotecnologia);
        return opcion ? opcion.label : this.biotecnologia;
    }

    get fechaVencimientoPPH() {
        return this.adhesion?.[0]?.Parametro_PPH__r?.Fecha_Vencimiento_PPH__c;
    }

    get showAdhesionStandalone() {
        return this.adhesion && !this.showCampanaSelector;
    }

    get totalBolsatech() { return this.getTotal('BolsaTech'); }
    // get totalBalanceAnual() { return this.getTotal('Balance Anual'); } // COMENTADO - Saldo Campaña Anterior

    get totalTransferencia() { return this.getTotal('Transferencia'); }

    get showTotalTransferencia() {
        return this.totalTransferencia.value !== 0;
    }

    get totalRegaliaEnlistPagada() {
        const value = this.toneladas.filter(tn => tn.Origen__c == 'Regalía Enlist' && tn.Etapa__c == 'Cobrada')
            .reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return { label: 'Regalía Enlist pagada', value, origen: 'Regalía Enlist' };
    }

    get totalTodo() {
        return this.totales.reduce((total, t) => total += t.value, 0) +
            this.totalBolsatech.value + this.totalRegaliaEnlistPagada.value +
            this.totalTransferencia.value;
    }

    /* COMENTADO - Toneladas disponibles para entregar
    get totalDisponibles() {
        const total = this.toneladas.reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total > 0 ? total : 0;
    }
    */

    get totalEntregadas() {
        return this.toneladas.filter(tn =>
            tn.Origen__c == 'BolsaTech' &&
            this.toLocalDate(tn.Fecha_Inicio__c).toISOString() >= this.fechaEntregadas.toISOString()
        ).reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0) * -1;
    }

    /* COMENTADO - Toneladas a vencer
    get totalVencer() {
        let total = this.toneladas.filter(tn =>
            this.toLocalDate(tn.Fecha_Fin__c).toISOString() == this.fechaVencimiento.toISOString() &&
            (tn.Origen__c != 'Regalía Enlist' || tn.Etapa__c != 'Facturada')
        ).reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total > 0 ? total : 0;
    }
    */

    get totalToneladasRegularizar() {
        const total = this.toneladas.reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total < 0 ? total * -1 : 0;
    }

    get totalRegaliaEnlistPendientes() {
        return this.toneladas
            .filter(tn => tn.Origen__c == 'Regalía Enlist' && tn.Etapa__c == 'Facturada')
            .reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
    }

    // ====== FECHAS ======
    toLocalDate(fecha) {
        const formmatedDate = new Date(fecha);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        return formmatedDate;
    }

    get fechaEntregadas() {
        const cultivo = this.cultivos.find(c => c.Id == this.cultivo);
        const formmatedDate = new Date(cultivo.Fecha_Vencimiento_de_Tonelada__c);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        const date = new Date();
        if (date < formmatedDate) {
            formmatedDate.setFullYear(formmatedDate.getFullYear() - 1);
        }
        return formmatedDate;
    }

    get fechaEntregadasWithFormat() {
        return this.fechaEntregadas.toLocaleDateString('es-AR');
    }

    get fechaVencimiento() {
        const cultivo = this.cultivos.find(c => c.Id == this.cultivo);
        const formmatedDate = new Date(cultivo.Fecha_Vencimiento_de_Tonelada__c);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        const date = new Date();
        if (date > formmatedDate) {
            formmatedDate.setFullYear(formmatedDate.getFullYear() + 1);
        }
        return formmatedDate;
    }

    get fechaVencimientoToDisplay() {
        return this.fechaVencimiento.toLocaleDateString('es-AR');
    }

    getTotal(origen) {
        const value = this.toneladas.filter(tn => tn.Origen__c == origen)
            .reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return { label: this.origenLabels[origen], value, origen: origen };
    }
}