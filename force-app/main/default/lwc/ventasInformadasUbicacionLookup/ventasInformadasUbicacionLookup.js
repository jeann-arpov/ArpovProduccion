import { LightningElement, api } from 'lwc';
import getLocalidadesDestinoParaLookup from '@salesforce/apex/VentasInformadasDestinoGeoService.getLocalidadesDestinoParaLookup';

export default class VentasInformadasUbicacionLookup extends LightningElement {
    @api ventaId;
    /** 'provincia' | 'localidad' */
    @api fieldType;
    @api editable = false;
    @api saving = false;
    @api provinciaId;
    @api provinciaOptions = [];

    _selectedId;
    _displayLabel = '';

    displayValue = '';
    dropdownOpen = false;
    filteredOptions = [];
    searchLoading = false;
    _searchTimeout;
    _searchSeq = 0;

    @api
    get selectedId() {
        return this._selectedId;
    }
    set selectedId(value) {
        this._selectedId = value || null;
        if (!this.dropdownOpen) {
            this.displayValue = this._displayLabel || '';
        }
    }

    @api
    get displayLabel() {
        return this._displayLabel;
    }
    set displayLabel(value) {
        this._displayLabel = value || '';
        if (!this.dropdownOpen) {
            this.displayValue = this._displayLabel;
        }
    }

    get cellClass() {
        return this.saving ? 'ubicacion-lookup-cell ubicacion-saving' : 'ubicacion-lookup-cell';
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.dropdownOpen ? 'slds-is-open' : ''
        }`;
    }

    get isProvincia() {
        return this.fieldType === 'provincia';
    }

    get isLocalidad() {
        return this.fieldType === 'localidad';
    }

    get inputDisabled() {
        return this.saving || (this.isLocalidad && !this.provinciaId);
    }

    get inputPlaceholder() {
        if (this.isLocalidad && !this.provinciaId) {
            return 'Elegí provincia';
        }
        return 'Buscar...';
    }

    get hasOptions() {
        return this.filteredOptions && this.filteredOptions.length > 0;
    }

    get emptyMessage() {
        if (this.searchLoading) {
            return 'Cargando...';
        }
        if (this.isLocalidad && !this.provinciaId) {
            return 'Seleccioná provincia primero';
        }
        return 'Sin resultados';
    }

    get readonlyDisplay() {
        return this._displayLabel || '—';
    }

    handleInput(event) {
        const searchTerm = event.target.value;
        this.displayValue = searchTerm;
        this.dropdownOpen = true;

        if (this.isProvincia) {
            this.handleProvinciaInput(searchTerm);
        } else {
            this.handleLocalidadInput(searchTerm);
        }
    }

    handleProvinciaInput(searchTerm) {
        if (!searchTerm.trim()) {
            this._selectedId = null;
            this._displayLabel = '';
            this.filteredOptions = this.mapProvinciaOptions('');
            this.fireChange(null, '');
            return;
        }

        if (this._selectedId) {
            const selected = (this.provinciaOptions || []).find((opt) => opt.value === this._selectedId);
            if (selected && searchTerm !== selected.label) {
                this._selectedId = null;
            }
        }

        this.filteredOptions = this.mapProvinciaOptions(searchTerm);
    }

    handleLocalidadInput(searchTerm) {
        if (!this.provinciaId) {
            return;
        }
        this._selectedId = null;
        this.scheduleLocalidadSearch(searchTerm);
    }

    handleFocus() {
        if (this.inputDisabled) {
            return;
        }
        this.dropdownOpen = true;
        if (this.isProvincia) {
            this.filteredOptions = this.mapProvinciaOptions(this.displayValue);
        } else {
            this.scheduleLocalidadSearch(this.displayValue);
        }
    }

    handleBlur() {
        window.setTimeout(() => {
            const active = this.template.activeElement;
            const container = this.template.querySelector('[data-id="ubicacion-combobox"]');
            if (container && active && container.contains(active)) {
                return;
            }
            this.dropdownOpen = false;
            this.displayValue = this._displayLabel || '';
        }, 200);
    }

    handleDropdownMouseDown(event) {
        event.preventDefault();
    }

    handleSelect(event) {
        event.preventDefault();
        const selectedId = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;

        this._selectedId = selectedId;
        this._displayLabel = selectedLabel;
        this.displayValue = selectedLabel;
        this.dropdownOpen = false;
        this.filteredOptions = [];

        this.fireChange(selectedId, selectedLabel);
    }

    fireChange(selectedId, selectedLabel) {
        this.dispatchEvent(
            new CustomEvent('lookupchange', {
                bubbles: true,
                composed: true,
                detail: {
                    ventaId: this.ventaId,
                    fieldType: this.fieldType,
                    selectedId: selectedId || null,
                    selectedLabel: selectedLabel || ''
                }
            })
        );
    }

    mapProvinciaOptions(searchTerm) {
        const term = (searchTerm || '').trim().toLowerCase();
        const filtered = (this.provinciaOptions || []).filter((opt) => {
            if (!term) {
                return true;
            }
            return opt.label.toLowerCase().includes(term);
        });
        const options = this.deduplicateOptionsByLabel(filtered);

        return options.map((opt) => ({
            ...opt,
            itemClass:
                opt.value === this._selectedId
                    ? 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-is-selected'
                    : 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
        }));
    }

    scheduleLocalidadSearch(searchTerm) {
        if (this._searchTimeout) {
            clearTimeout(this._searchTimeout);
        }
        if (!this.provinciaId) {
            this.filteredOptions = [];
            this.searchLoading = false;
            return;
        }

        const term = (searchTerm || '').trim();
        const delay = term ? 300 : 0;
        this.searchLoading = true;

        this._searchTimeout = window.setTimeout(() => {
            this._searchTimeout = null;
            this.searchLocalidades(term);
        }, delay);
    }

    async searchLocalidades(searchTerm) {
        if (!this.provinciaId) {
            this.filteredOptions = [];
            this.searchLoading = false;
            return;
        }

        const requestId = ++this._searchSeq;
        this.searchLoading = true;

        try {
            const data = await getLocalidadesDestinoParaLookup({
                provinciaId: this.provinciaId,
                searchTerm: searchTerm || ''
            });
            if (requestId !== this._searchSeq) {
                return;
            }
            const deduped = this.deduplicateOptionsByLabel(
                (data || []).map((item) => ({
                    label: item.title,
                    value: item.id
                }))
            );
            this.filteredOptions = deduped.map((item) => ({
                label: item.label,
                value: item.value,
                itemClass:
                    item.value === this._selectedId
                        ? 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-is-selected'
                        : 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
            }));
        } catch (error) {
            if (requestId === this._searchSeq) {
                console.error('Error buscando localidades:', error);
                this.filteredOptions = [];
            }
        } finally {
            if (requestId === this._searchSeq) {
                this.searchLoading = false;
            }
        }
    }

    deduplicateOptionsByLabel(options) {
        const seen = new Set();
        const unique = [];
        (options || []).forEach((opt) => {
            if (!opt?.label || !opt?.value) {
                return;
            }
            const key = opt.label.trim().toLowerCase().replace(/\s+/g, ' ');
            if (!key || seen.has(key)) {
                return;
            }
            seen.add(key);
            unique.push(opt);
        });
        return unique;
    }
}
