import { LightningElement } from 'lwc';
import getAdhesion from '@salesforce/apex/CuentaGranaria.getAdhesion';
// import getToneladas from '@salesforce/apex/CuentaGranaria.getToneladas'; // COMENTADO - flujo por biotecnología
// import getCampanas from '@salesforce/apex/CuentaGranaria.getCampanas'; // COMENTADO - reemplazado por getCampanasConTotales
import getCampanasConTotales from '@salesforce/apex/CuentaGranaria.getCampanasConTotales';
import getToneladasByCampana from '@salesforce/apex/CuentaGranaria.getToneladasByCampana';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getDetalleBT from '@salesforce/apex/CuentaGranaria.getDetalleBT';
import getRegularizarPorCampana from '@salesforce/apex/CuentaGranaria.getRegularizarPorCampana';
import IMAGENES from '@salesforce/resourceUrl/CuentaGranariaIcons';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import { doRequest, errorEvent, warningEvent } from 'c/utils';
import { trackGa4Event, trackGa4PageView } from 'c/portalGa4Events';
import MESA_AYUDA_EMAIL from '@salesforce/label/c.Mesa_Ayuda_Email';

export default class CuentaGranariaNew extends LightningElement {

    mesaAyudaEmail = MESA_AYUDA_EMAIL;

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
    mostrarVarietal = false;
    detalleAbierto = false;
    vistaVariedades = false;
    regularizarPorCampana = {};
    mesaAyudaUrl = 'https://wa.me/5491131172022';
    campanasEnMobile = false;
    campanasMq;
    _onCampanasMq;
    _pageViewGa4;

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
    errorCarga = false;
    varietalCargado = false;
    _profundidad = 0;
    _scrollPorClave = {};
    _onPopState;
    _reintento;

    // ====== STEPS ======
    step = 1;

    get isStep1Active() { return this.step === 1; }
    get isStep2Active() { return this.step === 2; }
    get isStep3Active() { return this.step === 3; }

    get showStep1Panel() {
        return this.isStep1Active && this.mostrarContenido;
    }

    get showStep2Panel() {
        return this.isStep2Active && this.showFilterTech && this.mostrarContenido;
    }

    get showStep3Panel() {
        return (
            this.isStep3Active &&
            this.cultivo &&
            this.biotecnologia &&
            Array.isArray(this.campanas) &&
            !this.detalleAbierto &&
            !this.vistaVariedades &&
            this.mostrarContenido
        );
    }

    get sinCampanas() {
        return this.showStep3Panel && this.campanas.length === 0;
    }

    get mostrarEsqueleto() {
        if (this.errorCarga) return false;
        if (!this.cultivos) return true;
        if (this.step === 3 && this.campanas == null) return true;
        if (this.mostrarVarietal && !this.varietalCargado) return true;
        if (this.loading && this.campanaSeleccionada && !this.isTrigo && !this.totales) return true;
        return false;
    }

    get claseVarietal() {
        return this.varietalCargado ? '' : 'cg-hide';
    }

    handleVarietalListo() {
        this.varietalCargado = true;
    }

    get mostrarContenido() {
        return !this.errorCarga && !this.mostrarEsqueleto;
    }

    get campanaIngresada() {
        return !!(this.campanaSeleccionada && (this.mostrarVarietal || this.totales));
    }

    get rootClass() {
        return 'cg-root' + (this.campanaIngresada ? ' is-ingresada' : '');
    }

    get muestraVolverIngreso() {
        return this.campanaIngresada && this.isTrigo && !this.detalleAbierto && !this.vistaVariedades;
    }

    get muestraVolverCampanas() {
        return this.muestraVolverIngreso;
    }

    handleDetalleChange(event) {
        this.detalleAbierto = !!event.detail?.abierto;
    }

    handleVistaChange(event) {
        this.vistaVariedades = event.detail?.vista === 'variedades';
    }

    handleSalirCampana(event) {
        this.handleSubirNivel(event);
    }

