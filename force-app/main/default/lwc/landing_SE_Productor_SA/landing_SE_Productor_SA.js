import { LightningElement, track } from 'lwc';
import getLoadData from '@salesforce/apex/HomeMulticultivo.getLoadData';
import { NavigationMixin } from 'lightning/navigation';
import { trackGa4Event } from 'c/portalGa4Events';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

const NUMBER_FMT = new Intl.NumberFormat('es-AR', {
    maximumFractionDigits: 0
});

const ALL_SECTIONS = ['ht', 'pph', 'cg'];
const HOME_CANVAS_STYLE_ID = 'se-home-canvas-override';

const HOME_CANVAS_CSS = `
html.se-home,
body.se-home {
  background: #eef1f7 none !important;
  background-image: none !important;
  background-color: #eef1f7 !important;
  background-size: auto !important;
  background-attachment: scroll !important;
}
body.se-home #ServiceCommunityTemplate,
body.se-home .siteforceServiceBody,
body.se-home .cViewPanel,
body.se-home .cCenterPanel,
body.se-home [role="main"],
body.se-home .siteforceContentArea,
body.se-home .comm-page-content,
body.se-home .comm-content,
body.se-home .lwr-main,
body.se-home main,
body.se-home [data-region="content"],
body.se-home [data-region="main"],
body.se-home .forceCommunitySection,
body.se-home .cb-section,
body.se-home .cb-section_column,
body.se-home .cb-section_column > div,
body.se-home .slds-col,
body.se-home .themeLayout,
body.se-home .themeLayout-layout,
body.se-home .forceCommunityThemeHeroBase,
body.se-home .forceCommunityThemeHeroBase .uiImage,
body.se-home .themeBackgroundImage,
body.se-home .comm-page-home,
body.se-home .contentPanel,
body.se-home .contentRegion {
  background: #eef1f7 none !important;
  background-image: none !important;
  background-color: #eef1f7 !important;
  box-shadow: none !important;
  border: none !important;
}
body.se-home .cCenterPanel,
body.se-home .siteforceContentArea,
body.se-home .forceCommunitySection,
body.se-home .cb-section {
  border-radius: 0 !important;
  max-width: none !important;
  width: 100% !important;
  margin: 0 !important;
  float: none !important;
}
body.se-home .cCenterPanel::before,
body.se-home .cCenterPanel::after,
body.se-home .siteforceServiceBody::before,
body.se-home .siteforceServiceBody::after,
body.se-home .forceCommunityThemeHeroBase::before,
body.se-home .forceCommunityThemeHeroBase::after {
  display: none !important;
  content: none !important;
  background: none !important;
}
`;

export default class Landing_SE_Productor_SA extends NavigationMixin(LightningElement) {
    @track crops = [];
    @track filterOpen = false;
    @track selectedCultivoIds = [];
    @track selectedSections = [...ALL_SECTIONS];

    firstName = '';
    loading = true;
    iconSoja = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
    iconTrigo = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
    iconCebada = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;

    get homeContentClass() {
        return this.loading ? 'home-content is-loading' : 'home-content';
    }

    async connectedCallback() {
        document.documentElement.classList.add('se-home');
        document.body.classList.add('se-home');
        this.installHomeCanvas();

        try {
            const data = await getLoadData();
            const payload = JSON.parse(JSON.stringify(data || {}));
            this.firstName = payload.firstName || '';
            const list = Array.isArray(payload.cultivos) ? payload.cultivos : [];
            this.crops = list.map((t) => this.decorateCrop(t));
            this.selectedCultivoIds = this.crops.map((c) => c.id);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Error cargando home Productor', e);
        } finally {
            this.loading = false;
        }
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-home');
        document.body.classList.remove('se-home');
        const styleEl = document.getElementById(HOME_CANVAS_STYLE_ID);
        if (styleEl) styleEl.remove();
    }

    installHomeCanvas() {
        let styleEl = document.getElementById(HOME_CANVAS_STYLE_ID);
        if (!styleEl) {
            styleEl = document.createElement('style');
            styleEl.id = HOME_CANVAS_STYLE_ID;
            document.head.appendChild(styleEl);
        }
        styleEl.textContent = HOME_CANVAS_CSS;
    }

