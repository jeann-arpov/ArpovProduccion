import { LightningElement, api } from 'lwc';
import getResumenVarietal from '@salesforce/apex/CuentaGranaria.getResumenVarietal';
import getDetalleVarietal from '@salesforce/apex/CuentaGranaria.getDetalleVarietal';
import getEntregasVarietal from '@salesforce/apex/CuentaGranaria.getEntregasVarietal';
import { doRequest, errorEvent } from 'c/utils';
import { trackGa4Event } from 'c/portalGa4Events';
import { ensureXlsxLoaded, downloadVentasWorkbook, downloadVentasWorkbookSheets } from 'c/ventasInformadasExcelUtil';
import icons from 'c/icons';

const ENTREGAS_HEADERS = ['Fecha', 'Marca', 'Variedad', 'CTG', 'Kg netos', 'Toneladas'];
const MOVIMIENTO_HEADERS = ['Fecha', 'Origen', 'HT', 'Toneladas'];
const MOVIMIENTO_ENTREGAS_HEADERS = ['Fecha', 'CTG', 'Kg netos', '% de la variedad', 'Toneladas'];

const ESTADOS = ['Debe regularizar', 'En regla', 'Sin entregas'];
const ESTADO_LABEL = {
    'Debe regularizar': 'Entregaste de más',
    'En regla': 'Podés seguir entregando',
    'Sin entregas': 'Listo para entregar'
};
const ESTADOS_GA4 = {
    todas: 'todas',
    'Debe regularizar': 'debe_regularizar',
    'En regla': 'en_regla',
    'Sin entregas': 'sin_entregas'
};

function etiquetaVariedad(variedad) {
    return ESTADO_LABEL[variedad?.estado] || variedad?.estado || '';
}

function etiquetaGrupo() {
    return ESTADO_LABEL['Debe regularizar'];
}

