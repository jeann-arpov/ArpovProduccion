import { LightningElement, api } from 'lwc';
import getResumenVarietal from '@salesforce/apex/CuentaGranaria.getResumenVarietal';
import getDetalleVarietal from '@salesforce/apex/CuentaGranaria.getDetalleVarietal';
import getEntregasVarietal from '@salesforce/apex/CuentaGranaria.getEntregasVarietal';
import { doRequest, errorEvent } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';
import { ensureXlsxLoaded, downloadVentasWorkbook } from 'c/ventasInformadasExcelUtil';
import icons from 'c/icons';

const ENTREGAS_HEADERS = ['Fecha', 'Marca', 'Variedad', 'CTG', 'Kg netos', 'Toneladas'];

const ESTADOS = ['Debe regularizar', 'En regla', 'Sin entregas'];
const ESTADOS_GA4 = {
    'Debe regularizar': 'debe_regularizar',
    'En regla': 'en_regla',
    'Sin entregas': 'sin_entregas'
};

/** BASF/Credenz y LG: el SVG no entra bien en <img> (symbol / sin viewBox). ACA no tiene SVG. */
const SEMILLEROS_LOGO_JPG = ['77', '26', '12'];

function logoMarca(idObtentor) {
    if (!idObtentor) return null;
    if (SEMILLEROS_LOGO_JPG.includes(idObtentor)) {
        return icons.marcas?.[idObtentor] || null;
    }
    const sprite = icons.semilleros?.[idObtentor];
    if (sprite) return sprite.split('#')[0];
    return icons.marcas?.[idObtentor] || null;
}

export default class CuentaGranariaVarietal extends LightningElement {
    @api campaniaLabel;
    @api subsistema;

    loading = false;
    errorCarga = false;
    logosFallidos = [];
    _scrollPorClave = {};
    _detalleEmpujado = false;
    _variedadesEmpujadas = false;
    resumen;
    detalle;
    busqueda = '';
    elegidas = [];
    vistaMovil = false;
    estados = {
        'Debe regularizar': true,
        'En regla': true,
        'Sin entregas': true
    };

    _campaniaId;
    _tecnologias;
    _pending = false;
    _resetVista = false;
    _detalleMarcaId;
    _variedadesTimer;
    _busquedaTimer;
    _errorGa4 = 'CG_CARGA_RESUMEN';

    @api
    get campaniaId() {
        return this._campaniaId;
    }

    set campaniaId(value) {
        if (value === this._campaniaId) return;
        this._campaniaId = value;
        this._resetVista = true;
        this._pending = true;
    }

    @api
    get tecnologias() {
        return this._tecnologias;
    }

    set tecnologias(value) {
        if (value === this._tecnologias) return;
        this._tecnologias = value;
        this._pending = true;
    }

    renderedCallback() {
        if (this._pending && this._campaniaId) {
            this._pending = false;
            if (this._resetVista) {
                this._resetVista = false;
                if (this.detalle) {
                    this.detalle = null;
                    this._detalleMarcaId = null;
                    this.dispatchEvent(new CustomEvent('detallechange', { detail: { abierto: false } }));
                }
                this.elegidas = [];
                this.vistaMovil = false;
                this.busqueda = '';
                this.estados = {
                    'Debe regularizar': true,
                    'En regla': true,
                    'Sin entregas': true
                };
            }
            this.cargar();
        }
        const caja = this.template.querySelector('[data-todas]');
        if (caja) {
            caja.indeterminate = this.algunasMarcas && !this.todasLasMarcas;
        }
    }

    disconnectedCallback() {
        this.cancelarVariedadesDesktop();
        this.cancelarBusquedaGa4();
    }

    @api
    recargar() {
        this.cargar();
    }

