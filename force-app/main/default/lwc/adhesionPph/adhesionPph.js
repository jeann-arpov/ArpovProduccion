import { LightningElement, track } from "lwc";
import getLoadData from "@salesforce/apex/AdhesionPPH.getLoadData";
import save from "@salesforce/apex/AdhesionPPH.save";
import deleteEstablecimiento from "@salesforce/apex/AdhesionPPH.deleteEstablecimiento";
import acceptTerms from "@salesforce/apex/AdhesionPPH.acceptTerms";
import sendAdhesion from "@salesforce/apex/AdhesionPPH.sendAdhesion";
import rectificarAdhesion from "@salesforce/apex/AdhesionPPH.rectificarAdhesion";
import rectificarAdhesion2 from "@salesforce/apex/AdhesionPPH.rectificarAdhesion2";
import { errorEvent, warningEvent, reduceErrors } from "c/utils";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {trackGa4Event} from 'c/portalGa4Events';

const DEBUG_PPH = false;

const CSS = `
.toastMessage{

    white-space: break-spaces !important;
    }
`;

export default class AdhesionPph extends LightningElement {
  @track establecimientos = [];
  @track variedades = [];

  counter = 1;
  loading = true;
  step = "adhesion";
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

    if (this.establecimientos.length === 0 && isDraft) this.addRow();

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
    return 3;
  }

  get wizardStepLabels() {
    return ["Plan de siembra", "Términos", "Resumen"];
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
      return { key: `wstep-${num}`, label, className };
    });
  }

  get activeWizardStep() {
    if (this.isTerminosYCondiciones) return 2;
    if (this.isResumen && !this.isDetalleView) return 3;
    return 1;
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
    return this.isResumen && !this.isDetalleView && !!this.resumenData;
  }

  /** Resumen editable (En Preparación / Rectificado) o fallback si falló 4a-ver. */
  get showResumenContent() {
    if (this.loading) return false;
    if (this.detalleRenderFailed && this.isResumen && !!this.resumenData) {
      return true;
    }
    return this.isResumen && this.canEditResumen && !!this.resumenData;
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
    if (this.isEdit) return "Editar establecimiento";
    return "Plan de siembra";
  }

  get deskPageTitle() {
    return `Adhesión PPH — ${this.paramName}`;
  }

  get mobPageSubtitle() {
    return "Declará tus establecimientos y hectáreas precertificadas.";
  }

  get deskPageSubtitle() {
    return this.mobPageSubtitle;
  }

  get saldoPphLabel() {
    const n = Number(this.saldoPph);
    if (Number.isNaN(n)) return "—";
    return new Intl.NumberFormat("es-AR").format(n);
  }

  get hideAddEstablecimiento() {
    return this.grandesCuentas === true;
  }

  get deskEstablecimientosCount() {
    return String(this.establecimientos?.length || 0);
  }

  get deskTotalSeLabel() {
    let total = 0;
    try {
      total = (this.variedades || []).reduce(
        (sum, v) => sum + (Number(v.totals?.current) || Number(v.totals?.total) || 0),
        0
      );
      if (!total) {
        const establecimientos = this.resumenData?.establecimientos || [];
        for (const est of establecimientos) {
          total += Object.values(est.variedades || {}).reduce(
            (a, v) => a + (Number(v.cantidad) || 0),
            0
          );
        }
      }
    } catch (e) {
      total = 0;
    }
    return `${new Intl.NumberFormat("es-AR").format(total)} HT`;
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
    this.continuar();
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
      this.step = "adhesion";
      return;
    }
    this.handleMobClose();
  }

  handleResumenSecondary() {
    if (this.canEditResumen) {
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
    // delegado por c-map; establecimientoPph maneja el callback
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
    this.establecimientos.push({ id: ++this.counter, record: {}, lineas });
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
    variedad.totals.current += event.detail.cantidad;
    if (event.detail.cantidad > 0) this.reportStep(2, "variedades");
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
    const variedades = establecimiento.getData().variedades;
    //tengo que descartar las cantidades de hectareas que pusieron
    for (const variedad of Object.keys(variedades)) {
      this.updateCantidad({
        detail: { variedad, cantidad: -variedades[variedad].cantidad }
      });
    }

    this.establecimientos = this.establecimientos.filter((e) => e.id !== id);
  }

  async doRequest(callback) {
    this.loading = true;

    try {
      await callback();
    } catch (e) {
      this.onError(e);
    }

    this.loading = false;
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
    const data = {
      establecimientos: [],
      account: this.account,
      plan: this.plan
    };

    for (const establecimiento of this.template.querySelectorAll(
      "c-establecimiento-pph"
    )) {
      const est = establecimiento.getData();

      if (this.grandesCuentas == true) est.name = this.gcEstablecimientoName;

      est.origen = this.grandesCuentas == true ? "Grandes Cuentas" : "Propio";

      if (establecimiento.info.record.Establecimiento__r) {
        est.id = establecimiento.info.record.Establecimiento__r.Id;
        est.pphId = establecimiento.info.id;
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

      establecimientos.push({
        id: record.Establecimiento__r?.Id,
        name: record.Establecimiento__r?.Name || record.Name,
        latitude: record.Establecimiento__r?.Coordenadas__Latitude__s,
        longitude: record.Establecimiento__r?.Coordenadas__Longitude__s,
        cantidadNoSE: record.Cantidad_Variedad_No_SE__c || 0,
        variedades
      });
    }

    return {
      establecimientos,
      account: this.account,
      plan: this.plan,
      total:
        this.variedades.map((v) => v.totals?.total || 0).reduce((a, b) => a + b, 0) +
        (this.htsGlobales?.total || 0),
      grandesCuentas: this.grandesCuentas,
      saldoPph: this.saldoPph
    };
  }

  get cultivo() {
    try {
      return this.plan?.Parametro_PPH__r?.Cultivo__r?.Name || "";
    } catch (e) {
      console.error("[adhesionPph] getter cultivo", e);
      return "";
    }
  }

  get campaña() {
    return this.plan?.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/)?.[0];
  }

  isValid(showError = false) {
    let valid = true;

    try {
      let cantidadSE = 0;
      for (const establecimiento of this.template.querySelectorAll(
        "c-establecimiento-pph"
      )) {
        if (!establecimiento.validate()) valid = false;
        for (const variedadData of Object.values(
          establecimiento.getData().variedades
        )) {
          cantidadSE += variedadData.cantidad;
        }
      }
      if (cantidadSE == 0)
        throw new Error(
          "No se puede realizar la adhesión sin tener hectareas SE en al menos un establecimiento"
        );
    } catch (e) {
      valid = false;
      if (showError) this.onError(e);
    }

    return valid;
  }

  async save() {
    await this.doRequest(async (_) => {
      if (this.isValid()) {
        const data = this.data;
        console.log(JSON.parse(JSON.stringify(data)));
        const newData = await save({
          js: JSON.stringify(data),
          planId: this.plan.Id
        });
        this.loadData(newData);

        if (this.doContinue) {
          this.doContinue = false;
          this.continuar();
        }
      }
    });
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

    for (const establecimiento of this.establecimientos) {
      if (establecimiento.record.Establecimiento__r.Id !== e.detail.id) {
        this.hiding[establecimiento.id] = true;
      }
    }
    console.log(this.establecimientos, this.hiding, e.detail.id);
    this.step = "edit";
  }

  autosave(e) {
    this.save();
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