    cerrarCampanaSinHistorial() {
        this.campanaSeleccionada = null;
        this.mostrarVarietal = false;
        this.totales = null;
        this.detalleAbierto = false;
        this.vistaVariedades = false;
        this.varietalCargado = false;
    }

    get wizardStepsTotal() {
        return 3;
    }

    get wizardStepLabels() {
        return ['Cultivo', 'Plataforma', 'Campaña'];
    }

    get wizardStepLabelList() {
        return [
            this.cultivoName ? `Cultivo · ${this.cultivoName}` : 'Cultivo',
            this.step >= 2 && this.biotecnologiaLabel
                ? `Plataforma · ${this.biotecnologiaLabel}`
                : 'Plataforma',
            this.campanaSeleccionadaPeriod ? `Campaña · ${this.campanaSeleccionadaPeriod}` : 'Campaña'
        ];
    }

    get wizardProgressLabel() {
        return `Paso ${this.step} de ${this.wizardStepsTotal}`;
    }

    get progressEyebrow() {
        return `Cuenta Granaria · Paso ${this.step} de ${this.wizardStepsTotal}`;
    }

    get pphRibbonUrl() {
        return this.images.pph;
    }

    get biotecnologiaLabel() {
        if (!this.biotecnologia) return '';
        const plats = this.biotecnologias || [];
        const match = plats.find((p) => p.value === this.biotecnologia);
        return match?.label || this.biotecnologia;
    }

    get continuarPaso1Disabled() {
        return !this.cultivoSeleccionadoId;
    }

    get continuarPaso2Disabled() {
        return !this.biotecnologia;
    }

    get cultivoNameDisplay() {
        if (!this.cultivoName) return '';
        const raw = this.cultivoName.toLowerCase();
        return raw.charAt(0).toUpperCase() + raw.slice(1);
    }

    handleProgStepClick(event) {
        const clickedStep = Number(event.detail?.step);
        this.goToStep(clickedStep);
    }

    handleStepClick(event) {
        const clickedStep = Number(event.currentTarget.dataset.step);
        this.goToStep(clickedStep);
    }

    goToStep(clickedStep) {
        if (!clickedStep || clickedStep > this.step) return;
        this.guardarScroll();
        this.step = clickedStep;
        if (clickedStep < 3) {
            this.totales = null;
            this.campanaSeleccionada = null;
            this.mostrarVarietal = false;
        }
        this.detalleAbierto = false;
        this.vistaVariedades = false;
        if (clickedStep < 2) {
            this.biotecnologia = null;
            this.campanas = null;
        }
        this.empujarUrl({ limpiarMarcas: true });
    }

    handleBackToPaso1(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.step = 1;
        this.detalleAbierto = false;
        this.vistaVariedades = false;
        this.biotecnologia = null;
        this.campanas = null;
        this.totales = null;
        this.campanaSeleccionada = null;
        this.mostrarVarietal = false;
        this.escribirCultivoUrl({ limpiarMarcas: true });
    }

    handleBackToPaso2(event) {
        this.handleSubirNivel(event);
    }

    handleSubirNivel(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.aplicarSubida();
        this.escribirCultivoUrl({ limpiarMarcas: !this.campanaIngresada });
        this.restaurarScroll();
    }

    aplicarSubida() {
        if (this.campanaIngresada) {
            this.cerrarCampanaSinHistorial();
            return;
        }
        if (this.step === 3) {
            this.step = 2;
            this.totales = null;
            this.campanaSeleccionada = null;
            this.mostrarVarietal = false;
            return;
        }
        if (this.step === 2) {
            this.handleBackToPaso1();
        }
    }

    handleContinuarPaso1(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (!this.cultivoSeleccionadoId) return;
        this.guardarScroll();
        this.cultivo = this.cultivoSeleccionadoId;
        this.reset();
        this.verificarAdhesion();
        this.avanzarTrasCultivo({ desdeUrl: false });
        this.empujarUrl({ limpiarMarcas: true });
        trackGa4Event('cuenta_granaria_paso', {
            paso: 1,
            nombre_paso: 'cultivo',
            cultivo: this.cultivoName
        });
    }

