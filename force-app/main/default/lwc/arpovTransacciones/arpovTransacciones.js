import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation'; 
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex'; 
import USER_ID from '@salesforce/user/Id';

// Campos del usuario
import CUIT_FIELD from '@salesforce/schema/User.Contact.Account.N_CUIT__c';
import ACCOUNT_ID_FIELD from '@salesforce/schema/User.Contact.AccountId';

// Controladores Apex
import getTransaccionesByCuenta from '@salesforce/apex/ArpovTransaccionesController.getTransaccionesByCuenta';
import getObtentores from '@salesforce/apex/ArpovTransaccionesController.getObtentores';
import getCultivosPorObtentor from '@salesforce/apex/ArpovTransaccionesController.getCultivosPorObtentor'; 
import getCampanasPorCultivo from '@salesforce/apex/ArpovTransaccionesController.getCampanasPorCultivo'; 
import crearTransaccionDUP from '@salesforce/apex/ArpovTransaccionesController.crearTransaccionDUP';
import getRelatedFiles from '@salesforce/apex/ArpovTransaccionesController.getRelatedFiles'; 
import getProductosPorObtentor from '@salesforce/apex/ArpovTransaccionesController.getProductosPorObtentor';
import guardarVariedadesDeclaradas from '@salesforce/apex/ArpovTransaccionesController.guardarVariedadesDeclaradas';

export default class ArpovTransacciones extends NavigationMixin(LightningElement) { 
    @track transactionsData = []; 
    @track filteredTransactions = [];

    // Estado de la UI y Modales
    @track isLoading = false;
    @track showCreateModal = false; 
    @track showSuccessModal = false;
    @track showDetailModal = false; 
    @track showVariedadesModal = false; // Modal dinámico de ítems

    // Estado para controlar qué transacción se está guardando individualmente
    @track savingTxIds = [];

    // Filtros de búsqueda
    filterStatus = '';
    filterDesde = '';
    filterHasta = '';

    // Datos del Formulario de Creación
    cuitProductor = '';
    accountId = undefined; 
    selectedObtentor = '';
    selectedCultivo = '';
    selectedCampana = '';
    comentarios = '';
    
    // Referencia temporal para la transacción recién creada
    newlyCreatedTx = null;

    // Datos de la Transacción Seleccionada para Detalle/Variedades
    @track selectedTx = {}; 
    @track currentRelatedFiles = []; 
    @track cultivoId;

    // Gestión de Paginación
    @track currentPage = 1;
    pageSize = 5; 

