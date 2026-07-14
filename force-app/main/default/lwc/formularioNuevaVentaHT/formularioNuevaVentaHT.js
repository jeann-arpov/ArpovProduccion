import { LightningElement, track } from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchProductores from '@salesforce/apex/CrearVentaController.searchProductores';
import getProductsData from '@salesforce/apex/CrearVentaController.getProductsData';
import getSemilleroData from '@salesforce/apex/CrearVentaController.getSemilleroData';
import getCultivos from '@salesforce/apex/UserControllerComunidad.getCultivos';
import {CompraVentaMixin} from 'c/utilsHT';
import getData from '@salesforce/apex/CrearVentaController.getData';
import finalizarVenta from '@salesforce/apex/CrearVentaController.finalizarVenta';
import anular from '@salesforce/apex/CrearVentaController.anular';
/*import crearCVS from '@salesforce/apex/CrearVentaController.crearCVS';
import generarFE from '@salesforce/apex/CrearVentaController.generarFE';
import generarPDF from '@salesforce/apex/CrearVentaController.generarPDF';*/
import { NavigationMixin } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import icons from 'c/icons';

export default class FormularioNuevaVentaHT extends CompraVentaMixin(LightningElement)  {
    icons = icons.compraVenta;
    @track step = 1;

    @track selectedCultivo = '';
    @track selectedProductor = '';
    @track selectedMarca = '';
    @track razonSocial = '';
    @track searchTerm = '';
    @track filteredProductores = [];
    searchTimeout;
    @track showResumen = false;
    @track detalleVenta = null;

    @track id_Obtentor__c= '';
    @track obtentorByMarca = {};
    @track idObtentorSeleccionado = '';


    
    marcas = ['BIOCERES', 'BIOGENESIS', 'BIODEN'];

    @track cultivos = [];

    iconMap = {
        'SOJA': '🌱',
        'TRIGO': '🌾',
        'CEBADA': '🌿',
        'Maíz': '🌽', // podés agregar más si es necesario
    };

    get step1Class() {
        return this.step > 1 ? 'step completed' : (this.step === 1 ? 'step active' : 'step');
    }

    get step2Class() {
        return this.step > 2 ? 'step completed' : (this.step === 2 ? 'step active' : 'step');
    }

    get step3Class() {
        return this.step === 3 ? 'step active' : 'step';
    }

    get isStep1Active() {
        return this.step === 1;
    }

    get isStep2Active() {
        return this.step === 2;
    }

    get isStep3Active() {
        return this.step === 3;
    }

    get decoratedCultivos() {
        return this.cultivos.map(c => ({
            ...c,
            cssClass: 'item' + (this.selectedCultivo === c.nombre ? ' selected' : '')
        }));
    }

    get decoratedCultivos() {
        return this.cultivos.map(c => ({
            ...c,
            cssClass: 'item' + (this.selectedCultivo === c.nombre ? ' selected' : '')
        }));
    }

    get hasProductores() {
        return this.filteredProductores && this.filteredProductores.length > 0;
    }

    get marcasOptions() {
        return this.marcas || [];
    }

    connectedCallback() {
        getCultivos()
        .then(result => {
            this.cultivos = result.map(c => ({
                nombre: c.label,
                id: c.value,
                icono: this.iconMap[c.label] || '🌾' 
            }));
        })
        .catch(error => {
            console.error('Error al obtener cultivos:', error);
        });
        
        this.handleDocumentClick = () => {
            if (this.isStep2Active) {
                const inputEl = this.template.querySelector('[data-id="productorSearch"]');
                if (inputEl) {
                    inputEl.focus();
                }
            }
        };
        document.addEventListener('click', this.handleDocumentClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleDocumentClick);
    }