function fraseNegativas(variedades) {
    const lista = (variedades || [])
        .filter((variedad) => variedad && variedad.estado === 'Debe regularizar')
        .slice()
        .sort((a, b) => {
            const saldo = (Number(a.saldo) || 0) - (Number(b.saldo) || 0);
            if (saldo !== 0) return saldo;
            return String(a.nombre || '').localeCompare(String(b.nombre || ''), 'es');
        });
    if (!lista.length) return '';
    const n = lista.length;
    const cuantas = n === 1 ? '1 variedad' : `${n} variedades`;
    const nombres = lista.map((variedad) => variedad.nombre).filter(Boolean).join(' · ');
    return `Entregaste más toneladas de las que compraste en ${cuantas}: ${nombres}`;
}

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
    @api esPph = false;
    @api cifraCampana = 0;
    @api cifraCompletar = false;
    @api nombresCompletar = '';
    @api cantidadCompletar = 0;
    @api pphRibbonUrl;

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
    filtroEstado = 'todas';

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
                this.filtroEstado = 'todas';
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
            this.cerrarDetalle({ desdeHistorial: true });
        }
        if (this.leerParametro('vista') === 'variedades') {
            this.abrirVariedades({ desdeHistorial: true });
            this.restaurarScroll('variedades');
            return;
        }
        if (this.vistaMovil) {
            this.cerrarVariedades({ desdeHistorial: true });
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
                this.aplicarVistaUrl();
                this.escribirUrl();
            }
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
        return false;
    }

    get heroCrop() {
        return this.campaniaLabel ? `TRIGO · ${this.campaniaLabel}` : 'TRIGO';
    }

    get mostrarCifras() {
        return !this.esPph;
    }

    get mostrarFiltroEstado() {
        return !this.esPph && this.elegidas.length > 0;
    }

    get muestraNombresCompletar() {
        if (this.esPph) return false;
        if (this.negativasCampana.some((variedad) => variedad.nombre)) return true;
        return this.cifraCompletar && !!this.nombresCompletar;
    }

    get cifraHeroClass() {
        return 'cgv-camp-fig' + (this.negativasCampana.length ? ' is-neg' : '');
    }

    get unidadHeroClass() {
        return 'cgv-camp-unit' + (this.negativasCampana.length ? ' is-neg' : '');
    }

    get cifraHeroTexto() {
        const numero = Math.round(Number(this.cifraCampana) || 0);
        if (this.negativasCampana.length) {
            return this.formatoAcreditado(-Math.abs(numero));
        }
        return this.formatoAcreditado(numero);
    }

    get unidadHero() {
        if (!this.negativasCampana.length) return 'Podés seguir entregando';
        return etiquetaGrupo();
    }

    get textoHeroNombres() {
        const negativas = this.negativasCampana;
        if (negativas.length) return fraseNegativas(negativas);
        const n = Number(this.cantidadCompletar) || 0;
        const cuantas = n === 1 ? '1 variedad' : `${n} variedades`;
        return `Entregaste más toneladas de las que compraste en ${cuantas}: ${this.nombresCompletar}`;
    }

    get rootClass() {
        return 'cgv-root' + (this.vistaMovil ? ' is-variedades' : '');
    }

    get marcas() {
        return (this.resumen && this.resumen.marcas) || [];
    }

    get negativasCampana() {
        return this.marcas
            .reduce((lista, marca) => lista.concat(marca.variedades || []), [])
            .filter((variedad) => variedad.estado === 'Debe regularizar');
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
        if (!fecha) {
            return `${textoVariedades} en ${textoMarcas}`;
        }
        return `${textoVariedades} en ${textoMarcas} · Última entrega informada ${this.fecha(fecha)}`;
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
        const total = this.variedadesElegidas.length;
        const items = [
            { estado: 'todas', conteo: total, label: `Todas ${total}` },
            ...ESTADOS.map((estado) => ({
                estado,
                conteo: conteos[estado] || 0,
                label: estado === 'Debe regularizar'
                    ? `${etiquetaGrupo()} ${conteos[estado] || 0}`
                    : `${ESTADO_LABEL[estado]} ${conteos[estado] || 0}`
            }))
        ];
        return items.map((item) => {
            const disabled = item.estado !== 'todas' && item.conteo === 0;
            const activa = this.filtroEstado === item.estado && !disabled;
            return {
                ...item,
                disabled,
                pressed: activa ? 'true' : 'false',
                cssClass: 'cgv-pill' + (activa ? ' is-on' : '') + (disabled ? ' is-off' : '')
            };
        });
    }

    get tituloVariedades() {
        return this.esPph ? 'Variedades respaldadas por PPH' : 'Variedades de las marcas elegidas';
    }

    get tituloVariedadesCorto() {
        return this.esPph ? 'Variedades respaldadas por PPH' : 'Variedades';
    }

    get encabezadoVariedades() {
        const marcas = this.marcasElegidas.length;
        const variedades = this.variedadesElegidas.length;
        const completar = this.conteos['Debe regularizar'] || 0;
        const textoMarcas = marcas === 1 ? '1 marca' : `${marcas} marcas`;
        const textoVariedades = variedades === 1 ? '1 variedad' : `${variedades} variedades`;
        if (this.esPph) {
            return `${textoMarcas} · ${textoVariedades}`;
        }
        const etiqueta = etiquetaGrupo().toLowerCase();
        const textoEstado = completar === 1 ? `1 ${etiqueta}` : `${completar} ${etiqueta}`;
        return `${textoMarcas} · ${textoVariedades} · ${textoEstado}`;
    }

    get grupos() {
        const filtro = this.filtroEstado;
        return this.marcasElegidas
            .map((marca) => {
                const variedades = (marca.variedades || [])
                    .filter((variedad) => filtro === 'todas' || variedad.estado === filtro)
                    .map((variedad) => this.decorarVariedad(variedad));
                const decorada = this.decorarMarca(marca);
                return {
                    ...decorada,
                    variedades,
                    vacio: variedades.length === 0,
                    keyDesk: `d-${marca.id}`,
                    keyMovil: `m-${marca.id}`
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
            estadoLabel: this.esPph ? 'Respaldada por PPH' : etiquetaVariedad(this.detalle),
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
            totalDebitosTexto: this.formatoFirmado(-this.totalDebitosNoEntrega(this.detalle)),
            totalDebitadoTexto: this.formatoFirmado(-(Number(this.detalle.totalDebitado) || 0)),
            sinCreditos: !(this.detalle.creditos || []).length,
            sinDebitos: !(this.detalle.debitos || []).length,
            sinEntregas: !(this.detalle.entregas || []).length
        };
    }

    decorarMovimientosCredito(movimientos, prefijo) {
        return (movimientos || []).map((mov, index) => {
            const tn = Number(mov.toneladas) || 0;
            const htTexto = this.formatoHt(mov.ht);
            return {
                ...mov,
                key: `${prefijo}-${index}`,
                fechaTexto: this.fecha(mov.fecha),
                htTexto,
                metaTexto: this.unirMeta([this.fecha(mov.fecha), htTexto ? `${htTexto} HT` : '']),
                toneladasTexto: this.formatoFirmado(tn),
                toneladasClass: 'cgv-r cgv-strong' + (tn < 0 ? ' is-neg' : tn > 0 ? ' is-pos' : ''),
                montoClass: 'cgv-mov-amt' + (tn < 0 ? ' is-neg' : tn > 0 ? ' is-pos' : '')
            };
        });
    }

    notaRegularizar(detalle) {
        const nombre = detalle?.variedad || 'esta variedad';
        return `Entregaste más grano de ${nombre} que el crédito que tenés.`;
    }

    totalDebitosNoEntrega(detalle) {
        return (detalle?.debitos || []).reduce((suma, mov) => suma + Math.abs(Number(mov.toneladas) || 0), 0);
    }

    decorarMarca(marca) {
        const variedades = marca.variedades || [];
        const negativas = variedades.filter((variedad) => variedad.estado === 'Debe regularizar').length;
        const positivas = variedades.filter((variedad) => variedad.estado === 'En regla').length;
        const elegida = this.elegidas.includes(marca.id);
        const total = variedades.length;
        const textoVariedades = total === 1 ? '1 variedad' : `${total} variedades`;
        let etiqueta = '';
        if (!this.esPph && total > 0) {
            if (negativas > 0) {
                etiqueta = `${negativas} de ${total} · ${etiquetaGrupo()}`;
            } else if (positivas > 0) {
                etiqueta = `${positivas} de ${total} · Podés seguir entregando`;
            } else {
                etiqueta = `${total} de ${total} · Listo para entregar`;
            }
        }
        const chipClass = this.esPph
            ? 'cgv-chip is-ok'
            : negativas > 0
                ? 'cgv-chip is-warn'
                : positivas > 0
                    ? 'cgv-chip is-ok'
                    : 'cgv-chip is-ready';
        const subtitulo = textoVariedades;
        return {
            ...marca,
            elegida,
            ariaChecked: elegida ? 'true' : 'false',
            cssClass: 'cgv-marca' + (elegida ? ' is-on' : ''),
            chipClass,
            chipDeskClass: chipClass + ' cgv-solo-desk',
            chipMovilClass: chipClass + ' cgv-solo-movil',
            etiqueta,
            etiquetaCorta: etiqueta,
            iniciales: this.iniciales(marca.nombre),
            logo: this.logo(marca.idObtentor),
            logoClass: 'cgv-logo' + (this.logo(marca.idObtentor) ? ' has-logo' : ''),
            textoVariedades,
            subtitulo,
            puedeRegularizar: false
        };
    }

    decorarVariedad(variedad) {
        const saldo = Number(variedad.saldo) || 0;
        return {
            ...variedad,
            estadoLabel: this.esPph ? 'Respaldada por PPH' : etiquetaVariedad(variedad),
            chipClass: this.esPph ? 'cgv-chip is-ok' : this.chipClass(variedad.estado),
            creditoTexto: this.formatoAcreditado(variedad.credito),
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
        return 'cgv-chip is-ready';
    }

    formato(value) {
        const numero = Math.round(Number(value) || 0);
        return new Intl.NumberFormat('es-AR', { maximumFractionDigits: 0 }).format(Math.abs(numero));
    }

    formatoAcreditado(value) {
        const numero = Math.round(Number(value) || 0);
        const texto = this.formato(numero);
        if (numero < 0) return `−${texto} t`;
        return `${texto} t`;
    }

    formatoHt(value) {
        const numero = Number(value);
        if (!Number.isFinite(numero) || numero === 0) return '';
        const texto = new Intl.NumberFormat('es-AR', { maximumFractionDigits: 2 }).format(Math.abs(numero));
        return numero < 0 ? `−${texto}` : texto;
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
        return false;
    }

    aplicarVistaUrl() {
        if (this.leerParametro('vista') !== 'variedades' || !this.elegidas.length) return;
        this.abrirVariedades({ desdeHistorial: true });
    }

    abrirVariedades({ desdeHistorial } = {}) {
        if (this.vistaMovil) return;
        this.vistaMovil = true;
        this._variedadesEmpujadas = !desdeHistorial;
        this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'variedades' } }));
    }

    cerrarVariedades({ desdeHistorial } = {}) {
        this.vistaMovil = false;
        this._variedadesEmpujadas = false;
        this.dispatchEvent(new CustomEvent('vistachange', { detail: { vista: 'marcas' } }));
        if (!desdeHistorial) this.escribirUrl();
    }

    cerrarDetalle({ desdeHistorial } = {}) {
        this.detalle = null;
        this._detalleMarcaId = null;
        this._detalleEmpujado = false;
        this.avisarDetalle(false);
        if (!desdeHistorial) this.escribirUrl();
    }

    subirConHistorial(empujado, cerrar) {
        if (empujado) {
            try {
                window.history.back();
                return;
            } catch (e) {
                // Si el history no está disponible, cierra la vista en memoria.
            }
        }
        cerrar();
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
            if (!this.detalle && this.vistaMovil) {
                url.searchParams.set('vista', 'variedades');
            } else {
                url.searchParams.delete('vista');
            }
            const href = `${url.pathname}${url.search}${url.hash}`;
            const actual = `${window.location.pathname}${window.location.search}${window.location.hash}`;
            if (href === actual) return;
            if (empujar) {
                window.history.pushState(window.history.state, '', href);
            } else {
                window.history.replaceState(window.history.state, '', href);
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
        if (!opciones.empujar) return;
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
        if (!estado || estado === this.filtroEstado) return;
        this.filtroEstado = estado;
        trackGa4Event('cuenta_granaria_filtro_estado', {
            ...this.paramsGa4(),
            estado: ESTADOS_GA4[estado] || estado,
            accion: 'mostrar'
        });
    }

    handleMostrarTodas() {
        this.filtroEstado = 'todas';
        trackGa4Event('cuenta_granaria_filtro_estado', {
            ...this.paramsGa4(),
            estado: 'todas',
            accion: 'mostrar_todas'
        });
    }

    handleVerVariedades() {
        if (!this.elegidas.length) return;
        this.guardarScroll('marcas');
        const yaAbierta = this.vistaMovil;
        this.abrirVariedades();
        if (!yaAbierta && this._variedadesEmpujadas) {
            this.escribirUrl({ empujar: true });
        } else {
            this.escribirUrl();
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
        this.trackVariedadesGa4();
    }

    handleVolverMarcas() {
        this.subirConHistorial(this._variedadesEmpujadas, () => {
            this.cerrarVariedades();
            this.restaurarScroll('marcas');
        });
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
        this.subirConHistorial(this._detalleEmpujado, () => {
            this.cerrarDetalle();
            this.restaurarScroll(this.vistaMovil ? 'variedades' : 'marcas');
        });
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
                Fecha: this.fechaExcel(mov.fecha),
                Marca: mov.marca || '',
                Variedad: mov.variedad || '',
                CTG: mov.ctg || '',
                'Kg netos': mov.kgNetos == null ? '' : Number(mov.kgNetos),
                Toneladas: mov.toneladas == null ? '' : Number(mov.toneladas)
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
        doRequest.call(this, async () => {
            await ensureXlsxLoaded(this);
            const hojas = [];
            const creditos = (vista.creditos || []).map((mov) => this.filaMovimientoExcel(mov));
            const debitos = (vista.debitos || []).map((mov) => this.filaMovimientoExcel(mov));
            const entregas = (vista.entregas || []).map((mov) => ({
                Fecha: this.fechaExcel(mov.fecha),
                CTG: mov.ctg || '',
                'Kg netos': mov.kgNetos == null ? '' : Number(mov.kgNetos),
                '% de la variedad': this.porcentajeEntrega(mov),
                Toneladas: mov.toneladas == null ? '' : Number(mov.toneladas)
            }));
            if (creditos.length) {
                hojas.push({ name: 'Créditos', headers: MOVIMIENTO_HEADERS, rows: creditos });
            }
            if (debitos.length) {
                hojas.push({ name: 'Débitos', headers: MOVIMIENTO_HEADERS, rows: debitos });
            }
            if (entregas.length) {
                hojas.push({ name: 'Entregas', headers: MOVIMIENTO_ENTREGAS_HEADERS, rows: entregas });
            }
            if (!hojas.length) return;
            const nombre = (vista.variedad || 'variedad').toLowerCase().replace(/\s+/g, '_');
            downloadVentasWorkbookSheets(`movimientos_${nombre}.xlsx`, hojas);
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
        });
    }

    filaMovimientoExcel(mov) {
        return {
            Fecha: this.fechaExcel(mov.fecha),
            Origen: mov.origen || '',
            HT: mov.ht == null || mov.ht === '' ? '' : Number(mov.ht),
            Toneladas: mov.toneladas == null || mov.toneladas === '' ? '' : Number(mov.toneladas)
        };
    }

    fechaExcel(value) {
        if (!value) return '';
        if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
        const partes = String(value).slice(0, 10).split('-');
        if (partes.length < 3) return value;
        const anio = Number(partes[0]);
        const mes = Number(partes[1]);
        const dia = Number(partes[2]);
        if (!anio || !mes || !dia) return value;
        return new Date(anio, mes - 1, dia);
    }

    paramsGa4() {
        return { cultivo: 'TRIGO', campaña: this.campaniaLabel };
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

}
