import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getLoadData from "@salesforce/apex/AdhesionPPH.getLoadData";
import save from "@salesforce/apex/AdhesionPPH.save";
import deleteEstablecimiento from "@salesforce/apex/AdhesionPPH.deleteEstablecimiento";
import acceptTerms from "@salesforce/apex/AdhesionPPH.acceptTerms";
import sendAdhesion from "@salesforce/apex/AdhesionPPH.sendAdhesion";
import rectificarAdhesion from "@salesforce/apex/AdhesionPPH.rectificarAdhesion";
import rectificarAdhesion2 from "@salesforce/apex/AdhesionPPH.rectificarAdhesion2";
import listEstablecimientosDisponibles from "@salesforce/apex/AdhesionPPH.listEstablecimientosDisponibles";
import { errorEvent, warningEvent, reduceErrors } from "c/utils";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {trackGa4Event} from 'c/portalGa4Events';

const DEBUG_PPH = false;

const CSS = `
.toastMessage{

    white-space: break-spaces !important;
    }
`;

export default class AdhesionPph extends NavigationMixin(LightningElement) {
  @track establecimientos = [];
  @track variedades = [];

  counter = 1;
  loading = true;
  step = "adhesion";
  declarationPhase = "establecimiento";
  account;
  currentModal;
  plan;
  doContinue = false;
  modalCallback;
  hiding = {};
  htsGlobales = {}; // Las HTs globales de PPH están porque se certificaron previo a las HTs por variedad. Son hts sin variedad
  saldoPph;
  certificadoDocumentId;
  reportedSteps = {};
  wizardStep = 1;
  @track availableEstablecimientos = [];
  showCreatePanel = false;
  createName = "";
  createLat;
  createLng;
  @track debugLines = [];
  @track loadError = "";
  @track debugSnapshot = "";
  @track resumenData;
  detalleRenderFailed = false;

  get planEstadoLabel() {
    return this.plan?.Estado__c || "cargando";
  }

  get statusBarLabel() {
    return `PPH · ${this.cultivoPillLabel || "—"} · ${this.planEstadoLabel} · paso ${this.step}`;
  }

  get parametro() {
    const parametro = new URL(window.location.href).searchParams.get(
      "recordId"
    );
    return parametro;
  }

  debugLog(message, detail) {
    if (!DEBUG_PPH) return;
    const line =
      detail !== undefined ? `${message} ${JSON.stringify(detail)}` : message;
    this.debugLines = [
      ...this.debugLines.slice(-24),
      `${new Date().toISOString().slice(11, 19)} ${line}`
    ];
    this.updateDebugSnapshot();
  }

  updateDebugSnapshot() {
    this.debugSnapshot = [
      `parametro=${this.parametro || "(vacío)"}`,
      `loading=${this.loading}`,
      `step=${this.step}`,
      `plan=${this.plan?.Estado__c || "(sin plan)"}`,
      `wizard=${this.showDeclarationWizard}`,
      `terminos=${this.isTerminosYCondiciones}`,
      `resumen=${this.isResumen}`,
      `detalle=${this.isDetalleView}`,
      `showDetalle=${this.showPphDetalle}`,
      `rectificar=${this.canRectificarResumen}`,
      `establecimientos=${this.establecimientos?.length || 0}`,
      `variedades=${this.variedades?.length || 0}`
    ].join(" | ");
  }