    handlePickPlataforma(event) {
        this.biotecnologia = event.currentTarget.dataset.value;
    }

    handleContinuarPaso2(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (!this.biotecnologia) return;
        this.guardarScroll();
        this.totales = null;
        this.campanaSeleccionada = null;
        this.cargarCampanas(this.cultivo);
        this.step = 3;
        this.empujarUrl();
        trackGa4Event('cuenta_granaria_paso', {
            paso: 2,
            nombre_paso: 'plataforma',
            cultivo: this.cultivoName,
            subsistema: this.biotecnologiaLabel
        });
    }

    get plataformasDelCultivo() {
        const nombre = this.cultivoName;
        return nombre ? this.tecnologias[nombre] || [] : [];
    }

    avanzarTrasCultivo({ desdeUrl } = {}) {
        const plats = this.plataformasDelCultivo;
        if (plats.length === 1) {
            this.biotecnologia = plats[0].value;
        }
        const hayDestino = !!desdeUrl && (this.leerParametro('campana') || this.tieneMarcasUrl());
        if (hayDestino) {
            this.cargarCampanas(this.cultivo, { entrarSiHayUrl: true });
            this.step = 3;
            return;
        }
        this.step = 2;
    }

    // ====== INIT ======
    get paramCultivo() {
        return this.leerParametro('cultivo') || this.leerParametro('cultivoId');
    }

    leerParametro(nombre) {
        try {
            return new URL(window.location.href).searchParams.get(nombre);
        } catch (e) {
            return null;
        }
    }

    tieneMarcasUrl() {
        return !!(this.leerParametro('marcas') || this.leerParametro('variedad'));
    }

    resolverCultivoDesdeUrl() {
        const nombre = (this.leerParametro('cultivo') || '').trim();
        const id = (this.leerParametro('cultivoId') || '').trim();
        const lista = this.cultivos || [];
        if (nombre) {
            const porNombre = lista.find((c) => String(c.Name).toUpperCase() === nombre.toUpperCase());
            if (porNombre) return porNombre;
        }
        if (id) {
            const porId = lista.find((c) => c.Id === id);
            if (porId) return porId;
        }
        if (this.tieneMarcasUrl() || this.leerParametro('campana')) {
            return lista.find((c) => String(c.Name).toUpperCase() === 'TRIGO') || null;
        }
        return null;
    }

    PARAMS_SENSIBLES = ['cuit', 'ctg', 'razon', 'razonsocial', 'account', 'accountid', 'nombre'];

    claveVista() {
        if (this.detalleAbierto) return 'detalle';
        if (this.vistaVariedades) return 'variedades';
        if (this.campanaIngresada) return 'marcas';
        return `step-${this.step}`;
    }

    guardarScroll() {
        try {
            this._scrollPorClave[this.claveVista()] = window.scrollY || 0;
        } catch (e) {
            // Si el scroll no está disponible, se abre arriba.
        }
    }

    restaurarScroll() {
        const y = this._scrollPorClave[this.claveVista()];
        window.setTimeout(() => {
            window.scrollTo({ top: y || 0, behavior: 'auto' });
        }, 0);
    }

    empujarUrl(opciones) {
        this._profundidad += 1;
        this.escribirCultivoUrl({ ...(opciones || {}), empujar: true });
    }