    handleProductorInput(event) {
        this.searchTerm = event.target.value;
        console.log('Search term:', this.searchTerm);
        clearTimeout(this.searchTimeout);

        this.searchTimeout = setTimeout(() => {
            if (this.searchTerm.length < 2) {
                this.filteredProductores = [];
                return;
            }

            searchProductores({ searchTerm: this.searchTerm, selectedIds: [] })
                .then(result => {
                    this.filteredProductores = result.map(p => ({
                        id: p.id,
                        title: p.title,
                        record: p.record
                    }));
                    console.log('🔍 Resultados:', this.filteredProductores);
                })
                .catch(error => {
                    console.error('❌ Error al buscar productores:', error);
                    this.filteredProductores = [];
                });
        }, 300);
    }

    handleProductorSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selected = this.filteredProductores.find(p => p.id === selectedId);
        if (!selected) return;

        this.selectedProductor = selected.id;
        this.razonSocial = selected.record.Name;
        this.searchTerm = selected.title;
        this.filteredProductores = [];
        this.step = 3;
        console.log('Productor select:', JSON.stringify(selected));
        console.log('selectedCultivo select:', JSON.stringify(this.selectedCultivo));
        getProductsData({
            cultivoId: this.selectedCultivo,
            productorId: this.selectedProductor
        }).then(result => {
            console.log('Productor data:', JSON.stringify(result));
            
            const marcasSet = new Set();
            this.obtentorByMarca = {}; // Limpiar el mapa previo

            result.forEach(item => {
                const nombreObtentor = item?.Product2?.Variedad2__r?.Obtentor_Comercializa__r?.Nombre_Obtentor__c;
                const id_Obtentor__c = item?.Product2?.Variedad2__r?.Obtentor_Comercializa__r?.Id_Obtentor__c;

                if (nombreObtentor && id_Obtentor__c) {
                    marcasSet.add(nombreObtentor);
                    this.obtentorByMarca[nombreObtentor] = id_Obtentor__c;
                }
            });

            this.marcas = Array.from(marcasSet).map(nombre => ({
                label: nombre,
                value: nombre
            }));
        }).catch(error => {
            console.error('❌ Error al obtener marcas:', error);
        });
    }

    handleSelectMarca(event) {
        if (this.step !== 3) return;
        this.selectedMarca = event.detail.value;
        this.idObtentorSeleccionado = this.obtentorByMarca[this.selectedMarca] || '';

        console.log('Marca seleccionada:', this.selectedMarca);
        console.log('ID del obtentor:', this.idObtentorSeleccionado);
    }

    handleSelectCultivo(event) {
        if (this.step !== 1) return;
        this.selectedCultivo = event.currentTarget.dataset.id;
        this.selectedCultivoName = event.currentTarget.dataset.nombre;
        this.step = 2;
    }

    goToStep1() {
        this.step = 1;
        this.selectedProductor = '';
        this.razonSocial = '';
        this.selectedMarca = '';
        this.searchTerm = '';
        this.filteredProductores = [];
    }

    goToStep2() {
        if (this.step >= 2) {
            this.step = 2;
            this.selectedMarca = '';
        }
    }

    goToStep3() {
        if (this.step >= 3) {
            this.step = 3;
        }
    }

    handleStepClick(event) {
        const stepClicked = parseInt(event.currentTarget.dataset.step, 10);
        if (stepClicked === 1) {
            this.goToStep1();
        } else if (stepClicked === 2) {
            this.goToStep2();
        } else if (stepClicked === 3) {
            this.goToStep3();
        }
    }

    handleContinue() {
        if (!this.selectedMarca) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Falta seleccionar la marca',
                    message: 'Por favor seleccioná una marca antes de continuar.',
                    variant: 'warning',
                    mode: 'dismissable'
                })
            );
            return;
        }

        const detalleVenta = {
            cultivo: this.selectedCultivo,
            productor: this.selectedProductor,
            marca: this.selectedMarca,
            razonSocial: this.razonSocial,
            idobtentor: this.idObtentorSeleccionado
        };

        this.detalleVenta = {
            cultivo: this.selectedCultivo,
            cultivoName: this.selectedCultivoName,
            productor: this.razonSocial,
            cuit: this.searchTerm, // CUIT como texto visible
            idobtentor: this.idObtentorSeleccionado

        };
        console.log('detalleVenta', JSON.stringify(this.semilleroData));
        this.showResumen = true;
    }

    productor;
    
    getData(isFirstLoad) {
        console.log('getData', JSON.stringify(getData({ventaId: this.recordId, isFirstLoad})));
        return getData({ventaId: this.recordId, isFirstLoad});
     }
 
     setData(data) {
         this.setDataAndItems(data, data.record ? data.record.Lineas_de_Venta_HT__r : null);
         this.productor = data.record ? data.record.Cuenta_Productor__r : null;
     }
 
     get pageRecordId() {
         if (window.location.href.includes('venta-ht/') && !window.location.href.includes('venta-ht/Venta_HT__c/')) return window.location.href.split('venta-ht/')[1].split('/')[0];
         return new URL(window.location.href).searchParams.get("recordId");
     }

     get community() {
        return 'Venta';
    }

    get isPortalObtentor(){
        return basePath.includes('Obtentor');
    }

    addRow(event) {
        const rows = Array.from(this.template.querySelectorAll('c-crear-linea-venta'));
        if (rows.length && this.productor == null && !this.data.record) return this.onError('Debe seleccionar un productor');
        this.addRowInternal(rows);
    }

    saveRow(event) {
        if (this.productor == null && !this.data.record) return this.onError('Debe seleccionar un productor');
        event.target.save(this.recordId, this.cultivo, this.productor.Id);
    }

    productorSelected(event) {
        const selection = event.target.getSelection();
        this.productor = selection.length ? selection[0].record : null;
        this.getProductos();

    }

    get hasOperadorCobranza() {
        return this.productor && this.productor.Operador_de_Cobranza__r != null;
    }

    async finalizar(event) {
        if (this.isChildrenLoading) return this.onError('Espere a que se termine de guardar la línea');
        await this.requestWrap(async () => {
            const data = await finalizarVenta({ventaId: this.recordId, checkDuplicates: this.recordId != this.lastDuplicateCheckId});
            if (data.duplicate) return this.notifyDuplicate();
            this.setData(data);
            if (this.puedeFacturar) await this.facturar();
            this.currentModal = data.pendiente ? "pendiente" : "finalizada";
        });
    }

    notifyDuplicate() {
        this.currentModal = "duplicate-venta";
        this.lastDuplicateCheckId = this.recordId;
    }

    async anular(event) {
        await this.requestWrap(async () => {
            const data = await anular({ventaId: this.recordId});
            this.setData(data);
            this.currentModal = null;
            this.redirectPendientesFacturacion();
        });
    }

    async search(event) {
        const lookup = event.target;
        await searchProductores(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }
    /*
    crearCVS() {
        return crearCVS({ventaId: this.recordId});
    }

    generarFE(cvId) {
        return generarFE({ventaId: this.recordId, cvId});
    }

    generarPDF(cvId) {
        return generarPDF({ventaId: this.recordId, cvId});
    }*/

    getSemilleroData() {
        console.log('Semillero data:', JSON.stringify(this.semillero));
        console.log('Semillero data:', JSON.stringify(getSemilleroData({obtentorId: this.semillero, productorId: this.productor.Id})));
        return getSemilleroData({obtentorId: this.semillero, productorId: this.productor.Id});
    }

    get productorMissing() {
        return this.productor == null;
    }

    async getProductos(){
        await this.requestWrap(async () => {
            console.log('this.cultivo data:', JSON.stringify(this.cultivo));
            console.log('this.productor data:', JSON.stringify(this.productor));
            const products = await getProductsData({cultivoId: this.cultivo, productorId: this.productor.Id});
            this.updateVariedades(products);
            console.log('products data:', JSON.stringify(products));

        });
    }

}