    // Gestión de Archivos Adjuntos (Formulario de Creación)
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];
    @track attachedFileId = '';
    @track attachedFileName = '';
    
    userIdContainer = USER_ID; 

    // Opciones Dinámicas
    @track obtentorOptions = [];
    @track cultivoOptions = []; 
    @track campanaOptions = []; 
    @track productoOptions = []; // Opciones filtradas por obtentor
    
    // Lista reactiva para los bloques dinámicos de variedades
    @track variedadesFormList = [];
    variedadIndexCounter = 0;

    // Guardamos la respuesta del wire de transacciones para poder refrescarla
    wiredTransaccionesResult;

    @wire(getRecord, { recordId: USER_ID, fields: [CUIT_FIELD, ACCOUNT_ID_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.cuitProductor = getFieldValue(data, CUIT_FIELD) || '20062988356';
            this.accountId = getFieldValue(data, ACCOUNT_ID_FIELD);
        } else if (error) {
            console.error('Error al cargar contexto de usuario:', error);
        }
    }

    @wire(getTransaccionesByCuenta, { idCuentaLogueada: '$accountId' })
    wiredTransacciones(result) {
        this.wiredTransaccionesResult = result;
        if (result.data) {
            this.transactionsData = result.data.map(tx => {
                const estadoNormalizado = tx.Estado__c ? tx.Estado__c.toLowerCase().trim() : '';
                const esCreada = estadoNormalizado === 'creada' || estadoNormalizado === 'creado';
                
                return {
                    ...tx,
                    formattedDate: new Date(tx.CreatedDate).toLocaleDateString('es-AR'),
                    cultivoName: tx.Cultivo__r ? tx.Cultivo__r.Name : '',
                    campanaName: tx.Campana__r ? tx.Campana__r.Name : '',
                    obtentorName: tx.Obtentor__r ? tx.Obtentor__r.Name : '',
                    statusClass: `badge-status badge-${estadoNormalizado.replace(' ', '-') || 'pendiente'}`,
                    isCreada: esCreada,              // Estado 'Creada' -> Muestra Declarar Variedades
                    esEstadoCreada: !esCreada,         // NO 'Creada' -> Muestra Generar PDF DUP
                    isSaving: this.savingTxIds.includes(tx.Id) // Estado reactivo de spinner individual
                };
            });
            this.applyFilters();
        }
    }

    @wire(getObtentores)
    wiredObtentores({ error, data }) {
        if (data) {
            this.obtentorOptions = data.map(opt => ({ label: opt.label, value: opt.value }));
        }
    }

    // Getters Reactivos
    get hasTransactions() { return this.filteredTransactions && this.filteredTransactions.length > 0; }
    get totalPages() { return Math.ceil(this.filteredTransactions.length / this.pageSize) || 1; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage >= this.totalPages; }
    get pagedTransactions() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredTransactions.slice(start, start + this.pageSize);
    }
    get hasAttachedFiles() { return this.attachedFileId !== ''; }
    get hasRelatedFiles() { return this.currentRelatedFiles && this.currentRelatedFiles.length > 0; }
    get isSubmitDisabled() {
        return !(this.selectedObtentor && this.selectedCultivo && this.selectedCampana);
    }

    // Getters para habilitar/deshabilitar Picklists dependientes de forma responsiva
    get isCultivoDisabled() {
        return !this.selectedObtentor;
    }

    get isCampanaDisabled() {
        return !this.selectedCultivo;
    }

    // Paginación y Filtros
    handlePreviousPage() { if (this.currentPage > 1) this.currentPage--; }
    handleNextPage() { if (this.currentPage < this.totalPages) this.currentPage++; }
    
    handleFilterStatusChange(event) { this.filterStatus = event.target.value; this.applyFilters(); }
    handleFilterDesdeChange(event) { this.filterDesde = event.target.value; this.applyFilters(); }
    handleFilterHastaChange(event) { this.filterHasta = event.target.value; this.applyFilters(); }

    applyFilters() {
        this.filteredTransactions = this.transactionsData.filter(tx => {
            const matchStatus = !this.filterStatus || tx.Estado__c === this.filterStatus;
            const txDate = new Date(tx.CreatedDate).setHours(0, 0, 0, 0);
            const matchDesde = !this.filterDesde || txDate >= new Date(this.filterDesde).setHours(0, 0, 0, 0);
            const matchHasta = !this.filterHasta || txDate <= new Date(this.filterHasta).setHours(0, 0, 0, 0);
            return matchStatus && matchDesde && matchHasta;
        });
        this.currentPage = 1; 
    }

    // Manejador del spinner por transacción
    setTxSavingState(txId, isSaving) {
        if (isSaving) {
            if (!this.savingTxIds.includes(txId)) {
                this.savingTxIds = [...this.savingTxIds, txId];
            }
        } else {
            this.savingTxIds = this.savingTxIds.filter(id => id !== txId);
        }

        this.transactionsData = this.transactionsData.map(tx => {
            if (tx.Id === txId) {
                return { ...tx, isSaving: isSaving };
            }
            return tx;
        });
        this.applyFilters();
    }

    // --- ACCIONES DEL MODAL DE CREACIÓN ---
    handleNewTransaction() { 
        this.clearForm();
        this.showCreateModal = true; 
    }
    
    handleCloseCreateModal() { 
        this.showCreateModal = false; 
        this.clearForm();
    }

    handleCancel() { 
        this.handleCloseCreateModal();
    }

    // Picklist Dependiente 1: Cambia Obtentor -> Busca Cultivos
    handleObtentorChange(event) { 
        this.selectedObtentor = event.target.value; 

        // Reseteamos dependientes
        this.selectedCultivo = '';
        this.selectedCampana = '';
        this.cultivoOptions = [];
        this.campanaOptions = [];

        if (this.selectedObtentor) {
            this.isLoading = true;
            getCultivosPorObtentor({ obtentorId: this.selectedObtentor })
                .then(result => {
                    this.cultivoOptions = result;
                })
                .catch(error => {
                    console.error('Error al obtener cultivos por obtentor:', error);
                    this.showToast('Error', 'No se pudieron recuperar los cultivos para este obtentor.', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    // Picklist Dependiente 2: Cambia Cultivo -> Busca Campañas
    handleCultivoChange(event) { 
        this.selectedCultivo = event.target.value; 
        this.cultivoId = this.selectedCultivo;

        // Reseteamos campaña dependiente
        this.selectedCampana = '';
        this.campanaOptions = [];

        if (this.selectedCultivo) {
            this.isLoading = true;
            getCampanasPorCultivo({ cultivoId: this.selectedCultivo })
                .then(result => {
                    this.campanaOptions = result;
                })
                .catch(error => {
                    console.error('Error al obtener campañas por cultivo:', error);
                    this.showToast('Error', 'No se pudieron recuperar las campañas para este cultivo.', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleCampanaChange(event) { this.selectedCampana = event.target.value; }
    handleComentariosChange(event) { this.comentarios = event.target.value; }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.attachedFileId = uploadedFiles[0].documentId;
            this.attachedFileName = uploadedFiles[0].name;
            this.showToast('Éxito', 'Documentación adjuntada correctamente.', 'success');
        }
    }

    handleRemoveFile() { this.attachedFileId = ''; this.attachedFileName = ''; }

    // --- MODAL DE DETALLE ---
    handleOpenDetail(event) {
        event.preventDefault();
        const txId = event.target.dataset.id;
        this.selectedTx = this.transactionsData.find(tx => tx.Id === txId);
        
        if (this.selectedTx) {
            this.isLoading = true;
            this.fetchRelatedFiles(txId);
        }
    }

    fetchRelatedFiles(txId) {
        getRelatedFiles({ transaccionId: txId })
            .then(result => {
                this.currentRelatedFiles = result;
                this.showDetailModal = true;
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error al cargar archivos vinculados: ', error);
                this.showToast('Error', 'No se pudieron recuperar los archivos vinculados.', 'error');
            });
    }

    handleCloseDetailModal() {
        this.showDetailModal = false;
        this.selectedTx = {};
        this.currentRelatedFiles = [];
    }

    handleDetailUploadFinished(event) {
        this.showToast('Éxito', 'Nuevo archivo adjuntado a la declaración.', 'success');
        this.fetchRelatedFiles(this.selectedTx.Id);
    }

    handleSubmit() {
        if (this.isSubmitDisabled) {
            this.showToast('Atención', 'Por favor, completa los campos requeridos', 'warning');
            return;
        }

        this.isLoading = true;

        crearTransaccionDUP({
            cuentaId: this.accountId,
            obtentorId: this.selectedObtentor,
            cultivoId: this.selectedCultivo,
            campanaId: this.selectedCampana,
            comentarios: this.comentarios,
            documentId: this.attachedFileId
        })
        .then((newTxId) => {
            // Guardamos el contexto de la transacción creada antes de limpiar los controles
            this.newlyCreatedTx = {
                Id: newTxId,
                Obtentor__c: this.selectedObtentor,
                Cultivo__c: this.selectedCultivo,
                Campana__c: this.selectedCampana
            };

            this.isLoading = false;
            this.showCreateModal = false; 
            this.showSuccessModal = true; 
            return refreshApex(this.wiredTransaccionesResult); 
        })
        .catch((error) => {
            this.isLoading = false;
            this.showToast('Error de Guardado', error?.body?.message || 'No se pudo crear la declaración.', 'error');
        });
    }

    handleCloseModal() {
        this.showSuccessModal = false;

        // Si venimos de crear una transacción, la abrimos directamente en el modal de variedades
        if (this.newlyCreatedTx) {
            const tempTx = { ...this.newlyCreatedTx };
            this.newlyCreatedTx = null;
            this.clearForm();
            
            // Invocamos directamente el flujo de variedades para la nueva transacción
            this.iniciarFlujoVariedades(tempTx);
        } else {
            this.clearForm();
        }
    }

    handleGenerarPdf(event) {
        const transaccionId = event.target.dataset.id; 
        const vfUrl = `/apex/dupPDF?transaccionId=${transaccionId}&portal=true`;

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__webPage',
            attributes: { url: vfUrl }
        }).then(generatedUrl => {
            window.open(generatedUrl, '_blank');
        }).catch(error => {
            console.error('Error al generar la URL de Visualforce:', error);
        });
    }

    /* ==========================================================================
       PROCESAMIENTO DINÁMICO DE DECLARAR VARIEDADES
       ========================================================================== */
    handleDeclararVariedades(event) {
        const txId = event.target.dataset.id;
        const tx = this.transactionsData.find(t => t.Id === txId);
        
        if (tx) {
            this.iniciarFlujoVariedades(tx);
        }
    }

    // Helper reutilizable para cargar productos y abrir el modal de variedades
    iniciarFlujoVariedades(transactionRecord) {
        this.selectedTx = transactionRecord;
        this.isLoading = true;
        
        getProductosPorObtentor({ 
            obtentorId: this.selectedTx.Obtentor__c, 
            cultivoId: this.selectedTx.Cultivo__c 
        })
        .then(result => {
            this.productoOptions = result;
            this.variedadIndexCounter = 1;
            this.variedadesFormList = [this.generarBloqueVacio(this.variedadIndexCounter)];
            this.showVariedadesModal = true;
        })
        .catch(error => {
            console.error('Error al cargar productos del obtentor:', error);
            this.showToast('Error', 'No se pudieron recuperar las variedades del obtentor.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    generarBloqueVacio(index) {
        return {
            key: index,
            numero: index,
            productoId: '',
            cantidad: '',
            densidad: ''
        };
    }

    handleVariedadFieldChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        this.variedadesFormList = this.variedadesFormList.map(item => {
            if (item.key === index) {
                return { ...item, [field]: value };
            }
            return item;
        });
    }

    validarBloquesCompletos() {
        return this.variedadesFormList.every(item => item.productoId && item.cantidad && item.densidad);
    }

    handleAgregarVariedadBloque() {
        if (!this.validarBloquesCompletos()) {
            this.showToast('Atención', 'Por favor complete todos los campos de la variedad actual antes de agregar otra.', 'warning');
            return;
        }
        
        this.variedadIndexCounter++;
        this.variedadesFormList = [...this.variedadesFormList, this.generarBloqueVacio(this.variedadIndexCounter)];
        this.recalcularNumeracionBloques();
    }

    handleBorrarVariedadBloque(event) {
        const indexToDelete = parseInt(event.target.dataset.index, 10);
        
        if (this.variedadesFormList.length === 1) {
            this.showToast('Atención', 'Debe declarar al menos una variedad.', 'warning');
            return;
        }
        
        this.variedadesFormList = this.variedadesFormList.filter(item => item.key !== indexToDelete);
        this.recalcularNumeracionBloques();
    }

    recalcularNumeracionBloques() {
        this.variedadesFormList = this.variedadesFormList.map((item, idx) => {
            return { ...item, numero: idx + 1 };
        });
    }

    handleCloseVariedadesModal() {
        this.showVariedadesModal = false;
        this.variedadesFormList = [];
        this.productoOptions = [];
    }

    handleFinalizarDeclaracion() {
        if (!this.validarBloquesCompletos()) {
            this.showToast('Atención', 'Por favor complete todos los campos requeridos en los bloques de variedades.', 'warning');
            return;
        }
        
        const currentTxId = this.selectedTx?.Id;

        this.isLoading = true;
        if (currentTxId) {
            this.setTxSavingState(currentTxId, true);
        }
        
        const itemsAAgregar = this.variedadesFormList.map(item => {
            return {
                sobjectType: 'Item_de_DUP__c',
                Producto__c: item.productoId,
                Cantidad_Declarada__c: parseFloat(item.cantidad),
                Densidad_de_Siembra__c: parseFloat(item.densidad),
                Transaccion__c: currentTxId,
                Estado__c: 'Uso Propio',
                Campana_Agricola__c: this.selectedTx.Campana__c,
                Obtentor__c: this.selectedTx.Obtentor__c
            };
        });
        
        guardarVariedadesDeclaradas({ items: itemsAAgregar })
            .then(() => {
                this.showVariedadesModal = false;
                this.showToast('Éxito', 'Declaración de variedades guardada correctamente.', 'success');
                return refreshApex(this.wiredTransaccionesResult);
            })
            .catch(error => {
                console.error('Error al registrar las variedades masivas:', error);
                this.showToast('Error de Guardado', error?.body?.message || 'No se pudo procesar la declaración.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
                if (currentTxId) {
                    this.setTxSavingState(currentTxId, false);
                }
            });
    }

    clearForm() {
        this.selectedObtentor = '';
        this.selectedCultivo = '';
        this.selectedCampana = '';
        this.comentarios = '';
        this.attachedFileId = '';
        this.attachedFileName = '';
        this.cultivoOptions = [];
        this.campanaOptions = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}