    escribirCultivoUrl({ limpiarMarcas, empujar } = {}) {
        try {
            const url = new URL(window.location.href);
            this.PARAMS_SENSIBLES.forEach((nombre) => url.searchParams.delete(nombre));
            const nombre = (this.cultivoName || '').toLowerCase();
            if (this.cultivo && this.step > 1 && nombre) {
                url.searchParams.set('cultivo', nombre);
            } else {
                url.searchParams.delete('cultivo');
            }
            url.searchParams.delete('cultivoId');
            const preservarDestino =
                !limpiarMarcas &&
                !this.campanaIngresada &&
                !!(this.leerParametro('campana') || this.tieneMarcasUrl());
            if (this.campanaSeleccionada && this.campanaIngresada) {
                url.searchParams.set('campana', this.campanaSeleccionada);
            } else if (!preservarDestino) {
                url.searchParams.delete('campana');
            }
            if (limpiarMarcas || (!preservarDestino && (this.step < 3 || !this.campanaIngresada))) {
                url.searchParams.delete('marcas');
                url.searchParams.delete('variedad');
            }
            const href = `${url.pathname}${url.search}${url.hash}`;
            if (empujar) {
                window.history.pushState(window.history.state, document.title, href);
            } else {
                window.history.replaceState(window.history.state, document.title, href);
            }
        } catch (e) {
            // Si el history no está disponible, el wizard igual avanza en memoria.
        }
    }

    aplicarDesdeHistorial() {
        const cultivoUrl = this.leerParametro('cultivo');
        const campanaUrl = this.leerParametro('campana');
        if (this.campanaIngresada && !campanaUrl) {
            this.cerrarCampanaSinHistorial();
            return;
        }
        if (!cultivoUrl) {
            this.handleBackToPaso1();
            return;
        }
        if (this.step === 3) {
            this.step = 2;
            this.totales = null;
            this.campanaSeleccionada = null;
            this.mostrarVarietal = false;
            return;
        }
        if (this.step === 2) {
            this.handleBackToPaso1();
        }
    }

    handlePopState() {
        if (this.campanaIngresada && (this.detalleAbierto || this.vistaVariedades)) {
            this.template.querySelector('c-cuenta-granaria-varietal')?.sincronizarDesdeUrl();
            this.restaurarScroll();
            return;
        }
        this._profundidad = Math.max(0, this._profundidad - 1);
        this.aplicarSubida();
        this.escribirCultivoUrl({ limpiarMarcas: !this.campanaIngresada });
        this.restaurarScroll();
    }

    connectedCallback() {
        document.documentElement.classList.add('se-inner');
        document.body.classList.add('se-inner');
        this._onPopState = () => this.handlePopState();
        window.addEventListener('popstate', this._onPopState);
        if (typeof window !== 'undefined' && window.matchMedia) {
            this.campanasMq = window.matchMedia('(max-width: 900px)');
            this.campanasEnMobile = this.campanasMq.matches;
            this._onCampanasMq = (event) => {
                this.campanasEnMobile = event.matches;
            };
            if (this.campanasMq.addEventListener) {
                this.campanasMq.addEventListener('change', this._onCampanasMq);
            } else if (this.campanasMq.addListener) {
                this.campanasMq.addListener(this._onCampanasMq);
            }
        }
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-inner');
        document.body.classList.remove('se-inner');
        if (this._onPopState) {
            window.removeEventListener('popstate', this._onPopState);
        }
        if (this.campanasMq && this._onCampanasMq) {
            if (this.campanasMq.removeEventListener) {
                this.campanasMq.removeEventListener('change', this._onCampanasMq);
            } else if (this.campanasMq.removeListener) {
                this.campanasMq.removeListener(this._onCampanasMq);
            }
        }
    }

    init() {
        this.initialized = true;

        doRequest.call(this, async _ => {
            this._reintento = 'init';
            this.errorCarga = false;
            const data = await getLoadData();
            this.cultivos = data.cultivos;
            trackGa4Event('cuenta_granaria_vista', { portal: 'Productor' });
            const elegido = this.resolverCultivoDesdeUrl();
            if (elegido) {
                this.cultivo = elegido.Id;
                this.cultivoSeleccionadoId = elegido.Id;
                this.verificarAdhesion();
                this.avanzarTrasCultivo({ desdeUrl: true });
            }
        });
    }