  errorCallback(error, stack) {
    const message = error?.message || String(error);
    this.loadError = message;
    console.error("[adhesionPph] errorCallback", message, stack, error);
    this.detalleRenderFailed = true;
    if (!this.isResumen && this.plan) {
      try {
        this.goToResumenStep();
      } catch (e) {
        console.error("[adhesionPph] errorCallback fallback", e);
      }
    }
    this.debugLog("errorCallback", { message, stack });
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error PPH (render)",
        message,
        variant: "error",
        mode: "sticky"
      })
    );
  }

  async init() {
    this.initialized = true;

    try {
      if (!this.parametro) {
        throw new Error(
          "Falta recordId en la URL (?recordId=Id del Parametro PPH)."
        );
      }
      const data = await getLoadData({ parametroId: this.parametro });
      this.loadData(data);
      await this.loadAvailableEstablecimientos();
    } catch (e) {
      this.loadError = reduceErrors(e).join("; ");
      console.error("[adhesionPph] init stack", e);
      this.onError(e);
    }

    this.loading = false;
    if (DEBUG_PPH) {
      this.updateDebugSnapshot();
    }
  }

  loadData(data) {
    this.variedades = data.variedades ? data.variedades : this.variedades;

    if (data.stockPorVariedad) {
      this.variedades.forEach((v) => {
        v.totals = data.stockPorVariedad[v.Id] || v.totals || { total: 0, current: 0 };
      });
      this.htsGlobales = data.stockGlobal || {};
    }

    if (data.account) this.account = data.account;
    if (data.plan) this.plan = data.plan;
    trackGa4Event("pph_declaracion_iniciada");

    this.saldoPph = data.saldoPph;
    this.certificadoDocumentId = data.certificadoDocumentId;

    this.variedades.forEach((v) => {
      if (!v.totals) v.totals = { total: 0, current: 0 };
      v.totals.current = 0;
    });

    const variedades = Object.fromEntries(
      this.variedades.map((v) => [v.Id, v])
    );

    const establecimientos = [];

    for (const establecimiento of data.establecimientos) {
      const est = {
        id: establecimiento.Id,
        record: establecimiento,
        lineas: []
      };

      for (const variedadId of Object.keys(variedades)) {
        const record =
          (establecimiento.Lineas_PPH__r || []).find(
            (l) => l.Variedad__c == variedadId
          ) || {};
        est.lineas.push({
          id: variedadId,
          record,
          variedad: variedades[variedadId]
        });
        if (!variedades[variedadId].totals) {
          variedades[variedadId].totals = { total: 0, current: 0 };
        }
        variedades[variedadId].totals.current +=
          record.Cantidad_Declarada__c || 0;
      }

      est.cantidadSE = est.lineas.reduce(
        (sum, l) => sum + (Number(l.record?.Cantidad_Declarada__c) || 0),
        0
      );

      if (
        this.plan.Estado__c != "En Preparación" &&
        this.plan.Estado__c != "Rectificado"
      ) {
        if (establecimiento.Lineas_PPH__r) {
          for (const linea of establecimiento.Lineas_PPH__r) {
            if (est.lineas.find((l) => l.id == linea.Variedad__c) == null) {
              est.lineas.push({
                id: linea.Variedad__c,
                record: linea,
                variedad: { ...linea.Variedad__r, totals: {} }
              });
            }
          }
        }
      }

      establecimientos.push(est);
    }

    this.establecimientos = establecimientos;

    const isDraft =
      this.plan.Estado__c === "En Preparación" ||
      this.plan.Estado__c === "Rectificado";

    // Descartar filas vacías sin establecimiento real (el checklist es la fuente).
    this.establecimientos = this.establecimientos.filter((e) => {
      const r = e.record?.Establecimiento__r;
      return !!(r?.Id || r?.Name);
    });

    if (this.establecimientos.length === 0 && isDraft) {
      this.showCreatePanel = false;
    }

    // Adherido/certificado: ir al detalle YA, sin pintar el wizard.
    // El setTimeout(0) dejaba un frame con c-establecimiento-pph y la página se iba a blanco.
    if (!isDraft) {
      this.goToResumenStep();
    }

    if (
      this.plan.Estado__c == "En Preparación" &&
      data.isInPeriodoAdhesion == false
    )
      this.onError("Ya ha terminado el período de adhesión");

    if (data.validation) {
      const style = document.createElement("style");
      style.innerText = CSS;
      this.template.querySelector("div").appendChild(style);

      this.onWarning(data.validation);
    }

    if (this.grandesCuentas) {
      const addBtn = this.template.querySelector(".pph-add-est");
      if (addBtn) addBtn.classList.add("slds-hide");
    }
  }

  get isAdhesion() {
    return this.step == "adhesion";
  }

  get isEdit() {
    return this.step == "edit";
  }

  get isTerminosYCondiciones() {
    return this.step == "terminos";
  }

  get isResumen() {
    return this.step == "resumen";
  }

  get showDeclarationWizard() {
    return !this.loading && (this.isAdhesion || this.isEdit);
  }

  get showTerminos() {
    return !this.loading && this.isTerminosYCondiciones;
  }

  get wizardStepsTotal() {
    return 2;
  }

  get wizardStepLabels() {
    return ["Establecimientos y superficie", "Términos y Condiciones"];
  }

  get wizardProgressLabel() {
    return `Paso ${this.activeWizardStep} de ${this.wizardStepsTotal}`;
  }

  get wizardProgressPct() {
    const total = Number(this.wizardStepsTotal) || 1;
    const step = Number(this.activeWizardStep) || 1;
    return Math.round((step / total) * 100);
  }

  get wizardProgressPctLabel() {
    return `${this.wizardProgressPct}%`;
  }

  get wizardProgressBarStyle() {
    return `width: ${this.wizardProgressPct}%`;
  }

  get wizardStepsUi() {
    const current = Number(this.activeWizardStep) || 1;
    return (this.wizardStepLabels || []).map((label, index) => {
      const num = index + 1;
      let className = "pph-wiz-step";
      if (num === current) className += " is-active";
      else if (num < current) className += " is-done";
      return { key: `wstep-${num}`, label: `${num} · ${label}`, className };
    });
  }

  /** Stepper desktop clásico (círculos + check), mismo patrón que Compra HT. */
  get deskWizardSteps() {
    const current = Number(this.activeWizardStep) || 1;
    const labels = this.wizardStepLabels || [];
    const total = labels.length;
    return labels.map((label, index) => {
      const num = index + 1;
      const isActive = num === current;
      const isDone = num < current;
      return {
        key: `desk-wstep-${num}`,
        num,
        label,
        disabled: num > current,
        showLine: num < total,
        circleText: isDone ? "✓" : String(num),
        ariaCurrent: isActive ? "step" : "false",
        wrapClass:
          "se-prog-item" + (num === total ? " se-prog-item-last" : ""),
        btnClass:
          "se-prog-btn" +
          (isActive ? " is-active" : "") +
          (isDone ? " is-done" : ""),
        circleClass:
          "se-prog-circle" +
          (isActive ? " is-active" : "") +
          (isDone ? " is-done" : ""),
        labelClass:
          "se-prog-label" +
          (isActive ? " is-active" : "") +
          (isDone ? " is-done" : "")
      };
    });
  }

  handleDeskWizardStepClick(event) {
    const clicked = Number(event.currentTarget.dataset.step);
    if (!clicked || clicked >= this.activeWizardStep) return;
    if (clicked === 1 && (this.isTerminosYCondiciones || this.isResumen)) {
      this.handleConfirmBack();
    }
  }

  get activeWizardStep() {
    if (this.isTerminosYCondiciones || (this.isResumen && !this.isDetalleView))
      return 2;
    return 1;
  }

  get isDeclarationEstablecimiento() {
    return this.showDeclarationWizard && this.declarationPhase === "establecimiento";
  }

  get isDeclarationSuperficie() {
    return this.showDeclarationWizard && this.declarationPhase === "superficie";
  }

  get establecimientoWizardPhase() {
    // Checklist arriba + superficie abajo (nunca el header legacy "ESTABLECIMIENTO").
    return "superficie";
  }

  get showAddEstablecimiento() {
    return !this.hideAddEstablecimiento && this.showDeclarationWizard;
  }

  get showAddEstablecimientoLegacy() {
    return false;
  }

  get showDeclarationBack() {
    return false;
  }

  get showEstablecimientoChecklist() {
    return this.showDeclarationWizard;
  }

  get showEstablecimientoCards() {
    if (!this.showDeclarationWizard) return false;
    return (this.establecimientos || []).some(
      (e) =>
        e.clientKey ||
        e.record?.Establecimiento__r?.Id ||
        e.record?.Establecimiento__r?.Name ||
        this.grandesCuentas
    );
  }

  get checklistItems() {
    const selectedIds = new Set(
      (this.establecimientos || [])
        .map((e) => e.record?.Establecimiento__r?.Id || e.clientKey)
        .filter(Boolean)
    );

    const items = (this.availableEstablecimientos || []).map((e) => {
      const key = e.clientKey || e.id;
      const selected = selectedIds.has(key) || selectedIds.has(e.id);
      return {
        key,
        id: e.id,
        clientKey: e.clientKey,
        name: e.name,
        locationLabel: e.locationLabel || "Sin ubicación registrada",
        selected,
        rowClass: selected ? "se-est-check is-selected" : "se-est-check",
        checkClass: selected ? "se-est-check-box is-on" : "se-est-check-box"
      };
    });

    return items;
  }

  get hasChecklistItems() {
    return this.checklistItems.length > 0;
  }

  get checklistSummary() {
    const n = (this.establecimientos || []).length;
    const total = this.checklistItems.length;
    if (!total) return "No hay establecimientos vigentes. Creá uno para continuar.";
    return `${n} de ${total} seleccionados`;
  }

  get createMapLabel() {
    if (this.createLat != null && this.createLng != null) {
      return `${Number(this.createLat).toFixed(2)}, ${Number(this.createLng).toFixed(2)}`;
    }
    return "Seleccionar punto de lote";
  }

  get sideTotalLabel() {
    return "Superficie SE";
  }

  get showSideNoSe() {
    return this.showDeclarationWizard;
  }

  async loadAvailableEstablecimientos() {
    try {
      const rows = await listEstablecimientosDisponibles();
      const fromServer = (rows || []).map((r) => ({
        id: r.id,
        name: r.name,
        locationLabel: r.locationLabel,
        lat: r.lat,
        lng: r.lng
      }));

      // Conservar borradores locales (altas nuevas aún no guardadas).
      const drafts = (this.availableEstablecimientos || []).filter((e) => e.clientKey);
      const serverIds = new Set(fromServer.map((e) => e.id));
      const extras = drafts.filter((d) => !serverIds.has(d.id));
      this.availableEstablecimientos = [...fromServer, ...extras];

      // Incluir los ya adheridos al plan aunque no figuren en la lista filtrada.
      const known = new Set(
        this.availableEstablecimientos.map((e) => e.id).filter(Boolean)
      );
      for (const est of this.establecimientos || []) {
        const r = est.record?.Establecimiento__r;
        if (r?.Id && !known.has(r.Id)) {
          this.availableEstablecimientos = [
            ...this.availableEstablecimientos,
            {
              id: r.Id,
              name: r.Name || est.record?.Name || "Establecimiento",
              locationLabel: "En esta adhesión",
              lat: r.Coordenadas__Latitude__s,
              lng: r.Coordenadas__Longitude__s
            }
          ];
          known.add(r.Id);
        }
        if (r?.Id) {
          est.clientKey = r.Id;
        }
      }

      if (!this.availableEstablecimientos.length && !(this.establecimientos || []).length) {
        this.showCreatePanel = true;
      }
    } catch (e) {
      this.onError(e);
    }
  }

  emptyLineas() {
    return this.variedades.map((variedad) => ({
      id: variedad.Id,
      record: {},
      variedad
    }));
  }

  handleToggleEstablecimiento(event) {
    const key = event.currentTarget.dataset.key;
    const item = (this.availableEstablecimientos || []).find(
      (e) => (e.clientKey || e.id) === key
    );
    if (!item) return;

    const matchKey = item.clientKey || item.id;
    const existingIdx = this.establecimientos.findIndex(
      (e) =>
        e.clientKey === matchKey ||
        e.record?.Establecimiento__r?.Id === item.id
    );

    if (existingIdx >= 0) {
      this.deselectEstablecimientoAt(existingIdx);
      return;
    }

    this.selectAvailableItem(item);
  }

  selectAvailableItem(item) {
    const estRecord = {
      Name: item.name,
      Establecimiento__r: {
        Id: item.id || undefined,
        Name: item.name,
        Coordenadas__Latitude__s: item.lat,
        Coordenadas__Longitude__s: item.lng
      },
      Cantidad_Variedad_No_SE__c: 0
    };
    // No enviar Id temporal a Salesforce
    if (!item.id) {
      delete estRecord.Establecimiento__r.Id;
    }

    this.establecimientos = [
      ...this.establecimientos,
      {
        id: ++this.counter,
        clientKey: item.clientKey || item.id,
        record: estRecord,
        lineas: this.emptyLineas(),
        cantidadSE: 0
      }
    ];
    this.handlePasoEstablecimiento();
  }

  deselectEstablecimientoAt(idx) {
    const row = this.establecimientos[idx];
    const pphId = row?.record?.Id;
    const sfEstId = row?.record?.Establecimiento__r?.Id;

    const removeLocal = () => {
      this.establecimientos = this.establecimientos.filter((_, i) => i !== idx);
    };

    if (pphId && sfEstId) {
      this.doRequest(async () => {
        await deleteEstablecimiento({ id: sfEstId });
        removeLocal();
      });
      return;
    }
    removeLocal();
  }

  openCreatePanel() {
    this.showCreatePanel = true;
    this.createName = "";
    this.createLat = undefined;
    this.createLng = undefined;
  }

  cancelCreatePanel() {
    this.showCreatePanel = false;
    this.createName = "";
    this.createLat = undefined;
    this.createLng = undefined;
  }

  handleCreateNameChange(event) {
    this.createName = event.target.value;
  }

  openCreateMap() {
    this._createMapCallback = (data, map) => {
      map?.hide?.();
      this.createLat = data.latitude;
      this.createLng = data.longitude;
    };
    this.template.querySelector("c-map")?.show(this._createMapCallback);
  }

  confirmCreateEstablecimiento() {
    const name = (this.createName || "").trim();
    if (!name) {
      this.onError("Ingresá el nombre del establecimiento");
      return;
    }
    if (this.createLat == null || this.createLng == null) {
      this.onError("Seleccioná la georeferencia del establecimiento");
      return;
    }

    const clientKey = `new-${++this.counter}`;
    const item = {
      clientKey,
      id: null,
      name,
      locationLabel: "Nuevo establecimiento",
      lat: this.createLat,
      lng: this.createLng
    };
    this.availableEstablecimientos = [...this.availableEstablecimientos, item];
    this.selectAvailableItem(item);
    this.cancelCreatePanel();
  }

  get isDetalleView() {
    return this.isResumen && !this.canEditResumen && !this.canRectificarResumen;
  }

  get showPphDetalle() {
    return (
      !this.loading &&
      this.isResumen &&
      !this.canEditResumen &&
      !!this.resumenData &&
      !this.detalleRenderFailed
    );
  }

  get showDetalleRectificar() {
    return this.showPphDetalle && this.canRectificarResumen;
  }

  get showResumenWizard() {
    return (
      !this.loading &&
      this.isResumen &&
      this.canEditResumen &&
      !!this.resumenData
    );
  }

  /** Solo fallback legacy si falló el detalle de plan Adherido. */
  get showResumenContent() {
    if (this.loading) return false;
    return (
      this.detalleRenderFailed &&
      this.isResumen &&
      !!this.resumenData &&
      !this.canEditResumen
    );
  }

  get confirmPageTitle() {
    return "Revisá tu adhesión";
  }

  get confirmPageSubtitle() {
    const cultivo = this.cultivoPillLabel || "cultivo";
    const campana = this.confirmCampanaLabel;
    const parts = [cultivo, campana].filter(Boolean);
    return `Confirmá la declaración de ${parts.join(" · ")} antes de enviarla.`;
  }

  get confirmBreadcrumb() {
    const name = this.plan?.Name || "Adhesión";
    return `Precertificación / Adhesiones / ${name}`;
  }

  get confirmCampanaLabel() {
    const campanaName = this.plan?.Parametro_PPH__r?.Campana__r?.Name;
    if (campanaName) return campanaName;
    // Campana__c es lookup; no mostrar el Id crudo
    const raw = this.plan?.Parametro_PPH__r?.Campana__c;
    if (raw && typeof raw === "string" && raw.length === 18 && raw.startsWith("a")) {
      return this.paramName || "";
    }
    if (raw && typeof raw === "string" && !raw.startsWith("a")) {
      return `Campaña ${raw}`;
    }
    return this.paramName || "";
  }

  get confirmTotalSe() {
    return (this.resumenData?.establecimientos || []).reduce((sum, est) => {
      if (est?.cantidadSE != null) return sum + (Number(est.cantidadSE) || 0);
      return (
        sum +
        Object.values(est?.variedades || {}).reduce(
          (a, v) => a + (Number(v?.cantidad) || 0),
          0
        )
      );
    }, 0);
  }

  get confirmTotalNoSe() {
    return (this.resumenData?.establecimientos || []).reduce(
      (sum, est) => sum + (Number(est?.cantidadNoSE) || 0),
      0
    );
  }

  get confirmSemilleroLabel() {
    const shortMap = {
      "03": "GDM",
      "14": "GDM",
      "85": "GDM",
      "04": "Syngenta",
      "23": "Syngenta",
      "13": "Pioneer",
      "87": "Brevant",
      "24": "Stine",
      "16": "MacroSeed",
      "77": "BASF",
      "06": "Klein",
      "05": "Buck",
      "12": "LG",
      "19": "Bioceres"
    };
    const names = new Set();
    (this.resumenData?.establecimientos || []).forEach((est) => {
      Object.values(est?.variedades || {}).forEach((linea) => {
        if (!(Number(linea?.cantidad) > 0)) return;
        const obt = linea?.variedad?.Obtentor_Comercializa__r;
        const id = String(obt?.Id_Obtentor__c || "");
        const key = id.padStart(2, "0");
        const short = shortMap[key] || shortMap[id];
        if (short) {
          names.add(short);
          return;
        }
        const raw = obt?.Name;
        if (raw) names.add(raw.replace(/\s*\([^)]*\)\s*$/, "").trim());
      });
    });
    if (!names.size) return "—";
    return Array.from(names).join(" · ");
  }

  get confirmToneladasLabel() {
    const fmt = (n) => new Intl.NumberFormat("es-AR").format(Number(n) || 0);
    const ht2kilos =
      Number(this.plan?.Parametro_PPH__r?.Cultivo__r?.HT2Kilos__c) || 0;
    if (!ht2kilos || !this.confirmTotalSe) return "—";
    const toneladas = (this.confirmTotalSe * ht2kilos) / 1000;
    return `${fmt(Math.round(toneladas * 10) / 10)} t`;
  }

  get confirmSummaryRows() {
    const fmt = (n) => new Intl.NumberFormat("es-AR").format(Number(n) || 0);
    const rows = [
      {
        key: "cultivo",
        label: "Cultivo",
        value: this.cultivoPillLabel || "—",
        valueClass: "v v-strong"
      },
      {
        key: "campana",
        label: "Campaña",
        value: this.confirmCampanaLabel || "—",
        valueClass: "v"
      },
      {
        key: "sem",
        label: "Semillero",
        value: this.confirmSemilleroLabel,
        valueClass: "v"
      },
      {
        key: "ests",
        label: "Establecimientos",
        value: this.deskEstablecimientosCount,
        valueClass: "v"
      },
      {
        key: "se",
        label: "Superficie declarada",
        value: `${fmt(this.confirmTotalSe)} ha`,
        valueClass: "v v-strong"
      },
      {
        key: "tn",
        label: "Toneladas estimadas",
        value: this.confirmToneladasLabel,
        valueClass: "v v-strong"
      }
    ];
    if (this.confirmTotalNoSe > 0) {
      rows.splice(5, 0, {
        key: "nose",
        label: "Ha no SE",
        value: `${fmt(this.confirmTotalNoSe)} ha`,
        valueClass: "v"
      });
    }
    return rows;
  }

  get confirmEstablecimientos() {
    const fmt = (n) => new Intl.NumberFormat("es-AR").format(Number(n) || 0);
    return (this.resumenData?.establecimientos || []).map((e, idx) => {
      const se =
        e.cantidadSE != null
          ? Number(e.cantidadSE) || 0
          : Object.values(e.variedades || {}).reduce(
              (a, v) => a + (Number(v.cantidad) || 0),
              0
            );
      const noSe = Number(e.cantidadNoSE) || 0;
      return {
        key: e.pphId || e.id || `confirm-est-${idx}`,
        editId: e.id,
        name: e.name || `Establecimiento ${idx + 1}`,
        seLabel: `${fmt(se)} ha`,
        noSeLabel: `${fmt(noSe)} ha`
      };
    });
  }

  handleConfirmEdit(event) {
    const id = event.currentTarget.dataset.id;
    if (!id) return;
    this.edit({ detail: { id } });
  }

  handleConfirmBack() {
    this.hiding = {};
    this.declarationPhase = "establecimiento";
    this.step = "adhesion";
  }

  goToResumenStep() {
    this.refreshResumenData();
    this.step = "resumen";
    if (DEBUG_PPH) {
      this.updateDebugSnapshot();
    }
  }

  refreshResumenData() {
    try {
      const fromDom = this.buildResumenInfoFromDom();
      this.resumenData =
        fromDom.establecimientos.length > 0
          ? fromDom
          : this.buildResumenInfoFromRecords();
    } catch (e) {
      const message = reduceErrors(e).join("; ");
      console.error("[adhesionPph] refreshResumenData", e);
      this.resumenData = {
        establecimientos: [],
        account: this.account,
        plan: this.plan,
        total: 0,
        grandesCuentas: this.grandesCuentas,
        saldoPph: this.saldoPph
      };
    }
  }

  get cultivoPillLabel() {
    if (!this.plan?.Parametro_PPH__r?.Cultivo__r?.Name) return "";
    return this.plan.Parametro_PPH__r.Cultivo__r.Name.toUpperCase();
  }

  get mobPageTitle() {
    if (this.isEdit) return "Editar adhesión";
    return "Continuá la adhesión";
  }

  get deskPageTitle() {
    return `Continuá la adhesión — ${this.paramName}`;
  }

  get mobPageSubtitle() {
    return `Seleccioná los establecimientos y completá la superficie para ${this.cultivoPillLabel || "el cultivo"} · ${this.paramName || ""}`;
  }

  get deskPageSubtitle() {
    return this.mobPageSubtitle;
  }

  /** HT disponibles para precertificar (stock vigente), no el residual post-adhesión. */
  get saldoDisponibleHt() {
    const fromVariedades = (this.variedades || []).reduce(
      (sum, v) => sum + (Number(v.totals?.total) || 0),
      0
    );
    return fromVariedades + (Number(this.htsGlobales?.total) || 0);
  }

  get saldoPphLabel() {
    const n = this.saldoDisponibleHt;
    if (Number.isNaN(n)) return "—";
    return new Intl.NumberFormat("es-AR").format(n);
  }

  get showSaldoCompraHint() {
    const n = this.saldoDisponibleHt;
    return Number.isNaN(n) || n <= 0;
  }

  get saldoCompraHint() {
    return "Sin HT disponibles — comprá para precertificar.";
  }

  redirectCompraHT() {
    this[NavigationMixin.GenerateUrl]({
      type: "comm__namedPage",
      attributes: {
        pageName: "FormularioNuevaVentaHT"
      }
    }).then((url) => window.open(url, "_blank"));
  }

  get hideAddEstablecimiento() {
    return false;
  }

  get deskEstablecimientosCount() {
    if (this.isResumen && this.resumenData?.establecimientos) {
      return String(this.resumenData.establecimientos.length || 0);
    }
    return String(this.establecimientos?.length || 0);
  }

  get deskTotalSeLabel() {
    let total = 0;
    try {
      if (this.isResumen && this.resumenData?.establecimientos?.length) {
        for (const est of this.resumenData.establecimientos) {
          if (est.cantidadSE != null) {
            total += Number(est.cantidadSE) || 0;
          } else {
            total += Object.values(est.variedades || {}).reduce(
              (a, v) => a + (Number(v.cantidad) || 0),
              0
            );
          }
        }
      } else {
        const nodes =
          this.template?.querySelectorAll?.("c-establecimiento-pph") || [];
        for (const node of nodes) {
          const data = typeof node.getData === "function" ? node.getData() : null;
          if (data?.cantidadSE != null) {
            total += Number(data.cantidadSE) || 0;
          } else {
            total += Object.values(data?.variedades || {}).reduce(
              (a, v) => a + (Number(v.cantidad) || 0),
              0
            );
          }
        }
        if (!total) {
          for (const est of this.establecimientos || []) {
            if (est.cantidadSE != null) {
              total += Number(est.cantidadSE) || 0;
            } else {
              total += (est.lineas || []).reduce(
                (a, l) => a + (Number(l.record?.Cantidad_Declarada__c) || 0),
                0
              );
            }
          }
        }
      }
    } catch (e) {
      total = 0;
    }
    return `${new Intl.NumberFormat("es-AR").format(total)} ha`;
  }

  get deskTotalNoSeLabel() {
    let total = 0;
    try {
      const nodes = this.template?.querySelectorAll?.("c-establecimiento-pph") || [];
      for (const node of nodes) {
        const data = typeof node.getData === "function" ? node.getData() : null;
        total += Number(data?.cantidadNoSE) || 0;
      }
      if (!total && this.resumenData?.establecimientos) {
        for (const est of this.resumenData.establecimientos) {
          total += Number(est.cantidadNoSE) || 0;
        }
      }
    } catch (e) {
      total = 0;
    }
    return `${new Intl.NumberFormat("es-AR").format(total)} ha`;
  }

  get showMobWizardFooter() {
    return this.isAdhesion;
  }

  get mobFooterContinuarDisabled() {
    return false;
  }

  get mobFooterContinuarLabel() {
    return "Continuar →";
  }

  get mobCancelLabel() {
    return "Cancelar";
  }

  get mobFooterStatus() {
    return "";
  }

  get hideTerminosFooter() {
    return false;
  }

  get isResumenMobileEmbedded() {
    return true;
  }

  get resumenMobTitle() {
    if (this.canEditResumen) return "Revisá tu adhesión";
    return "Adhesión enviada";
  }

  get resumenDeskTitle() {
    return this.resumenMobTitle;
  }

  get canEditResumen() {
    const estado = this.plan?.Estado__c;
    return estado === "En Preparación" || estado === "Rectificado";
  }

  get canRectificarResumen() {
    const params = this.plan?.Parametro_PPH__r;
    if (!params || this.plan?.Estado__c !== "Adherido") return false;
    return this.isWithinRectificacionWindow(params, 1) || this.isWithinRectificacionWindow(params, 2);
  }

  isWithinRectificacionWindow(params, n) {
    const start = params[`Fecha_Inicio_Rectificacion_${n}__c`];
    const end = params[`Fecha_Fin_Rectificacion_${n}__c`];
    if (!start || !end) return false;
    const now = new Date();
    return now >= new Date(start) && now <= new Date(end);
  }

  get rectificacionWindow() {
    const params = this.plan?.Parametro_PPH__r;
    if (!params) return 0;
    if (this.isWithinRectificacionWindow(params, 1)) return 1;
    if (this.isWithinRectificacionWindow(params, 2)) return 2;
    return 0;
  }

  get showResumenMobFooter() {
    return this.canEditResumen || this.canRectificarResumen;
  }

  get showResumenPrimary() {
    return this.showResumenMobFooter;
  }

  get showResumenSecondary() {
    return this.canEditResumen;
  }

  get resumenEnviarDisabled() {
    return !this.canEditResumen;
  }

  get resumenCancelLabel() {
    if (this.canRectificarResumen && !this.canEditResumen) return "Volver";
    return "Editar";
  }

  get resumenContinueLabel() {
    if (this.canRectificarResumen && !this.canEditResumen) return "Rectificar";
    return "Enviar adhesión";
  }

  get resumenDeskSecondaryLabel() {
    return this.resumenCancelLabel;
  }

  get resumenDeskPrimaryLabel() {
    return this.resumenContinueLabel;
  }

  handleMobContinuar() {
    if (this.showDeclarationWizard) {
      if (!this.isValidEstablecimientos(true)) return;
      this.reportStep(2, "establecimientos_y_superficie");
      this.continuar();
      return;
    }
    this.continuar();
  }

  handleDeclarationBack() {
    // Paso único: no hay sub-paso interno.
  }

  isValidEstablecimientos(showError = false) {
    try {
      if (this.showEstablecimientoChecklist) {
        if (!(this.establecimientos || []).length) {
          throw new Error("Seleccioná o creá al menos un establecimiento");
        }
        for (const est of this.establecimientos) {
          const hasExisting = !!est.record?.Establecimiento__r?.Id;
          const hasDraft =
            !!est.record?.Establecimiento__r?.Name &&
            (est.record?.Establecimiento__r?.Coordenadas__Latitude__s != null ||
              est.record?.Establecimiento__r?.Coordenadas__longitude__s != null ||
              est.record?.Establecimiento__r?.Coordenadas__Longitude__s != null);
          if (!hasExisting && !hasDraft) {
            throw new Error("Seleccioná o creá un establecimiento para continuar");
          }
        }
        return true;
      }

      const nodes = this.template.querySelectorAll("c-establecimiento-pph");
      if (!nodes.length) {
        throw new Error("Agregá al menos un establecimiento");
      }
      for (const node of nodes) {
        if (typeof node.validateSelection === "function" && !node.validateSelection()) {
          throw new Error("Seleccioná o creá un establecimiento para continuar");
        }
      }
      return true;
    } catch (e) {
      if (showError) this.onError(e);
      return false;
    }
  }

  handleMobBack() {
    this.handleMobClose();
  }

  handleMobClose() {
    window.history.back();
  }

  handleMobCancel() {
    this.handleMobClose();
  }

  handleResumenBack() {
    if (this.canEditResumen) {
      this.declarationPhase = "establecimiento";
      this.step = "adhesion";
      return;
    }
    this.handleMobClose();
  }

  handleResumenSecondary() {
    if (this.canEditResumen) {
      this.declarationPhase = "establecimiento";
      this.step = "adhesion";
      return;
    }
    this.handleMobClose();
  }

  handleResumenPrimary() {
    if (this.canRectificarResumen && !this.canEditResumen) {
      this.rectificarConfirm();
      return;
    }
    this.enviarConfirm();
  }

  updateLocation(event) {
    if (typeof this._createMapCallback === "function") {
      this._createMapCallback(event.detail);
      this._createMapCallback = null;
    }
  }

  get year() {
    if (!this.plan) return "";
    const param = this.plan.Parametro_PPH__r;
    return (
      param.Fecha_Inicio_Adhesion_PPH__c.split("-")[0] +
      "/" +
      param.Fecha_Fin_Adhesion_PPH__c.split("-")[0]
    );
  }

  get cultivo() {
    if (!this.plan) return "";
    const param = this.plan.Parametro_PPH__r;
    return param.Cultivo__r.Name;
  }

  get paramName() {
    if (!this.plan) return "";
    const param = this.plan.Parametro_PPH__r;
    return param.Name;
  }

  get grandesCuentas() {
    return this.account.Grandes_Cuentas__c;
  }

  get gcEstablecimientoName() {
    return this.account.N_CUIT__c + " - " + this.plan.Parametro_PPH__r.Name;
  }

  addRow() {
    const lineas = this.variedades.map((variedad) => ({
      id: variedad.Id,
      record: {},
      variedad
    }));
    this.establecimientos.push({
      id: ++this.counter,
      record: {},
      lineas,
      cantidadSE: 0
    });
  }

  connectedCallback() {
    console.log("[adhesionPph] connectedCallback");
    document.documentElement.classList.add("se-inner", "se-inner-wizard");
    document.body.classList.add("se-inner", "se-inner-wizard");
    if (!this.initialized) {
      this.init();
    }
  }

  renderedCallback() {
    if (!this.loading && !this._loggedReady) {
      this._loggedReady = true;
      console.log("[adhesionPph] ready", {
        step: this.step,
        estado: this.plan?.Estado__c,
        detalle: this.showPphDetalle,
        resumen: this.showResumenContent,
        wizard: this.showDeclarationWizard
      });
    }
    if (DEBUG_PPH) {
      this.updateDebugSnapshot();
    }
  }

  get showDebugPanel() {
    return DEBUG_PPH;
  }

  get showLoadError() {
    return !this.loading && !!this.loadError;
  }

  get hasVisibleContent() {
    return (
      this.showDeclarationWizard ||
      this.isTerminosYCondiciones ||
      this.showResumenContent ||
      this.showPphDetalle ||
      this.showResumenWizard
    );
  }

  get showEmptyState() {
    return !this.loading && !this.hasVisibleContent && !this.loadError;
  }

  disconnectedCallback() {
    document.documentElement.classList.remove("se-inner", "se-inner-wizard");
    document.body.classList.remove("se-inner", "se-inner-wizard");
  }

  onError(e) {
    const message = reduceErrors(e).join("\n");
    this.loadError = message;
    this.debugLog("onError", message);
    this.notifyValidationError(e);
  }

  /** Toast / evento de error sin tumbar el wizard (no setea loadError). */
  notifyValidationError(e) {
    const message = reduceErrors(e).join("\n");
    this.debugLog("notifyValidationError", message);
    this.dispatchEvent(errorEvent(e));
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error PPH",
        message,
        variant: "error",
        mode: "sticky"
      })
    );
  }

  clearSuperficieSeErrors() {
    for (const el of this.template.querySelectorAll("c-establecimiento-pph")) {
      if (typeof el.setSuperficieSeError === "function") {
        el.setSuperficieSeError("");
      }
    }
  }

  markSuperficieSeOverSaldo(message) {
    for (const el of this.template.querySelectorAll("c-establecimiento-pph")) {
      if (typeof el.setSuperficieSeError === "function") {
        el.setSuperficieSeError(message);
      }
    }
  }

  onWarning(e) {
    this.dispatchEvent(warningEvent(e));
  }

  reportStep(paso, nombre) {
    if (this.reportedSteps[paso]) return;
    this.reportedSteps[paso] = true;
    trackGa4Event("pph_paso_completado", { paso, nombre_paso: nombre });
  }

  handlePasoEstablecimiento() {
    this.reportStep(1, "establecimientos");
  }

  handlePasoHectareasNoSE() {
    this.reportStep(3, "hectareas_no_se");
  }

  updateCantidad(event) {
    const variedad = this.variedades.find((v) => v.Id == event.detail.variedad);
    if (!variedad) return;
    if (!variedad.totals) variedad.totals = { total: 0, current: 0 };
    variedad.totals.current += event.detail.cantidad;
    if (event.detail.cantidad > 0) this.reportStep(2, "variedades");
  }

  updateCantidadSe(event) {
    const estId = event.target?.info?.id;
    const cantidad = event.detail?.cantidad;
    // Persistir en el padre: autosave pone loading=true y desmonta el wizard;
    // sin esto, al remount el hijo vuelve a init() con cantidadSE=0.
    if (estId != null && cantidad != null) {
      this.establecimientos = this.establecimientos.map((e) =>
        e.id === estId ? { ...e, cantidadSE: cantidad } : e
      );
    }
    if ((cantidad || 0) > 0) {
      this.reportStep(2, "superficie");
    }
    // Si el total entre establecimientos supera el saldo, marcar todos los inputs SE
    this.revalidateTotalSeInline();
    this.recalcVariedadCurrentsFromDom();
  }

  revalidateTotalSeInline() {
    let total = 0;
    const nodes = [
      ...this.template.querySelectorAll("c-establecimiento-pph")
    ];
    for (const el of nodes) {
      total += Number(el.getData()?.cantidadSE) || 0;
    }
    const saldo = Number(this.saldoDisponibleHt) || 0;
    if (total > saldo) {
      const fmt = (n) => new Intl.NumberFormat("es-AR").format(n);
      const message = `La superficie total (${fmt(total)} ha) supera las ${fmt(saldo)} HT disponibles del cultivo`;
      this.markSuperficieSeOverSaldo(message);
      return;
    }
    for (const el of nodes) {
      if (typeof el.applySeFieldValidity === "function") {
        el.applySeFieldValidity();
        el.reportSeValidity?.();
      }
    }
  }

  updateCantidadNoSe(event) {
    const estId = event.target?.info?.id;
    const cantidad = event.detail?.cantidad;
    if (estId == null || cantidad == null) return;
    this.establecimientos = this.establecimientos.map((e) => {
      if (e.id !== estId) return e;
      return {
        ...e,
        record: {
          ...(e.record || {}),
          Cantidad_Variedad_No_SE__c: cantidad
        }
      };
    });
  }

  /**
   * Reparte superficie SE (total por establecimiento) entre variedades con stock,
   * priorizando las de mayor saldo. Mutates data.establecimientos[].variedades.
   */
  applySeAllocation(data) {
    const remainingStock = {};
    for (const v of this.variedades || []) {
      remainingStock[v.Id] = Number(v.totals?.total) || 0;
    }

    const sortedIds = [...(this.variedades || [])]
      .sort(
        (a, b) => (Number(b.totals?.total) || 0) - (Number(a.totals?.total) || 0)
      )
      .map((v) => v.Id);

    for (const est of data.establecimientos || []) {
      if (est.variedades && Object.keys(est.variedades).length > 0) {
        continue;
      }

      let need = Number(est.cantidadSE) || 0;
      const metaById = Object.fromEntries(
        (est.lineasMeta || []).map((m) => [m.variedadId, m])
      );
      const variedades = {};

      for (const vid of sortedIds) {
        const meta = metaById[vid] || {};
        const available = Math.max(remainingStock[vid] || 0, 0);
        const take = Math.min(need, available);
        remainingStock[vid] = available - take;
        need -= take;

        if (take > 0 || meta.lineaId) {
          variedades[vid] = {
            id: meta.lineaId || null,
            cantidad: take,
            variedad: meta.variedad
          };
        }
      }

      if (need > 0) {
        throw new Error(
          "La superficie a precertificar supera el saldo de HT disponible del cultivo"
        );
      }

      est.variedades = variedades;
    }

    return data;
  }

  recalcVariedadCurrentsFromDom() {
    try {
      (this.variedades || []).forEach((v) => {
        if (!v.totals) v.totals = { total: 0, current: 0 };
        v.totals.current = 0;
      });
      const data = this.buildResumenInfoFromDomRaw();
      this.applySeAllocation(data);
      for (const est of data.establecimientos || []) {
        for (const [vid, vdata] of Object.entries(est.variedades || {})) {
          const v = this.variedades.find((x) => x.Id == vid);
          if (v) {
            if (!v.totals) v.totals = { total: 0, current: 0 };
            v.totals.current += Number(vdata.cantidad) || 0;
          }
        }
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[adhesionPph] recalcVariedadCurrentsFromDom", e);
    }
  }

  buildResumenInfoFromDomRaw() {
    const data = {
      establecimientos: [],
      account: this.account,
      plan: this.plan
    };

    for (const establecimiento of this.template.querySelectorAll(
      "c-establecimiento-pph"
    )) {
      const est = establecimiento.getData();

      if (establecimiento.info.record.Establecimiento__r) {
        est.id = establecimiento.info.record.Establecimiento__r.Id;
        // info.id puede ser un contador local (1, 2, …) del checklist; no es un Id SF.
        // Solo mandar pphId si es el Id real de Establecimiento_PPH__c.
        const recordPphId = establecimiento.info.record?.Id;
        est.pphId = this.isSalesforceId(recordPphId)
          ? recordPphId
          : this.isSalesforceId(establecimiento.info.id)
            ? establecimiento.info.id
            : null;
      }

      // Grandes Cuentas: el patrón CUIT-plan solo aplica a establecimientos NUEVOS.
      // Si reutilizamos uno Propio existente, no pisar Name/Origen (rompe el checklist).
      const hasExistingEstId = this.isSalesforceId(est.id);
      if (this.grandesCuentas === true && !hasExistingEstId) {
        est.name = this.gcEstablecimientoName;
        est.origen = "Grandes Cuentas";
      } else {
        est.origen = "Propio";
      }

      data.establecimientos.push(est);
    }

    data.total =
      this.variedades.map((v) => v.totals?.total || 0).reduce((a, b) => a + b, 0) +
      (this.htsGlobales?.total || 0);
    data.grandesCuentas = this.grandesCuentas;
    data.saldoPph = this.saldoPph;
    return data;
  }

  isSalesforceId(value) {
    return (
      typeof value === "string" &&
      (value.length === 15 || value.length === 18) &&
      /^[a-zA-Z0-9]+$/.test(value)
    );
  }

  /** Payload limpio para Apex Data/Establecimiento/Variedad (sin campos UI). */
  serializeSavePayload(data) {
    return {
      establecimientos: (data.establecimientos || []).map((est) => {
        const variedades = {};
        for (const [vid, v] of Object.entries(est.variedades || {})) {
          if (!this.isSalesforceId(vid)) continue;
          const lineaId = v?.id;
          variedades[vid] = {
            id: this.isSalesforceId(lineaId) ? lineaId : null,
            cantidad: Number(v?.cantidad) || 0
          };
        }
        return {
          id: this.isSalesforceId(est.id) ? est.id : null,
          pphId: this.isSalesforceId(est.pphId) ? est.pphId : null,
          latitude: est.latitude,
          longitude: est.longitude,
          cantidadNoSE: Number(est.cantidadNoSE) || 0,
          name: est.name,
          origen: est.origen,
          variedades
        };
      })
    };
  }

  showMap(event) {
    this.template.querySelector("c-map").show(event.detail.callback);
  }

  closeModal() {
    this.currentModal = null;
    this.modalCallback = null;
  }

  remove(event) {
    if (this.establecimientos.length == 1)
      return this.onError("No puede borrar el único establecimiento restante");
    this.modalCallback = this.confirmDelete.bind(this, event.target);
    this.currentModal = "confirm-delete";
  }

  async changeEstablecimiento(event) {
    const id = event.target.info.record.Establecimiento__r.Id;
    const idPph = event.target.info.id;
    await this.doRequest(async () => await deleteEstablecimiento({ id }));
    let idx = this.establecimientos.findIndex((e) => e.id === idPph);
    this.establecimientos[idx].lineas = this.establecimientos[idx].lineas.map(
      (l) => ({
        ...l,
        record: { Cantidad_Declarada__c: l.record.Cantidad_Declarada__c }
      })
    );
    this.establecimientos[idx].record = {};
    delete this.establecimientos[idx].id;
  }

  confirmDelete(toDelete) {
    this.closeModal();
    const id = toDelete.info.record.Establecimiento__r?.Id;

    if (id != null) {
      this.doRequest(() =>
        deleteEstablecimiento({ id }).then((_) =>
          this.removeEstablecimiento(toDelete)
        )
      );
    } else {
      this.removeEstablecimiento(toDelete);
    }
  }

  removeEstablecimiento(establecimiento) {
    const id = establecimiento.info.id;
    const data = establecimiento.getData();
    if (data.cantidadSE != null) {
      // currents se recalculan al quitar el nodo
    } else {
      const variedades = data.variedades || {};
      for (const variedad of Object.keys(variedades)) {
        this.updateCantidad({
          detail: { variedad, cantidad: -variedades[variedad].cantidad }
        });
      }
    }

    this.establecimientos = this.establecimientos.filter((e) => e.id !== id);
    // Dejar que el DOM se actualice y recalcular
    Promise.resolve().then(() => this.recalcVariedadCurrentsFromDom());
  }

  async doRequest(callback, quiet = false) {
    // quiet: no togglear loading (evita desmontar c-establecimiento-pph / perder inputs)
    if (!quiet) this.loading = true;

    try {
      await callback();
    } catch (e) {
      this.onError(e);
    }

    if (!quiet) this.loading = false;
  }

  get data() {
    try {
      if (this.resumenData) {
        return this.resumenData;
      }
      const fromDom = this.buildResumenInfoFromDom();
      if (fromDom.establecimientos.length) {
        return fromDom;
      }
      return this.buildResumenInfoFromRecords();
    } catch (e) {
      console.error("[adhesionPph] getter data", e);
      throw e;
    }
  }

  buildResumenInfoFromDom() {
    return this.applySeAllocation(this.buildResumenInfoFromDomRaw());
  }

  buildResumenInfoFromRecords() {
    const establecimientos = [];

    for (const est of this.establecimientos || []) {
      const record = est.record || {};
      const variedades = {};

      for (const linea of est.lineas || []) {
        const cantidad = linea.record?.Cantidad_Declarada__c || 0;
        if (cantidad > 0 || linea.record?.Id) {
          variedades[linea.id] = {
            cantidad,
            variedad: linea.variedad || linea.record?.Variedad__r
          };
        }
      }

      const loc = record.Establecimiento__r?.Localidad__r?.Name;
      const prov = record.Establecimiento__r?.Provincia__c;
      let locationLabel = '';
      if (loc && prov) locationLabel = `${loc}, ${prov}`;
      else if (loc) locationLabel = loc;
      else if (prov) locationLabel = prov;

      establecimientos.push({
        id: record.Establecimiento__r?.Id,
        name: record.Establecimiento__r?.Name || record.Name,
        locationLabel,
        latitude: record.Establecimiento__r?.Coordenadas__Latitude__s,
        longitude: record.Establecimiento__r?.Coordenadas__Longitude__s,
        cantidadNoSE: record.Cantidad_Variedad_No_SE__c || 0,
        cantidadSE:
          est.cantidadSE != null
            ? est.cantidadSE
            : Object.values(variedades).reduce(
                (a, v) => a + (Number(v.cantidad) || 0),
                0
              ),
        lineasMeta: (est.lineas || []).map((l) => ({
          variedadId: l.id,
          lineaId: l.record?.Id || null,
          stock: Number(l.variedad?.totals?.total) || 0,
          variedad: l.variedad
        })),
        variedades
      });
    }

    return this.applySeAllocation({
      establecimientos,
      account: this.account,
      plan: this.plan,
      total:
        this.variedades.map((v) => v.totals?.total || 0).reduce((a, b) => a + b, 0) +
        (this.htsGlobales?.total || 0),
      grandesCuentas: this.grandesCuentas,
      saldoPph: this.saldoPph
    });
  }

  get campaña() {
    return this.plan?.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/)?.[0];
  }

  isValid(showError = false) {
    let valid = true;

    try {
      this.clearSuperficieSeErrors();

      let cantidadSE = 0;
      for (const establecimiento of this.template.querySelectorAll(
        "c-establecimiento-pph"
      )) {
        if (!establecimiento.validate()) valid = false;
        const estData = establecimiento.getData();
        if (estData.cantidadSE != null) {
          cantidadSE += Number(estData.cantidadSE) || 0;
        } else {
          for (const variedadData of Object.values(estData.variedades || {})) {
            cantidadSE += variedadData.cantidad;
          }
        }
      }

      if (!valid) {
        if (showError) {
          this.notifyValidationError(
            new Error(
              "Revisá las hectáreas ingresadas: hay valores inválidos o incompletos"
            )
          );
        }
        return false;
      }

      if (cantidadSE == 0)
        throw new Error(
          "No se puede realizar la adhesión sin tener hectareas SE en al menos un establecimiento"
        );

      const saldo = Number(this.saldoDisponibleHt) || 0;
      if (cantidadSE > saldo) {
        const fmt = (n) => new Intl.NumberFormat("es-AR").format(n);
        const message = `La superficie total (${fmt(cantidadSE)} ha) supera las ${fmt(saldo)} HT disponibles del cultivo`;
        this.markSuperficieSeOverSaldo(message);
        throw new Error(message);
      }

      // Valida que el reparto sea posible
      this.applySeAllocation(this.buildResumenInfoFromDomRaw());
    } catch (e) {
      valid = false;
      if (showError) this.notifyValidationError(e);
    }

    return valid;
  }

  async save(options = {}) {
    const quiet = options.quiet === true;
    await this.doRequest(async (_) => {
      // En autosave no exigir que TODOS los establecimientos tengan ha
      // (el usuario puede ir llenando de a uno); solo Continuar usa isValid estricto.
      const ok = quiet ? this.canQuietSave() : this.isValid();
      if (!ok) return;

      const data = this.buildResumenInfoFromDom();
      const payload = this.serializeSavePayload(data);
      console.log(JSON.parse(JSON.stringify(payload)));
      const newData = await save({
        js: JSON.stringify(payload),
        planId: this.plan.Id
      });
      this.loadData(newData);

      if (this.doContinue) {
        this.doContinue = false;
        this.continuar();
      }
    }, quiet);
  }

  /** Guardado parcial desde blur: al menos un SE > 0 y reparto posible. */
  canQuietSave() {
    try {
      let cantidadSE = 0;
      for (const establecimiento of this.template.querySelectorAll(
        "c-establecimiento-pph"
      )) {
        const estData = establecimiento.getData();
        cantidadSE += Number(estData.cantidadSE) || 0;
      }
      if (cantidadSE <= 0) return false;
      if (cantidadSE > this.saldoDisponibleHt) return false;
      this.applySeAllocation(this.buildResumenInfoFromDomRaw());
      return true;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn("[adhesionPph] canQuietSave", e);
      return false;
    }
  }

  get adhesionClass() {
    return this.isAdhesion || this.isEdit ? "" : "slds-hide";
  }

  continuar(e) {
    if (this.isValid(true)) {
      this.currentModal = "confirm-continue";
      this.modalCallback = this.goToNextStep.bind(this);
    }
  }

  goToNextStep() {
    this.closeModal();

    if (this.plan.Terminos_y_Condiciones__c != true) {
      this.step = "terminos";
    } else {
      this.goToResumenStep();
    }
  }

  cancelTerms(e) {
    this.declarationPhase = "establecimiento";
    this.step = "adhesion";
  }

  async acceptTerms(e) {
    await this.doRequest(async (_) => {
      await acceptTerms({ planId: this.plan.Id });
      this.plan.Terminos_y_Condiciones__c = true;
      this.reportStep(4, "aceptacion");
      this.goToResumenStep();
    });
  }

  backToResumen() {
    if (this.isValid(true)) {
      this.goToResumenStep();
    }
  }

  edit(e) {
    this.hiding = {};
    this.declarationPhase = "establecimiento";

    for (const establecimiento of this.establecimientos) {
      if (establecimiento.record.Establecimiento__r.Id !== e.detail.id) {
        this.hiding[establecimiento.id] = true;
      }
    }
    console.log(this.establecimientos, this.hiding, e.detail.id);
    this.step = "edit";
  }

  autosave(e) {
    this.save({ quiet: true });
  }

  enviarConfirm(e) {
    this.reportStep(5, "confirmacion");
    this.loading = true;
    this.enviar();
    //this.modalCallback = this.enviar.bind(this);
    //this.currentModal = "confirm-continue-resumen";
  }

  rectificarConfirm(e) {
    this.modalCallback = this.rectificar.bind(this);
    this.currentModal = "confirm-continue-rectificar";
  }

  async enviar() {
    await this.doRequest(async (_) => {
      await sendAdhesion({ planId: this.plan.Id });
      this.plan.Estado__c = "Adherido";
      this.currentModal = "adherido";
      this.trackEnviado();
    });
    if (this.plan.Tiene_Hts_Pendientes__c == true) {
      this.dispatchEvent(
        warningEvent(
          new Error(
            "La adhesión de las HTs que se encuentran pendientes de pago está atada al pago en tiempo y forma de las mismas"
          )
        )
      );
    }
  }

  trackEnviado() {
    const establecimientos = this.data.establecimientos;
    const cantidad_establecimientos = establecimientos.length;
    const hectareas_se = establecimientos.reduce(
      (acc, e) =>
        acc +
        Object.values(e.variedades).reduce((a, v) => a + (v.cantidad || 0), 0),
      0
    );
    const hectareas_no_se = establecimientos.reduce(
      (acc, e) => acc + (e.cantidadNoSE || 0),
      0
    );
    trackGa4Event("pph_enviado", {
      cantidad_establecimientos,
      hectareas_se,
      hectareas_no_se
    });
  }

  async rectificar() {
    await this.doRequest(async (_) => {
      if (this.rectificacionWindow === 2) {
        await rectificarAdhesion2({ planId: this.plan.Id });
      } else {
        await rectificarAdhesion({ planId: this.plan.Id });
      }
      window.location.reload();
    });
  }

  isPointerEventInsideElement(event, element) {
    var pos = {
      x:
        (event.targetTouches ? event.targetTouches[0].pageX : event.pageX) -
        window.scrollX,
      y:
        (event.targetTouches ? event.targetTouches[0].pageY : event.pageY) -
        window.scrollY
    };
    var rect = element.getBoundingClientRect();
    return (
      pos.x < rect.right &&
      pos.x > rect.left &&
      pos.y < rect.bottom &&
      pos.y > rect.top
    );
  }

  loadingClick(e) {
    if (
      this.loading &&
      this.step == "adhesion" &&
      this.isPointerEventInsideElement(
        e,
        this.template.querySelector(".continue")
      )
    ) {
      this.doContinue = true; // si hacen click en continue, tengo que esperar a que termine el save y luego les ahorro rehacer el click
    }
  }

  handleDetalleBack() {
    this.handleMobClose();
  }

  handleDetalleVerExpediente() {
    // Placeholder hasta que exista un expediente vinculado al plan:
    // vuelve al listado de adhesiones (Mis PPH).
    this.handleMobClose();
  }

  handleDetalleDownloadPdf(event) {
    const documentId = event.detail?.documentId;
    if (!documentId) return;
    this.template.querySelector("c-pdf-reader")?.show({
      documentId,
      title: "Certificado PPH"
    });
  }

  handleDetalleNotify(event) {
    this.dispatchEvent(warningEvent(event.detail?.message));
  }

  handleOnInformarPagoClick(event) {
    this.template.querySelector("c-informar-pago").show({
      title: "No veo mis HTs",
      subject: `CUIT: ${this.account.N_CUIT__c} - ${this.plan.Name} - PPH`,
      accountId: this.account.Id,
      variant: "sg"
    });
  }
}