    @api
    sincronizarDesdeUrl() {
        const variedad = this.leerParametro('variedad');
        if (variedad) return;
        if (this.detalle) {
            this.detalle = null;
            this._detalleMarcaId = null;
            this._detalleEmpujado = false;
            this.avisarDetalle(false);
            this.restaurarScroll(this.vistaMovil ? 'variedades' : 'marcas');
            return;
        }
        if (this.vistaMovil) {
            this.vistaMovil = false;
            this._variedadesEmpujadas = false;
            this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'marcas' } }));
            this.restaurarScroll('marcas');
        }
    }

    cargar() {
        doRequest.call(this, async () => {
            this._errorGa4 = 'CG_CARGA_RESUMEN';
            this.errorCarga = false;
            this.resumen = await getResumenVarietal({
                campaniaId: this._campaniaId,
                tecnologias: this._tecnologias
            });
            this.aplicarMarcasUrl();
            const abierta = await this.aplicarVariedadUrl();
            if (!abierta) {
                this.escribirUrl();
            }
            trackGa4Event('cuenta_granaria_creditos', this.paramsCreditosGa4());
            this.avisarListo();
        });
    }

    avisarListo() {
        this.dispatchEvent(new CustomEvent('listo'));
    }

    onError(e) {
        this.errorCarga = true;
        this.avisarListo();
        this.dispatchEvent(errorEvent(e, {
            mensaje_corto: this._errorGa4 || 'CG_CARGA_RESUMEN',
            modulo: 'CuentaGranaria'
        }));
    }

    handleReintentar() {
        this.errorCarga = false;
        this.cargar();
    }

    get mostrarEsqueleto() {
        return this.loading && !this.errorCarga && !this.resumen;
    }

    get mostrarContenido() {
        return !this.errorCarga && !this.mostrarEsqueleto;
    }

    guardarScroll(clave) {
        try {
            this._scrollPorClave[clave] = window.scrollY || 0;
        } catch (e) {
            // Si el scroll no está disponible, se abre arriba.
        }
    }

    restaurarScroll(clave) {
        const y = this._scrollPorClave[clave];
        window.setTimeout(() => {
            window.scrollTo({ top: y || 0, behavior: 'auto' });
        }, 0);
    }

    get esDetalle() {
        return !!this.detalle;
    }

    get rootClass() {
        return 'cgv-root' + (this.vistaMovil ? ' is-variedades' : '');
    }

    get marcas() {
        return (this.resumen && this.resumen.marcas) || [];
    }

    get marcasFiltradas() {
        const texto = (this.busqueda || '').trim().toLowerCase();
        return this.marcas
            .filter((marca) => !texto || (marca.nombre || '').toLowerCase().includes(texto))
            .map((marca) => this.decorarMarca(marca));
    }

    get marcasElegidas() {
        const ids = new Set(this.elegidas);
        return this.marcas.filter((marca) => ids.has(marca.id));
    }

    get todasLasMarcas() {
        return this.marcas.length > 0 && this.elegidas.length === this.marcas.length;
    }

    get algunasMarcas() {
        return this.elegidas.length > 0;
    }

    get hayBusquedaVacia() {
        return this.marcas.length > 0 && this.marcasFiltradas.length === 0;
    }

    get textoBusquedaVacia() {
        const texto = (this.busqueda || '').trim();
        return `No encontramos marcas con “${texto}” en esta campaña.`;
    }

    get textoMetaResumen() {
        const marcas = this.marcas.length;
        const variedades = this.marcas.reduce((n, marca) => n + ((marca.variedades || []).length), 0);
        const textoVariedades = variedades === 1 ? '1 variedad' : `${variedades} variedades`;
        const textoMarcas = marcas === 1 ? '1 marca' : `${marcas} marcas`;
        const fecha = this.resumen && this.resumen.ultimaEntrega;
        const entrega = fecha ? `Última entrega informada ${this.fecha(fecha)}` : 'Última entrega informada —';
        return `${textoVariedades} en ${textoMarcas} · ${entrega}`;
    }

    get sinMarcas() {
        return !this.loading && this.resumen && this.marcas.length === 0;
    }

    get todasBoxClass() {
        let cls = 'cgv-todas-box';
        if (this.todasLasMarcas) cls += ' is-on';
        else if (this.algunasMarcas) cls += ' is-mix';
        return cls;
    }

    get contadorMarcas() {
        const n = this.elegidas.length;
        const m = this.marcas.length;
        if (!m) return 'Sin marcas en esta campaña';
        return `${n} de ${m} elegidas`;
    }

    get textoVerVariedades() {
        const n = this.elegidas.length;
        if (!n) return 'Ver variedades →';
        return n === 1 ? 'Ver variedades de 1 marca →' : `Ver variedades de ${n} marcas →`;
    }

    get variedadesElegidas() {
        return this.marcasElegidas.reduce((lista, marca) => lista.concat(marca.variedades || []), []);
    }

    get conteos() {
        const base = { 'Debe regularizar': 0, 'En regla': 0, 'Sin entregas': 0 };
        this.variedadesElegidas.forEach((variedad) => {
            base[variedad.estado] = (base[variedad.estado] || 0) + 1;
        });
        return base;
    }

    get pills() {
        const conteos = this.conteos;
        return ESTADOS.map((estado) => {
            const conteo = conteos[estado] || 0;
            const activa = !!this.estados[estado] && conteo > 0;
            return {
                estado,
                conteo,
                label: `${estado} ${conteo}`,
                disabled: conteo === 0,
                pressed: activa ? 'true' : 'false',
                cssClass: 'cgv-pill' + (activa ? ' is-on' : '') + (conteo === 0 ? ' is-off' : '')
            };
        });
    }

    get encabezadoVariedades() {
        const marcas = this.marcasElegidas.length;
        const variedades = this.variedadesElegidas.length;
        const regularizar = this.conteos['Debe regularizar'] || 0;
        const textoMarcas = marcas === 1 ? '1 marca' : `${marcas} marcas`;
        const textoVariedades = variedades === 1 ? '1 variedad' : `${variedades} variedades`;
        const textoRegularizar = regularizar === 1 ? '1 debe regularizar' : `${regularizar} deben regularizar`;
        return `${textoMarcas} · ${textoVariedades} · ${textoRegularizar}`;
    }

    get grupos() {
        const activos = this.estados;
        return this.marcasElegidas
            .map((marca) => {
                const variedades = (marca.variedades || [])
                    .filter((variedad) => activos[variedad.estado])
                    .map((variedad) => this.decorarVariedad(variedad));
                return {
                    ...this.decorarMarca(marca),
                    variedades,
                    vacio: variedades.length === 0
                };
            })
            .filter((marca) => !marca.vacio);
    }

    get sinMarcasElegidas() {
        return this.elegidas.length === 0;
    }

    get filtrosApagados() {
        return this.elegidas.length > 0 && this.grupos.length === 0 && !this.sinMarcasElegidas;
    }

    get detalleVista() {
        if (!this.detalle) return null;
        const saldo = Number(this.detalle.saldo) || 0;
        const faltan = Number(this.detalle.toneladasARegularizar) || 0;
        const ht = faltan > 0 ? Math.ceil(faltan / 4) : 0;
        return {
            ...this.detalle,
            logo: this.logo(this.detalle.idObtentor),
            chipClass: this.chipClass(this.detalle.estado),
            creditoTexto: this.formato(this.detalle.credito) + ' t',
            debitoTexto: this.formato(this.detalle.debito) + ' t',
            saldoTexto: this.formatoFirmado(saldo),
            faltanTexto: this.formato(faltan),
            muestraFaltan: faltan > 0,
            equivale: ht > 0 ? `Equivale a ${ht} HT (1 HT = 4 t).` : '',
            notaRegularizar: this.notaRegularizar(this.detalle),
            creditos: this.decorarMovimientosCredito(this.detalle.creditos, 'c'),
            debitos: this.decorarMovimientosCredito(this.detalle.debitos, 'd'),
            entregas: (this.detalle.entregas || []).map((mov, index) => {
                const tn = Number(mov.toneladas) || 0;
                const pct = this.porcentajeEntrega(mov);
                return {
                    ...mov,
                    key: `e-${index}`,
                    fechaTexto: this.fecha(mov.fecha),
                    kgTexto: mov.kgNetos == null ? '—' : this.formato(mov.kgNetos),
                    porcentajeTexto: pct == null ? '—' : `${pct}%`,
                    tituloTexto: this.unirMeta([this.fecha(mov.fecha), mov.ctg ? `CTG ${mov.ctg}` : '']),
                    metaTexto: this.unirMeta([
                        mov.kgNetos == null ? '' : `Camión ${this.formato(mov.kgNetos)} kg`,
                        pct == null || !this.detalle.variedad ? '' : `${this.detalle.variedad} ${pct}%`
                    ]),
                    toneladasTexto: this.formatoFirmado(tn),
                    toneladasClass: 'cgv-r cgv-strong' + (tn < 0 ? ' is-neg' : ''),
                    montoClass: 'cgv-mov-amt' + (tn < 0 ? ' is-neg' : tn > 0 ? ' is-pos' : '')
                };
            }),
            totalCreditosTexto: this.formatoFirmado(this.detalle.totalCreditos),
            totalDebitosTexto: this.formato(this.totalDebitosNoEntrega(this.detalle)) + ' t',
            totalDebitadoTexto: this.formato(this.detalle.totalDebitado) + ' t',
            sinCreditos: !(this.detalle.creditos || []).length,
            sinDebitos: !(this.detalle.debitos || []).length,
            sinEntregas: !(this.detalle.entregas || []).length
        };
    }

    decorarMovimientosCredito(movimientos, prefijo) {
        return (movimientos || []).map((mov, index) => {
            const tn = Number(mov.toneladas) || 0;
            const htTexto = mov.ht ? `${String(mov.ht).replace('-', '−')} HT` : '';
            return {
                ...mov,
                key: `${prefijo}-${index}`,
                fechaTexto: this.fecha(mov.fecha),
                htTexto: mov.ht ? String(mov.ht).replace('-', '−') : '',
                metaTexto: this.unirMeta([this.fecha(mov.fecha), htTexto]),
                toneladasTexto: this.formatoFirmado(tn),
                toneladasClass: 'cgv-r cgv-strong' + (tn < 0 ? ' is-neg' : tn > 0 ? ' is-pos' : ''),
                montoClass: 'cgv-mov-amt' + (tn < 0 ? ' is-neg' : tn > 0 ? ' is-pos' : '')
            };
        });
    }

    notaRegularizar(detalle) {
        const nombre = detalle?.variedad || 'esta variedad';
        const hayCesion = detalle?.tieneCesionSaliente === true;
        const hayEntregas = (detalle?.entregas || []).length > 0;
        if (hayCesion && hayEntregas) {
            return `Entregaste y cediste más grano de ${nombre} que el crédito que tenés.`;
        }
        if (hayCesion) {
            return `Cediste más grano de ${nombre} que el crédito que tenés.`;
        }
        return `Entregaste más grano de ${nombre} que el crédito que tenés.`;
    }

    totalDebitosNoEntrega(detalle) {
        return (detalle?.debitos || []).reduce((suma, mov) => suma + Math.abs(Number(mov.toneladas) || 0), 0);
    }

    decorarMarca(marca) {
        const variedades = marca.variedades || [];
        const negativas = variedades.filter((variedad) => variedad.estado === 'Debe regularizar').length;
        const elegida = this.elegidas.includes(marca.id);
        let subtitulo;
        const textoVariedades = variedades.length === 1 ? '1 variedad' : `${variedades.length} variedades`;
        if (negativas > 0) {
            subtitulo = `${textoVariedades} · ${negativas === 1 ? '1 debe regularizar' : negativas + ' deben regularizar'}`;
        } else if (variedades.every((variedad) => variedad.estado === 'Sin entregas')) {
            subtitulo = `${textoVariedades} · sin entregas`;
        } else {
            subtitulo = `${textoVariedades} · en regla`;
        }
        const chipClass = marca.estado === 'regularizar' ? 'cgv-chip is-warn' : this.chipClass(marca.estado);
        return {
            ...marca,
            elegida,
            ariaChecked: elegida ? 'true' : 'false',
            cssClass: 'cgv-marca' + (elegida ? ' is-on' : ''),
            chipClass,
            chipDeskClass: chipClass + ' cgv-solo-desk',
            chipMovilClass: chipClass + ' cgv-solo-movil',
            etiquetaCorta: negativas > 0 ? `${negativas} a regularizar` : marca.etiqueta,
            iniciales: this.iniciales(marca.nombre),
            logo: this.logo(marca.idObtentor),
            logoClass: 'cgv-logo' + (this.logo(marca.idObtentor) ? ' has-logo' : ''),
            textoVariedades,
            subtitulo,
            puedeRegularizar: negativas >= 2,
            textoRegularizar: `Regularizar ${negativas} variedades →`,
            textoAyudaRegularizar: `Te lleva a Compra HT con Trigo, HT Disponible y ${marca.nombre} ya elegidos. Solo te queda elegir las variedades.`
        };
    }

    decorarVariedad(variedad) {
        const saldo = Number(variedad.saldo) || 0;
        return {
            ...variedad,
            chipClass: this.chipClass(variedad.estado),
            creditoTexto: this.formato(variedad.credito) + ' t',
            debitoTexto: this.formato(variedad.debito) + ' t',
            saldoTexto: this.formatoFirmado(saldo),
            saldoClass: 'cgv-num' + (saldo < 0 ? ' is-neg' : saldo > 0 ? ' is-pos' : '')
        };
    }

    logo(idObtentor) {
        if (!idObtentor || this.logosFallidos.includes(idObtentor)) return null;
        return logoMarca(idObtentor);
    }

    handleLogoError(event) {
        const id = event.currentTarget?.dataset?.obtentor;
        if (id && !this.logosFallidos.includes(id)) {
            this.logosFallidos = [...this.logosFallidos, id];
        }
    }

    iniciales(nombre) {
        const palabras = String(nombre || '')
            .replace(/[().]/g, ' ')
            .split(/\s+/)
            .filter((parte) => parte && !/^(sa|srl|sas|de|la|el|y|los|las)$/i.test(parte));
        if (palabras.length > 1) {
            return (palabras[0][0] + palabras[1][0]).toUpperCase();
        }
        return (palabras[0] || 'M').slice(0, 2).toUpperCase();
    }

    chipClass(estado) {
        if (estado === 'Debe regularizar') return 'cgv-chip is-warn';
        if (estado === 'En regla') return 'cgv-chip is-ok';
        return 'cgv-chip is-muted';
    }

    formato(value) {
        const numero = Math.round(Number(value) || 0);
        return new Intl.NumberFormat('es-AR', { maximumFractionDigits: 0 }).format(Math.abs(numero));
    }

    formatoFirmado(value) {
        const numero = Math.round(Number(value) || 0);
        const texto = this.formato(numero);
        if (numero < 0) return `−${texto} t`;
        if (numero > 0) return `+${texto} t`;
        return `${texto} t`;
    }

    unirMeta(partes) {
        return (partes || []).filter((parte) => parte && String(parte).trim()).join(' · ');
    }

    porcentajeEntrega(mov) {
        const kg = Number(mov.kgNetos);
        const tnKg = Math.abs(Number(mov.toneladas) || 0) * 1000;
        if (!Number.isFinite(kg) || kg <= 0 || tnKg <= 0) return null;
        return Math.round((tnKg / kg) * 100);
    }

    fecha(value) {
        if (!value) return '';
        const partes = String(value).slice(0, 10).split('-');
        if (partes.length < 3) return value;
        return `${partes[2]}/${partes[1]}/${partes[0].slice(2)}`;
    }

    handleBuscar(event) {
        this.busqueda = event.target.value;
        this.programarBusquedaGa4();
    }

    handleBorrarBusqueda(event) {
        event.preventDefault();
        event.stopPropagation();
        this.cancelarBusquedaGa4();
        this.busqueda = '';
    }

    handleLimpiar(event) {
        event.preventDefault();
        event.stopPropagation();
        this.elegidas = [];
        this.vistaMovil = false;
        this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'marcas' } }));
        this.escribirUrl();
        this.cancelarVariedadesDesktop();
        this.trackMarcaGa4({ accion: 'limpiar' });
    }

    handleTodas(event) {
        event.preventDefault();
        event.stopPropagation();
        const seleccionarTodas = !this.todasLasMarcas;
        this.elegidas = seleccionarTodas ? this.marcas.map((marca) => marca.id) : [];
        this.escribirUrl();
        this.trackMarcaGa4({ accion: seleccionarTodas ? 'todas' : 'limpiar' });
        if (seleccionarTodas) {
            this.programarVariedadesDesktop();
        } else {
            this.cancelarVariedadesDesktop();
        }
    }

    handleMarca(event) {
        event.preventDefault();
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        const marca = this.marcas.find((item) => item.id === id);
        const quitar = this.elegidas.includes(id);
        this.elegidas = quitar
            ? this.elegidas.filter((actual) => actual !== id)
            : this.elegidas.concat(id);
        this.escribirUrl();
        this.trackMarcaGa4({
            semillero: this.semilleroGa4(marca),
            accion: quitar ? 'quitar' : 'elegir'
        });
        this.programarVariedadesDesktop();
    }

    /** CA-20: marcas en ?marcas=; al detalle solo queda ?marcas=idMarca&variedad=nombre. */
    aplicarMarcasUrl() {
        try {
            const raw = new URL(window.location.href).searchParams.get('marcas');
            if (!raw) {
                this.elegidas = [];
                return;
            }
            const validos = new Set(this.marcas.map((marca) => marca.id));
            this.elegidas = raw
                .split(',')
                .map((id) => id.trim())
                .filter((id) => validos.has(id));
        } catch (e) {
            this.elegidas = [];
        }
    }

    async aplicarVariedadUrl() {
        const nombre = this.leerParametro('variedad');
        if (!nombre) return false;
        const hallada = this.buscarVariedadPorNombre(nombre);
        if (!hallada) return false;
        await this.abrirDetalle(hallada.variedad.id, hallada.marca.id);
        return true;
    }

    escribirUrl({ empujar } = {}) {
        try {
            const url = new URL(window.location.href);
            url.searchParams.delete('cuit');
            url.searchParams.delete('ctg');
            url.searchParams.delete('razon');
            url.searchParams.delete('razonsocial');
            if (this.detalle) {
                if (this._detalleMarcaId) {
                    url.searchParams.set('marcas', this._detalleMarcaId);
                } else {
                    url.searchParams.delete('marcas');
                }
                if (this.detalle.variedad) {
                    url.searchParams.set('variedad', this.detalle.variedad);
                } else {
                    url.searchParams.delete('variedad');
                }
            } else {
                url.searchParams.delete('variedad');
                if (this.elegidas.length) {
                    url.searchParams.set('marcas', this.elegidas.join(','));
                } else {
                    url.searchParams.delete('marcas');
                }
            }
            const href = `${url.pathname}${url.search}${url.hash}`;
            if (empujar) {
                window.history.pushState(window.history.state, document.title, href);
            } else {
                window.history.replaceState(window.history.state, document.title, href);
            }
        } catch (e) {
            // Si el history no está disponible, la selección igual queda en memoria.
        }
    }

    leerParametro(nombre) {
        try {
            return new URL(window.location.href).searchParams.get(nombre);
        } catch (e) {
            return null;
        }
    }

    buscarVariedad(variedadId) {
        for (const marca of this.marcas) {
            const variedad = (marca.variedades || []).find((item) => item.id === variedadId);
            if (variedad) return { marca, variedad };
        }
        return null;
    }

    buscarVariedadPorNombre(nombre) {
        const clave = (nombre || '').trim().toLowerCase();
        if (!clave) return null;
        const alcance = this.elegidas.length
            ? this.marcas.filter((marca) => this.elegidas.includes(marca.id))
            : this.marcas;
        for (const marca of alcance) {
            const variedad = (marca.variedades || []).find(
                (item) => (item.nombre || '').trim().toLowerCase() === clave
            );
            if (variedad) return { marca, variedad };
        }
        return null;
    }

    async abrirDetalle(variedadId, marcaId, opciones = {}) {
        this._errorGa4 = 'CG_CARGA_VARIEDAD';
        this.detalle = await getDetalleVarietal({
            campaniaId: this._campaniaId,
            variedadId,
            tecnologias: this._tecnologias
        });
        this._detalleMarcaId = marcaId || this.buscarVariedad(variedadId)?.marca?.id;
        this.escribirUrl({ empujar: !!opciones.empujar });
        this._detalleEmpujado = !!opciones.empujar;
        this.avisarDetalle(true);
        const marca = this.buscarVariedad(variedadId)?.marca;
        trackGa4Event('cuenta_granaria_variedad', {
            ...this.paramsGa4(),
            semillero: this.semilleroGa4(marca),
            variedad: this.detalle.variedad,
            estado: ESTADOS_GA4[this.detalle.estado] || ''
        });
    }

    handlePill(event) {
        const estado = event.currentTarget.dataset.estado;
        const estaba = !!this.estados[estado];
        this.estados = { ...this.estados, [estado]: !estaba };
        trackGa4Event('cuenta_granaria_filtro_estado', {
            ...this.paramsGa4(),
            estado: ESTADOS_GA4[estado] || '',
            accion: estaba ? 'ocultar' : 'mostrar'
        });
    }

    handleMostrarTodas() {
        this.estados = { 'Debe regularizar': true, 'En regla': true, 'Sin entregas': true };
        trackGa4Event('cuenta_granaria_filtro_estado', {
            ...this.paramsGa4(),
            accion: 'mostrar_todas'
        });
    }

    handleVerVariedades() {
        if (!this.elegidas.length) return;
        this.guardarScroll('marcas');
        this.vistaMovil = true;
        this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'variedades' } }));
        if (!this._variedadesEmpujadas) {
            this._variedadesEmpujadas = true;
            try {
                window.history.pushState(window.history.state, document.title, `${window.location.pathname}${window.location.search}${window.location.hash}`);
            } catch (e) {
                // Si el history no está disponible, la vista igual cambia en memoria.
            }
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
        this.trackVariedadesGa4();
    }

    handleVolverMarcas() {
        this.vistaMovil = false;
        this._variedadesEmpujadas = false;
        this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'marcas' } }));
        this.restaurarScroll('marcas');
    }

    handleDetalle(event) {
        event.preventDefault();
        event.stopPropagation();
        this.guardarScroll(this.vistaMovil ? 'variedades' : 'marcas');
        const variedadId = event.currentTarget.dataset.id;
        const marcaId = event.currentTarget.dataset.marca || this.buscarVariedad(variedadId)?.marca?.id;
        doRequest.call(this, async () => {
            await this.abrirDetalle(variedadId, marcaId, { empujar: true });
        });
    }

    handleVolverCampana(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.detalle = null;
        this._detalleMarcaId = null;
        this._detalleEmpujado = false;
        this.escribirUrl();
        this.avisarDetalle(false);
        this.restaurarScroll(this.vistaMovil ? 'variedades' : 'marcas');
    }

    avisarDetalle(abierto) {
        this.dispatchEvent(new CustomEvent('detallechange', { detail: { abierto } }));
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    handleComprarHT() {
        this.irACompraHT({
            marca: this.detalle?.idObtentor,
            variedad: this.detalle?.variedadId,
            origen: 'cuenta_granaria_variedad',
            accion: 'comprar'
        });
    }

    handleRegularizarMarca(event) {
        const marca = this.marcas.find((item) => item.id === event.currentTarget.dataset.id);
        const negativas = (marca?.variedades || []).filter((v) => v.estado === 'Debe regularizar').length;
        this.irACompraHT({
            marca: marca?.idObtentor,
            origen: 'cuenta_granaria_marca',
            accion: 'regularizar',
            cantidad_variedades: negativas
        });
    }

    // Compra HT (crearCompra2) lee el contexto desde sessionStorage (sin query params en la URL).
    irACompraHT(datos) {
        const entrada = { cultivo: 'trigo', tipo: 'disponible', paso: 'variedad' };
        Object.keys(datos).forEach((clave) => {
            const valor = datos[clave];
            if (valor !== undefined && valor !== null && valor !== '') {
                entrada[clave] = String(valor);
            }
        });
        entrada.volver = `${window.location.pathname}${window.location.search}${window.location.hash}`;
        try {
            sessionStorage.setItem('se_compra_ht_entrada', JSON.stringify(entrada));
        } catch (e) {
            // Si el storage falla, igual navega; Compra HT arranca en el paso 1.
        }
        const portalBase = window.location.pathname.split('/s/')[0];
        window.location.href = `${portalBase}/s/FormularioNuevaVentaHT`;
    }

    handleDescargarEntregas() {
        doRequest.call(this, async () => {
            this._errorGa4 = 'CG_DESCARGA';
            const filas = await getEntregasVarietal({
                campaniaId: this._campaniaId,
                tecnologias: this._tecnologias
            });
            await ensureXlsxLoaded(this);
            const rows = (filas || []).map((mov) => ({
                Fecha: this.fecha(mov.fecha),
                Marca: mov.marca || '',
                Variedad: mov.variedad || '',
                CTG: mov.ctg || '',
                'Kg netos': mov.kgNetos == null ? '' : mov.kgNetos,
                Toneladas: mov.toneladas == null ? '' : mov.toneladas
            }));
            const periodo = (this.campaniaLabel || 'campania').replace(/\//g, '-');
            downloadVentasWorkbook(
                `entregas_trigo_${periodo}.xlsx`,
                rows,
                ENTREGAS_HEADERS,
                'Entregas Bolsatech'
            );
            trackGa4Event('reporte_generado', {
                modulo: 'CuentaGranaria',
                tipo_reporte: 'entregas_bolsatech',
                ...this.paramsGa4()
            });
        });
    }

    handleDescargar() {
        const vista = this.detalleVista;
        if (!vista) return;
        const lineas = ['Fecha;Origen;HT;Toneladas'];
        (vista.creditos || []).forEach((mov) => {
            lineas.push(`${mov.fechaTexto};${mov.origen || ''};${mov.htTexto};${mov.toneladas}`);
        });
        (vista.debitos || []).forEach((mov) => {
            lineas.push(`${mov.fechaTexto};${mov.origen || ''};${mov.htTexto};${mov.toneladas}`);
        });
        lineas.push('');
        lineas.push('Fecha;CTG;Kg netos;% de la variedad;Toneladas');
        (vista.entregas || []).forEach((mov) => {
            lineas.push(`${mov.fechaTexto};${mov.ctg || ''};${mov.kgNetos || ''};;${mov.toneladas}`);
        });
        this.bajarCsv(lineas, `movimientos_${(vista.variedad || 'variedad').toLowerCase().replace(/\s+/g, '_')}.csv`);
        const marca =
            this.marcas.find((item) => item.id === this._detalleMarcaId) ||
            this.buscarVariedad(vista.variedadId)?.marca;
        trackGa4Event('reporte_generado', {
            modulo: 'CuentaGranaria',
            tipo_reporte: 'movimientos_variedad',
            ...this.paramsGa4(),
            semillero: this.semilleroGa4(marca),
            variedad: vista.variedad
        });
    }

    paramsGa4() {
        return { cultivo: 'TRIGO', campaña: this.campaniaLabel };
    }

    paramsCreditosGa4() {
        return {
            ...this.paramsGa4(),
            subsistema: this.subsistema || 'Aporte Genético'
        };
    }

    semilleroGa4(marca) {
        return String(marca?.nombre || '').trim().toUpperCase();
    }

    trackMarcaGa4(extra) {
        trackGa4Event('cuenta_granaria_marca', {
            ...this.paramsGa4(),
            cantidad_marcas: this.elegidas.length,
            ...extra
        });
    }

    trackVariedadesGa4() {
        trackGa4Event('cuenta_granaria_variedades', {
            ...this.paramsGa4(),
            cantidad_marcas: this.elegidas.length
        });
    }

    esDesktopGa4() {
        try {
            return window.matchMedia('(min-width: 768px)').matches;
        } catch (e) {
            return true;
        }
    }

    programarVariedadesDesktop() {
        this.cancelarVariedadesDesktop();
        if (!this.esDesktopGa4() || !this.elegidas.length) return;
        this._variedadesTimer = setTimeout(() => {
            this._variedadesTimer = null;
            this.trackVariedadesGa4();
        }, 1000);
    }

    cancelarVariedadesDesktop() {
        if (this._variedadesTimer) {
            clearTimeout(this._variedadesTimer);
            this._variedadesTimer = null;
        }
    }

    programarBusquedaGa4() {
        this.cancelarBusquedaGa4();
        this._busquedaTimer = setTimeout(() => {
            this._busquedaTimer = null;
            const texto = (this.busqueda || '').trim();
            if (!texto) return;
            trackGa4Event('cuenta_granaria_buscar_marca', {
                ...this.paramsGa4(),
                cantidad_resultados: this.marcasFiltradas.length
            });
        }, 1000);
    }

    cancelarBusquedaGa4() {
        if (this._busquedaTimer) {
            clearTimeout(this._busquedaTimer);
            this._busquedaTimer = null;
        }
    }

    bajarCsv(lineas, nombre) {
        const enlace = document.createElement('a');
        enlace.href = 'data:text/csv;charset=utf-8,' + encodeURI(lineas.join('\n'));
        enlace.download = nombre;
        enlace.click();
    }
}
