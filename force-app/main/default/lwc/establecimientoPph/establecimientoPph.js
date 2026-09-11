import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import searchEstablecimientos from '@salesforce/apex/AdhesionPPH.searchEstablecimientos';
import icons from 'c/icons';
import { errorEvent } from 'c/utils';

export default class EstablecimientoPph extends NavigationMixin(LightningElement) {
    @api info;
    @api hiding;
    @api cultivo;
    @api grandesCuentas;
    @api variant = 'legacy';
    /** wizard: 'establecimiento' | 'superficie' | 'full' (default full = ambos bloques) */
    @api wizardPhase = 'full';
    /** Saldo HT total del cultivo (opcional; si no viene se estima desde lineas). */
    @api saldoHt;

    name = "";
    cantidadNoSE;
    cantidadSE;
    longitude;
    latitude;
    collapsed = false;
    establecimiento;

    icons = icons.pph;

    init() {
        this.initialized = true;

        this.cantidadNoSE = this.info.record.Cantidad_Variedad_No_SE__c;
        this.cantidadSE =
            this.info.cantidadSE != null
                ? this.info.cantidadSE
                : (this.info.lineas || []).reduce(
                      (sum, l) => sum + (Number(l.record?.Cantidad_Declarada__c) || 0),
                      0
                  );

        if (this.info.record.Establecimiento__r) {
            this.establecimiento = {
                ...this.info.record.Establecimiento__r,
                title: this.info.record.Name,
                id: this.info.record.Establecimiento__r.Id,
                icon: 'standard:address'
            };
        }
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    get titulo() {
        return "Establecimiento " + (this.establecimiento?.Name || (this.name ? " - " + this.name : ""));
    }

    get isWizardVariant() {
        return this.variant === 'wizard';
    }

    get showWizardEstablecimientoBlock() {
        if (!this.isWizardVariant) return true;
        return this.wizardPhase !== 'superficie';
    }

    /** Nunca mostrar el header legacy ESTABLECIMIENTO en el wizard rediseñado. */
    get showWizardLegacyHead() {
        return false;
    }

    get showWizardNameChip() {
        if (!(this.isWizardVariant && this.wizardPhase === 'superficie')) return false;
        const nombre =
            this.establecimiento?.Name ||
            this.establecimiento?.title ||
            this.name ||
            this.info?.record?.Establecimiento__r?.Name ||
            this.info?.record?.Name;
        return !!nombre;
    }

    get showWizardEstablecimientoBody() {
        // La selección se hace con el checklist del padre.
        return false;
    }

    get showWizardSuperficieOnlyHead() {
        return false;
    }

    get showWizardSuperficieBlock() {
        if (!this.isWizardVariant) return true;
        return this.wizardPhase !== 'establecimiento';
    }

    get showWizardToggle() {
        return this.isWizardVariant && this.wizardPhase === 'full' && !this.grandesCuentas;
    }

    get collapsedLabel() {
        return this.collapsed ? 'Expandir establecimiento' : 'Colapsar establecimiento';
    }

    get superficieEyebrow() {
        return 'Establecimiento';
    }

    get superficieTitle() {
        const nombre =
            this.establecimiento?.Name ||
            this.establecimiento?.title ||
            this.name ||
            this.info?.record?.Name ||
            this.info?.record?.Establecimiento__r?.Name ||
            '';
        return nombre || 'Establecimiento';
    }

    get hasVariedades() {
        return (this.info?.lineas || []).length > 0;
    }

    get saldoHtCultivo() {
        if (this.saldoHt != null && this.saldoHt !== undefined) {
            return Number(this.saldoHt) || 0;
        }
        return (this.info?.lineas || []).reduce(
            (sum, l) => sum + (Number(l.variedad?.totals?.total) || 0),
            0
        );
    }

    get hasSaldoHt() {
        return this.saldoHtCultivo > 0 || this.safeCantidadSE > 0;
    }

    get maxCantidadSe() {
        return Math.max(Number(this.saldoHtCultivo) || 0, 0);
    }

    get safeCantidadSE() {
        return Number(this.cantidadSE) || 0;
    }

    get superficieSeHint() {
        const saldo = new Intl.NumberFormat('es-AR').format(this.saldoHtCultivo || 0);
        return `HT disponibles del cultivo: ${saldo}. Si te faltan, usá Comprar HT arriba.`;
    }

    get seInput() {
        return this.template.querySelector('.se-se-input');
    }

    get overSaldoSeMessage() {
        const saldo = new Intl.NumberFormat('es-AR').format(this.maxCantidadSe);
        return `No puede superar las ${saldo} HT disponibles del cultivo`;
    }

    /** Marca / limpia error inline del input SE (también usable desde el padre). */
    @api
    setSuperficieSeError(message) {
        const input = this.seInput;
        if (!input) return;
        input.setCustomValidity(message || '');
        if (message) input.reportValidity();
    }

    @api
    applySeFieldValidity() {
        if (!this.isWizardVariant) return true;
        const input = this.seInput;
        if (!input) return true;
        if (this.safeCantidadSE > this.maxCantidadSe) {
            input.setCustomValidity(this.overSaldoSeMessage);
            return false;
        }
        input.setCustomValidity('');
        return true;
    }

    @api
    reportSeValidity() {
        this.seInput?.reportValidity();
    }

    @api
    validateSelection() {
        if (this.grandesCuentas) return true;
        if (this.establecimiento) return true;
        if (this.name?.trim() && this.latitude !== undefined && this.longitude !== undefined) {
            return true;
        }
        return false;
    }

    updateName(event) {
        this.name = event.target.value;
    }

    updateCantidad(event) {
        this.dispatchEvent(new CustomEvent('updatecantidad', { detail: event.detail }));
    }

    updateCantidadSe(event) {
        const prev = this.safeCantidadSE;
        const raw = event.detail?.value ?? event.target?.value;
        const parsed = raw === '' || raw == null ? 0 : Number(raw);
        const next = Number.isFinite(parsed) ? parsed : 0;
        this.cantidadSE = next;
        this.applySeFieldValidity();
        this.seInput?.reportValidity();
        this.dispatchEvent(
            new CustomEvent('updatecantidadse', {
                detail: { previous: prev, cantidad: next, delta: next - prev }
            })
        );
    }

    updateCantidadFuera(event) {
        const raw = event.detail?.value ?? event.target?.value;
        const parsed = raw === '' || raw == null ? 0 : Number(raw);
        this.cantidadNoSE = Number.isFinite(parsed) ? parsed : 0;
        this.dispatchEvent(
            new CustomEvent('updatecantidadnose', {
                detail: { cantidad: this.cantidadNoSE }
            })
        );
    }

    showMap(event) {
        event?.preventDefault?.();
        this.dispatchEvent(new CustomEvent('showmap', { detail: { callback: this.updateLocation.bind(this) } }));
    }

    updateLocation(data, map) {
        map.hide();
        if (this.validateCoordinates(data.longitude, data.latitude)) {
            this.longitude = data.longitude;
            this.latitude = data.latitude;
            const coordinates = this.template.querySelector('.coordinates');
            if (coordinates) {
                coordinates.value = this.mapCoodinates;
                coordinates.setCustomValidity('');
                coordinates.reportValidity();
            }
            this.autosave();
        } else {
            this.dispatchEvent(errorEvent(new Error('Las coordenadas deben ser negativas')));
        }
    }

    validateCoordinates(longitude, latitude) {
        return Math.sign(longitude) === -1 && Math.sign(latitude) === -1;
    }

    changeCollapsed() {
        this.collapsed = !this.collapsed;
    }

    remove() {
        this.dispatchEvent(new CustomEvent('remove'));
    }

    get safeCantidadNoSE() {
        return this.cantidadNoSE || 0;
    }

    get totalSuperficieSe() {
        if (this.isWizardVariant) {
            return this.safeCantidadSE;
        }
        try {
            return (this.variedadesPPH || [])
                .map((e) => Number(e.getData()?.cantidad) || 0)
                .reduce((a, b) => a + b, 0);
        } catch (e) {
            return 0;
        }
    }

    get totalSembrado() {
        return this.safeCantidadNoSE + this.totalSuperficieSe;
    }

    get totalSembradoLabel() {
        return `${new Intl.NumberFormat('es-AR').format(this.totalSuperficieSe || 0)} ha`;
    }

    get cantidadNoSeLabel() {
        return `${new Intl.NumberFormat('es-AR').format(this.safeCantidadNoSE || 0)} ha`;
    }

    get mapCoodinates() {
        if (this.latitude !== undefined) return this.latitude.toFixed(2) + ', ' + this.longitude.toFixed(2);
        return 'Seleccionar Punto de lote';
    }

    get coordinatesClass() {
        return 'coordinates' + (this.latitude !== undefined ? '' : ' black');
    }

    get disabled() {
        return (
            this.grandesCuentas === false &&
            !this.establecimiento &&
            (this.name.trim() === '' || this.longitude === undefined || this.latitude === undefined)
        );
    }

    get infoClass() {
        let cls = this.isWizardVariant ? 'se-est-info' : 'info';
        if (this.collapsed) cls += ' collapsed';
        if (this.disabled) cls += ' disabled';
        return cls;
    }

    @api
    validate() {
        let valid = true;

        if (this.grandesCuentas === false && !this.establecimiento && this.mapCoodinates.startsWith('Selec')) {
            const coordinates = this.template.querySelector('.coordinates');
            if (coordinates) coordinates.setCustomValidity('Este campo es obligatorio');
        }

        let total = 0;

        if (this.isWizardVariant) {
            total = this.safeCantidadSE;
            if (!this.applySeFieldValidity()) {
                valid = false;
            }
        } else {
            for (const element of this.template.querySelectorAll('c-variedad-pph')) {
                if (!element.validate()) valid = false;
                total += element.getData().cantidad;
            }
        }

        for (const element of this.template.querySelectorAll('lightning-input')) {
            if (!element.reportValidity()) valid = false;
        }

        if (valid && total + this.safeCantidadNoSE === 0) {
            throw this.isWizardVariant
                ? 'Debe ingresarse superficie SE o hectáreas fuera de SE para poder avanzar'
                : 'Debe ingresarse cantidad distinto a 0 en al menos una variedad para poder avanzar';
        }

        return valid;
    }

    get variedadesPPH() {
        return Array.from(this.template.querySelectorAll('c-variedad-pph'));
    }

    @api
    getData() {
        if (this.isWizardVariant) {
            return {
                id: this.establecimiento?.Id,
                latitude: this.establecimiento?.Coordenadas__Latitude__s || this.latitude,
                longitude: this.establecimiento?.Coordenadas__Longitude__s || this.longitude,
                cantidadNoSE: this.safeCantidadNoSE,
                cantidadSE: this.safeCantidadSE,
                name: this.establecimiento?.Name || this.name,
                lineasMeta: (this.info?.lineas || []).map((l) => ({
                    variedadId: l.id,
                    lineaId: l.record?.Id || null,
                    stock: Number(l.variedad?.totals?.total) || 0,
                    variedad: l.variedad
                })),
                variedades: {}
            };
        }

        const variedades = Object.fromEntries(
            this.variedadesPPH
                .filter((v) => v.cantidad > 0 || v.info.record.Id)
                .map((v) => [v.info.id, v.getData()])
        );
        return {
            id: this.establecimiento?.Id,
            latitude: this.establecimiento?.Coordenadas__Latitude__s || this.latitude,
            longitude: this.establecimiento?.Coordenadas__Longitude__s || this.longitude,
            cantidadNoSE: this.safeCantidadNoSE,
            name: this.establecimiento?.Name || this.name,
            variedades
        };
    }

    redirectCompraHT() {
        this[NavigationMixin.GenerateUrl]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'FormularioNuevaVentaHT'
            }
        }).then((url) => window.open(url, '_blank'));
    }

    get establecimientoClass() {
        return 'establecimiento' + (this.hiding[this.info.id] ? ' slds-hide' : '');
    }

    autosave() {
        this.dispatchEvent(new CustomEvent('autosave'));
    }

    blur(e) {
        // lightning-input: value puede ser number; dataset siempre string
        const prev = String(e.target.dataset.val ?? '');
        const next = String(e.target.value ?? '');
        if (prev !== next) {
            this.autosave();
        }
    }

    focus(e) {
        e.target.dataset.val = String(e.target.value ?? '');
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    establecimientoSelected(event) {
        const selection = event.target.getSelection();
        this.establecimiento = selection.length
            ? { ...selection[0].record, title: selection[0].record.Name, icon: 'standard:address' }
            : null;

        if (this.establecimiento === null && this.info.record.Id) {
            this.dispatchEvent(new CustomEvent('establecimientochange'));
        }
    }

    async search(event) {
        const lookup = event.target;
        await searchEstablecimientos({ searchTerm: event.detail.searchTerm })
            .then((res) => lookup.setSearchResults(res))
            .catch((e) => this.onError(e));
    }

    get totalesSembradasLabel() {
        return `Hectáreas TOTALES de ${this.cultivo.Name} Sembradas`;
    }

    get superficieBannerTitle() {
        return 'Superficie a precertificar (ha)';
    }
}