    renderedCallback() {
        if (!this.initialized) {
            this.init();
        }
        if (this._scrollToResumen) {
            const el = this.template.querySelector('.cg-resumen');
            if (el) {
                this._scrollToResumen = false;
                el.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
        this.emitirPageViewGa4();
    }

    paramsGa4(extra = {}) {
        const params = { portal: 'Productor' };
        if (this.cultivoName) params.cultivo = this.cultivoName;
        if (this.campanaSeleccionadaPeriod) params.campaña = this.campanaSeleccionadaPeriod;
        if (this.biotecnologiaLabel) params.subsistema = this.biotecnologiaLabel;
        return { ...params, ...extra };
    }

    tituloPageViewGa4() {
        const cultivo = this.cultivoNameDisplay;
        if (!cultivo || this.mostrarEsqueleto || this.errorCarga) return null;
        const base = `Cuenta Granaria · ${cultivo}`;
        if (this.detalleAbierto) return `${base} · Detalle de variedad`;
        if (this.vistaVariedades) return `${base} · Variedades`;
        if (this.campanaIngresada && this.isTrigo) return `${base} · Resumen varietal`;
        if (this.step === 3 && Array.isArray(this.campanas) && !this.campanaIngresada) {
            return `${base} · Campañas`;
        }
        return null;
    }

    emitirPageViewGa4() {
        const title = this.tituloPageViewGa4();
        if (!title) {
            this._pageViewGa4 = null;
            return;
        }
        if (title === this._pageViewGa4) return;
        this._pageViewGa4 = title;
        trackGa4PageView(title);
    }

    // ====== CULTIVOS CON ICONOS ======
    get decoratedCultivos() {
        return (this.cultivos || []).map(c => {
            const nombre = c.Name;
            const id = c.Id;
            const selected = this.cultivoSeleccionadoId === id;
            return {
                ...c,
                nombre,
                nombreUpper: (nombre || '').toUpperCase(),
                id,
                icono: this.getIcon(nombre),
                ariaChecked: selected ? 'true' : 'false',
                cssClass: 'cg-cultivo-tile' + (selected ? ' is-selected' : '')
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
        event.preventDefault();
        event.stopPropagation();
        const cultivoId = event.currentTarget.dataset.id;
        this.cultivoSeleccionadoId = cultivoId;
        this.cultivo = cultivoId;
        console.log('Cultivo seleccionado:', event.currentTarget.dataset.nombre, cultivoId);
    }

    // ====== ADHESIÓN ======
    verificarAdhesion() {
        doRequest.call(this, async _ => {
            this.adhesion = await getAdhesion({ cultivoId: this.cultivo });
        });
    }

    // ====== CAMPAÑAS ======
    cargarCampanas(cultivoId, opciones = {}) {
        doRequest.call(this, async _ => {
            this._reintento = 'campanas';
            this.errorCarga = false;
            const result = await getCampanasConTotales({ cultivoId, tecnologias: this.biotecnologia });
            console.log('Campañas con totales:', JSON.stringify(result));
            this.regularizarPorCampana = {};
            if (this.isTrigo && result && result.length) {
                this.regularizarPorCampana = (await getRegularizarPorCampana({
                    campaniaIds: result.map((c) => c.id),
                    tecnologias: this.biotecnologia
                })) || {};
            }
            this.campanas = result || [];
            if (opciones.entrarSiHayUrl && !this.campanaSeleccionada) {
                this.entrarCampanaDesdeUrl();
            }
        });
    }

    entrarCampanaDesdeUrl() {
        const idUrl = this.leerParametro('campana');
        let camp = idUrl ? this.decoratedCampanas.find((item) => item.id === idUrl) : null;
        if (!camp && this.tieneMarcasUrl()) {
            camp = this.decoratedCampanas.find(
                (item) => item.isCurrent && !item.ingresarDisabled && !item.muestraComprarHT
            );
        }
        if (!camp || camp.ingresarDisabled) return;
        this.campanaSeleccionada = camp.id;
        if (this.isTrigo) {
            this.varietalCargado = false;
            this.mostrarVarietal = true;
        } else {
            this.getData();
        }
        this.escribirCultivoUrl();
    }

    // Año cruzado como en Home y Compra HT: '2026' -> '26/27'
    getCampanaPeriod(ano) {
        const year = parseInt(ano, 10);
        if (isNaN(year)) return ano;
        const next = String(year + 1).slice(-2);
        const curr = String(year).slice(-2);
        return `${curr}/${next}`;
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

        const flaggedIdx = sorted.findIndex((c) => c.esActual === true);
        const activaIdx = sorted.map((c) => c.estado).lastIndexOf('Activa');
        const currentIdx = flaggedIdx >= 0 ? flaggedIdx : activaIdx >= 0 ? activaIdx : sorted.length - 1;

        const cards = sorted.map((c, idx) => {
            const isCurrent = idx === currentIdx;
            const isPrecampana = !isCurrent && c.estado === 'En Preparación';
            const hasAdhesion = c.pphAdherida === true;
            const showPPH = hasAdhesion;
            const displayToneladas = Number(c.saldoCuentaGranaria ?? 0) || 0;
            const isSelected = this.campanaSeleccionada === c.id;
            const isNegativa = !showPPH && displayToneladas < 0;
            // Regla de negocio (prod): solo la campaña actual admite Ingresar;
            // si esa campaña está adherida a PPH, el CTA queda deshabilitado.
            const ingresarDisabled = !isCurrent || showPPH;

            const regularizar = this.isTrigo && !showPPH ? this.regularizarPorCampana?.[c.id] : null;
            const aRegularizar = Number(regularizar?.toneladas) || 0;
            const conRegularizar = aRegularizar > 0;
            const sinHT =
                this.isTrigo &&
                isCurrent &&
                !showPPH &&
                !conRegularizar &&
                displayToneladas === 0 &&
                (Number(c.totalCompraHT) || 0) <= 0;
            const negativas = regularizar?.variedades || [];
            const textoNegativas = negativas.length === 1
                ? '1 variedad a regularizar'
                : `${negativas.length} variedades a regularizar`;
            const nombresNegativas = negativas.length > 3
                ? `${negativas.slice(0, 3).join(' · ')} · +${negativas.length - 3}`
                : negativas.join(' · ');
            const cifra = sinHT ? 0 : conRegularizar ? aRegularizar : displayToneladas;

            return {
                ...c,
                period: this.getCampanaPeriod(c.ano),
                displayName: this.cultivoName,
                displayToneladas: cifra,
                unidad: conRegularizar && !sinHT ? 't a regularizar' : 'toneladas',
                unitClass: 'cg-camp-unit' + (conRegularizar && !sinHT ? ' is-neg' : ''),
                infoClass: 'cg-info-i' + (conRegularizar && !sinHT ? ' is-warn' : ''),
                muestraNegativas: conRegularizar && isCurrent && !sinHT,
                textoNegativas,
                nombresNegativas,
                muestraMesaAyuda: conRegularizar && !isCurrent,
                muestraComprarHT: sinHT,
                muestraIngresar: !sinHT,
                figClass: 'cg-camp-fig' + ((isNegativa || conRegularizar) && !sinHT ? ' is-neg' : ''),
                cssClass: 'cg-camp-card' + (isSelected ? ' is-selected' : ''),
                btnClass:
                    'cg-btn cg-btn-block' +
                    (isSelected ? ' cg-btn-camp-sel' : ' cg-btn-primary'),
                tipTitle: showPPH
                    ? 'Campaña Adherida a PPH'
                    : conRegularizar && !sinHT
                      ? 'Toneladas a regularizar'
                      : 'Saldo disponible de esta campaña',
                tipBody: showPPH
                    ? 'Podés entregar tu grano sin segregar tecnologías en función del plan de siembra informado.'
                    : conRegularizar && !sinHT
                      ? 'Es lo que te falta en las variedades que deben regularizar en esta campaña (saldo menor a −1 HT, o sea −4 t). Un saldo positivo no compensa el negativo de otra variedad.'
                      : 'Es el saldo que se usa primero cuando realizás una entrega de grano de esta campaña. Si tenés saldo suficiente, se debita automáticamente. Si no alcanza, el sistema utilizará tus HT disponibles.',
                isLast: isCurrent,
                isCurrent,
                showPPH,
                hideToneladas: showPPH,
                hasAdhesion,
                ingresarDisabled,
                ariaDisabled: ingresarDisabled ? 'true' : 'false',
                isDisabled: ingresarDisabled,
                statusMeta: hasAdhesion
                    ? 'Campaña con PPH'
                    : isCurrent
                      ? 'Activa · disponible'
                      : isPrecampana
                        ? 'Precampaña'
                        : 'Histórico',
                adhesionVencimiento: hasAdhesion ? c.pphVencimiento || null : null,
                saldoCuentaGranaria: c.saldoCuentaGranaria || 0,
                totalToneladasOriginal: c.totalToneladas || 0
            };
        });
        return this.campanasEnMobile ? cards.slice().reverse() : cards;
    }

    handleSelectCampana(event) {
        const index = Number(event.currentTarget.getAttribute('data-index'));
        const camp = this.decoratedCampanas[index];
        if (!camp || camp.ingresarDisabled) {
            return;
        }

        this.guardarScroll();
        const campanaId = event.currentTarget.dataset.id;
        this.campanaSeleccionada = campanaId;
        this._scrollToResumen = true;
        if (this.isTrigo) {
            this.totales = null;
            this.varietalCargado = false;
            this.mostrarVarietal = true;
            this.empujarUrl();
            return;
        }
        this.mostrarVarietal = false;
        this.empujarUrl();
        this.getData();
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
    handleSelectPlataforma(event) {
        this.biotecnologia = event.currentTarget.dataset.value;
        console.log('Biotecnología seleccionada:', this.biotecnologia);
        this.totales = null;
        this.campanaSeleccionada = null;
        this.cargarCampanas(this.cultivo);
        this.step = 3;
    }

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
            this._reintento = 'resumen';
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
            trackGa4Event('cuenta_granaria_creditos', this.paramsGa4());
        });
    }

    descargarDetalle(event) {
        const origen = event.currentTarget.dataset.name;
        const ids = this.toneladas.filter(tn => tn.Origen__c == origen).map(tn => tn.Id);

        if (ids.length) {
            doRequest.call(this, async _ => {
                this._reintento = 'descarga';
                const result = await getDetalleBT({ toneladasIds: ids });
                const downLink = document.createElement('a');
                downLink.href = 'data:text/csv;charset=utf-8,' + encodeURI(result);
                downLink.target = '_blank';
                downLink.download = `detalle_toneladas_${origen}.csv`.toLowerCase().replace(' ', '_');
                downLink.click();
                if (origen === 'BolsaTech') {
                    trackGa4Event('reporte_generado', {
                        modulo: 'CuentaGranaria',
                        tipo_reporte: 'entregas_bolsatech',
                        ...this.paramsGa4()
                    });
                }
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

    handleComprarHTCampana() {
        const entrada = {
            cultivo: 'trigo',
            tipo: 'disponible',
            origen: 'cuenta_granaria_campana',
            accion: 'comprar',
            volver: `${window.location.pathname}${window.location.search}${window.location.hash}`
        };
        try {
            sessionStorage.setItem('se_compra_ht_entrada', JSON.stringify(entrada));
        } catch (e) {
            // Si el storage falla, Compra HT arranca en el paso 1.
        }
        const portalBase = window.location.pathname.split('/s/')[0];
        window.location.href = `${portalBase}/s/FormularioNuevaVentaHT`;
    }

    // ====== UTILS ======
    reset() { 
        this.totales = null; 
        this.campanaSeleccionada = null;
        this.campanas = null;
        this.biotecnologia = null;
        this.mostrarVarietal = false;
        this.detalleAbierto = false;
        this.vistaVariedades = false;
        this.varietalCargado = false;
    }

    get isTrigo() {
        return this.cultivoName === 'TRIGO';
    }

    onError(e) {
        this.errorCarga = true;
        const codigo =
            this._reintento === 'descarga'
                ? 'CG_DESCARGA'
                : this._reintento === 'varietal' || this._reintento === 'resumen'
                    ? 'CG_CARGA_RESUMEN'
                    : 'CG_CARGA_CAMPANAS';
        this.dispatchEvent(errorEvent(e, { mensaje_corto: codigo, modulo: 'CuentaGranaria' }));
    }

    handleMesaAyuda(event) {
        trackGa4Event('cuenta_granaria_mesa_ayuda', {
            cultivo: this.cultivoName,
            campaña: event.currentTarget.dataset.campana || '',
            origen: 'campana_anterior'
        });
    }

    handleReintentar() {
        this.errorCarga = false;
        if (this._reintento === 'campanas' && this.cultivo) {
            this.cargarCampanas(this.cultivo, { entrarSiHayUrl: true });
            return;
        }
        if (this._reintento === 'varietal') {
            this.template.querySelector('c-cuenta-granaria-varietal')?.recargar();
            return;
        }
        if (this.campanaSeleccionada && !this.isTrigo) {
            this.getData();
            return;
        }
        this.initialized = false;
        this.init();
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
        return this.showCampanaSelector && !this.isTrigo;
    }

    get muestraVolverPlataforma() {
        return this.showStep3Panel && this.isTrigo && !this.campanaIngresada;
    }

    get textoVolverPaso3() {
        return '← Volver a Plataforma';
    }

    get campLayoutClass() {
        return 'cg-camp-layout' + (this.isTrigo ? ' is-solo' : '');
    }

    get showInfoRegaliaEnlist(){
        return this.biotecnologia == 'Enlist E3/Conkesta E3';
    }

    get biotecnologias() {
        console.log('Tecnologías disponibles para cultivo', this.cultivoName, ':', this.cultivoOptions.find(c => c.value == this.cultivo).label);
        console.log('Cultivo seleccionado:', this.cultivo);


        return this.tecnologias[this.cultivoOptions.find(c => c.value == this.cultivo).label];
    }

    get decoratedPlataformas() {
        return (this.biotecnologias || []).map((p) => {
            const selected = this.biotecnologia === p.value;
            return {
                ...p,
                ariaChecked: selected ? 'true' : 'false',
                cssClass: 'cg-plat-opt' + (selected ? ' is-selected' : '')
            };
        });
    }

    get needsRegularizar() {
        return Number(this.totalToneladasRegularizar) > 0;
    }

    get regularizarCardClass() {
        return 'cg-reg-card' + (this.needsRegularizar ? ' is-warn' : '');
    }

    get resumenRows() {
        if (!this.totales) return [];
        const rows = (this.totales || []).map((t) => ({
            key: `origen-${t.label}`,
            label: t.label,
            value: t.value,
            origen: t.origen,
            canDownload: false,
            rowClass: '',
            cardClass: 'cg-mcard'
        }));

        rows.push({
            key: 'bolsatech',
            label: this.totalBolsatech.label,
            value: this.totalBolsatech.value,
            origen: this.totalBolsatech.origen,
            canDownload: true,
            rowClass: '',
            cardClass: 'cg-mcard'
        });

        if (this.showInfoRegaliaEnlist) {
            rows.push({
                key: 'regalia-pagada',
                label: this.totalRegaliaEnlistPagada.label,
                value: this.totalRegaliaEnlistPagada.value,
                origen: this.totalRegaliaEnlistPagada.origen,
                canDownload: false,
                rowClass: '',
                cardClass: 'cg-mcard'
            });
        }

        if (this.showTotalTransferencia) {
            rows.push({
                key: 'transferencia',
                label: this.totalTransferencia.label,
                value: this.totalTransferencia.value,
                origen: this.totalTransferencia.origen,
                canDownload: false,
                rowClass: '',
                cardClass: 'cg-mcard'
            });
        }

        return rows;
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