    decorateCrop(t) {
        const name = (t.cultivo?.Name || '').toUpperCase();
        const isComprar = t.version === 'comprar';
        const isAdherir = t.version === 'adherir';
        const isAdherido = t.version === 'adherido';
        const htAdq = Number(t.htAdquirida != null ? t.htAdquirida : t.htSinConsumir || 0);
        const needsCg = t.cgNeedsRegularizar === true;
        const hasFase = t.hasFase === true;
        const faseDias = t.faseDias;
        const faseUrgent = t.faseUrgent === true;

        let faseHitoFull = t.faseHito || '';
        if (faseDias != null && faseHitoFull) {
            faseHitoFull = `${faseHitoFull} · faltan ${faseDias} días`;
        }

        const period = t.pphPeriod || '';
        let pphDescription = 'Precertificar libera el tope de entrega por hectárea declarada.';
        if (t.pphInicioAdhesion && period) {
            pphDescription = `La adhesión a PPH para la campaña ${period} se habilita el ${t.pphInicioAdhesion}.`;
            if (t.pphFinAdhesion) {
                pphDescription += ` Vas a tener hasta el ${t.pphFinAdhesion} para adherir.`;
            }
        } else if (isAdherir) {
            pphDescription = period
                ? `Ya podés adherir a PPH para la campaña ${period}.`
                : 'Ya podés adherir a PPH.';
        }

        const pphHa = Number(t.pphHectareas || 0);
        const pphEst = Number(t.pphEstablecimientos || 0);

        return {
            id: t.cultivo.Id,
            name,
            paramId: t.paramId,
            iconUrl: this.iconFor(name),
            isComprar,
            isAdherir,
            isAdherido,
            hasFase,
            faseStripClass: 'home-phase' + (faseUrgent ? ' is-urgent' : ''),
            faseLabel: t.faseLabel || '',
            faseHitoFull,
            htAdquiridaLabel: `${NUMBER_FMT.format(htAdq)} HT`,
            buyLabel: 'Comprar HT →',
            buyNote: hasFase && (t.faseLabel || '').toLowerCase().includes('pre')
                ? 'Accedé a un precio diferencial en precampaña.'
                : 'Campaña abierta con precio diferencial.',
            pphStatus: isAdherido ? 'ADHERIDO' : 'SIN ADHERIR',
            pphStatusClass: 'home-pill' + (isAdherido ? ' is-lima' : ' is-gris'),
            pphCtaLabel: isAdherir ? 'Adherí a PPH →' : null,
            pphDescription,
            pphHaLabel: `${NUMBER_FMT.format(pphHa)} ha`,
            pphEstLabel: String(pphEst),
            cgNeedsRegularizar: needsCg,
            cgMsg: needsCg
                ? 'Tu Cuenta Granaria de campañas pasadas necesita regularizar toneladas.'
                : 'Tu Cuenta Granaria de campañas pasadas se encuentra en regla.',
            cgMsgClass: 'home-cg-msg' + (needsCg ? ' is-warn' : ' is-ok'),
            cgIconClass: 'home-cg-head-ic' + (needsCg ? ' is-warn' : ' is-ok'),
            showHt: true,
            showPph: true,
            showCg: true
        };
    }

    iconFor(name) {
        if (name.includes('TRIGO')) return this.iconTrigo;
        if (name.includes('CEBADA')) return this.iconCebada;
        return this.iconSoja;
    }

    get greeting() {
        return this.firstName ? `Hola, ${this.firstName}` : 'Hola';
    }

    get filterCount() {
        return this.selectedCultivoIds.length + 1;
    }

    get filterOptions() {
        return this.crops.map((c) => ({
            id: c.id,
            label: c.name.charAt(0) + c.name.slice(1).toLowerCase(),
            checked: this.selectedCultivoIds.includes(c.id)
        }));
    }

    get sectionOptions() {
        const labels = {
            ht: 'Hectárea Tecnológica',
            pph: 'PPH',
            cg: 'Cuenta Granaria'
        };
        return ALL_SECTIONS.map((id) => ({
            id,
            label: labels[id],
            checked: this.selectedSections.includes(id)
        }));
    }

    get visibleCrops() {
        const set = new Set(this.selectedCultivoIds);
        const secs = new Set(this.selectedSections);
        return this.crops
            .filter((c) => set.has(c.id))
            .map((c) => ({
                ...c,
                showHt: secs.has('ht'),
                showPph: secs.has('pph'),
                showCg: secs.has('cg')
            }));
    }

    get filtersPanelClass() {
        return 'home-filters' + (this.filterOpen ? '' : ' is-hidden');
    }

    get filtersSheetClass() {
        return 'home-filters-sheet' + (this.filterOpen ? '' : ' is-hidden');
    }

    toggleFilters() {
        this.filterOpen = !this.filterOpen;
    }

    closeFilters() {
        this.filterOpen = false;
    }

    clearFilters(event) {
        event.preventDefault();
        this.selectedCultivoIds = this.crops.map((c) => c.id);
        this.selectedSections = [...ALL_SECTIONS];
    }

    toggleCultivoFilter(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.selectedCultivoIds);
        if (next.has(id)) next.delete(id);
        else next.add(id);
        this.selectedCultivoIds = [...next];
    }

    toggleSectionFilter(event) {
        const id = event.currentTarget.dataset.id;
        const next = new Set(this.selectedSections);
        if (next.has(id)) next.delete(id);
        else next.add(id);
        this.selectedSections = [...next];
    }

    goCompraHT() {
        trackGa4Event('ht_compra_iniciada', { portal: 'Productor', accion: 'comprar' });
        const portalBase = window.location.pathname.split('/s/')[0];
        window.location.assign(portalBase + '/s/FormularioNuevaVentaHT');
    }

    goPph(event) {
        const id = event.currentTarget.dataset.id;
        const crop = this.crops.find((c) => c.id === id);
        if (!crop) return;
        if (crop.isAdherir || !crop.isAdherido) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: '/adhesion-pph?recordId=' + crop.paramId }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/adhesion-pph' }
        });
    }

    goMovimientos() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/movimientos-ht' }
        });
    }

    goCuentaGranaria() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/cuentagranarianew' }
        });
    }
}
