import { LightningElement, track } from "lwc";
import getLoadData from "@salesforce/apex/AdhesionPPH.getLoadData";
import save from "@salesforce/apex/AdhesionPPH.save";
import deleteEstablecimiento from "@salesforce/apex/AdhesionPPH.deleteEstablecimiento";
import acceptTerms from "@salesforce/apex/AdhesionPPH.acceptTerms";
import sendAdhesion from "@salesforce/apex/AdhesionPPH.sendAdhesion";
import rectificarAdhesion from "@salesforce/apex/AdhesionPPH.rectificarAdhesion";
import rectificarAdhesion2 from "@salesforce/apex/AdhesionPPH.rectificarAdhesion2";
import { reduceErrors } from "c/utils";
import { trackGa4Event, trackErrorFuncional } from "c/portalGa4Events";
import { PAGES, goToCommunityPage } from "c/seNav";

const TOAST_MS = 8000;
const TITULO_ADHESION = "Adhesión al Programa de Precertificación de Hectáreas (PPH)";

const STATUS = {
  "En Preparación": { label: "Tu solicitud de adhesión está lista para ser enviada", tone: "info" },
  Rectificado: { label: "Tu solicitud de adhesión está lista para ser enviada", tone: "info" },
  "En Revisión": { label: "Tu solicitud de adhesión ya fue enviada", tone: "ok" },
  Adherido: { label: "Estás adherido al PPH", tone: "ok" },
  Rechazado: { label: "Tu solicitud de adhesión fue rechazada", tone: "danger" },
  Vencido: { label: "Adhesión vencida", tone: "info" }
};

export default class AdhesionPph extends LightningElement {
  @track establecimientos = [];
  @track variedades = [];
  @track toast;

  counter = 1;
  loading = true;
  saving = false;
  step = "adhesion";
  account;
  currentModal;
  plan;
  doContinue = false;
  modalCallback;
  hiding = {};
  htsGlobales = {}; // Las HTs globales de PPH están porque se certificaron previo a las HTs por variedad. Son hts sin variedad
  saldoPph;
  reportedSteps = {};
  pendingSave;
  toastTimer;

  get parametro() {
    return new URL(window.location.href).searchParams.get("recordId");
  }

  connectedCallback() {
    document.documentElement.classList.add("se-inner");
    document.body.classList.add("se-inner");
    if (!this.initialized) {
      this.init();
    }
  }

  disconnectedCallback() {
    document.documentElement.classList.remove("se-inner");
    document.body.classList.remove("se-inner");
    clearTimeout(this.toastTimer);
  }

  async init() {
    this.initialized = true;

    try {
      const data = await getLoadData({ parametroId: this.parametro });
      this.loadData(data);
      trackGa4Event("pph_declaracion_iniciada");
    } catch (e) {
      this.onError(e);
    }

    this.loading = false;
  }

  loadData(data) {
    this.variedades = data.variedades ? data.variedades : this.variedades;

    if (data.stockPorVariedad) {
      this.variedades.forEach((v) => {
        v.totals = data.stockPorVariedad[v.Id] || v.totals || { total: 0 };
      });
      this.htsGlobales = data.stockGlobal || {};
    }

    if (data.account) this.account = data.account;
    if (data.plan) this.plan = data.plan;
    if (data.saldoPph !== undefined) this.saldoPph = data.saldoPph;

    this.variedades.forEach((v) => {
      if (!v.totals) v.totals = { total: 0 };
      v.totals.current = 0;
    });

    const variedades = Object.fromEntries(this.variedades.map((v) => [v.Id, v]));
    const establecimientos = [];

    for (const establecimiento of data.establecimientos || []) {
      const est = {
        id: establecimiento.Id,
        record: establecimiento,
        lineas: []
      };

      for (const variedadId of Object.keys(variedades)) {
        const record =
          (establecimiento.Lineas_PPH__r || []).find((l) => l.Variedad__c == variedadId) || {};
        est.lineas.push({
          id: variedadId,
          record,
          variedad: variedades[variedadId]
        });
        variedades[variedadId].totals.current += record.Cantidad_Declarada__c || 0;
      }

      if (!this.isDraft && establecimiento.Lineas_PPH__r) {
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

      establecimientos.push(est);
    }

    this.establecimientos = establecimientos;

    if (this.establecimientos.length == 0) this.addRow();

    if (!this.isDraft) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => (this.step = "resumen"), 0);
    }

    if (this.plan?.Estado__c == "En Preparación" && data.isInPeriodoAdhesion == false) {
      this.onError("Ya ha terminado el período de adhesión");
    }

    if (data.validation) this.onWarning(data.validation);
  }

  get isDraft() {
    const estado = this.plan?.Estado__c;
    return estado == "En Preparación" || estado == "Rectificado";
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

  get showForm() {
    return this.isAdhesion || this.isEdit;
  }

  get formClass() {
    let cls = "p-form";
    if (!this.showForm) cls += " is-hidden";
    if (this.saving) cls += " is-saving";
    return cls;
  }

  get pageTitle() {
    return this.isTerminosYCondiciones ? "Términos y Condiciones" : TITULO_ADHESION;
  }

  get pageSubtitle() {
    if (this.isTerminosYCondiciones) return `${TITULO_ADHESION} - ${this.paramName}`;
    return this.paramName;
  }

  get showHelpButton() {
    return this.showForm && !!this.plan;
  }

  get status() {
    if (!this.isResumen || !this.plan) return null;
    const conf = STATUS[this.plan.Estado__c] || STATUS["En Revisión"];
    return { label: conf.label, className: `p-status p-status-${conf.tone}` };
  }

  get showAddButton() {
    return this.isAdhesion;
  }

  get cultivo() {
    return this.plan?.Parametro_PPH__r?.Cultivo__r?.Name || "";
  }

  get cultivoRecord() {
    return this.plan?.Parametro_PPH__r?.Cultivo__r;
  }

  get paramName() {
    return this.plan?.Parametro_PPH__r?.Name || "";
  }

  get campaña() {
    return this.plan?.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/)?.[0];
  }

  get totalHtCultivo() {
    return (
      this.variedades.reduce((acc, v) => acc + (v.totals?.total || 0), 0) +
      (this.htsGlobales?.total || 0)
    );
  }

  get grandesCuentas() {
    return this.account?.Grandes_Cuentas__c === true;
  }

  addRow() {
    const lineas = this.variedades.map((variedad) => ({
      id: variedad.Id,
      record: {},
      variedad
    }));
    this.establecimientos.push({ id: ++this.counter, record: {}, lineas });
  }

  handleAddRow() {
    this.addRow();
  }

  /* ---------- Toast ---------- */

  showToast(message, variant = "error") {
    clearTimeout(this.toastTimer);
    this.toast = {
      title: variant === "warning" ? "Atención" : "Error",
      message,
      className: `p-toast p-toast-${variant}`
    };
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.toastTimer = setTimeout(() => (this.toast = null), TOAST_MS);
  }

  closeToast() {
    clearTimeout(this.toastTimer);
    this.toast = null;
  }

  onError(e) {
    const messages = reduceErrors(e);
    try {
      trackErrorFuncional(e, { messages });
    } catch (err) {
      // no bloquear UX por analytics
    }
    this.showToast(messages.join("\n"), "error");
  }

  onWarning(e) {
    this.showToast(reduceErrors(e).join("\n"), "warning");
  }

  handleNotify(event) {
    this.onError(event.detail?.message);
  }

  /* ---------- GA4 ---------- */

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
    if (variedad) variedad.totals.current += event.detail.cantidad;
    if (event.detail.cantidad > 0) this.reportStep(2, "variedades");
  }

  /* ---------- Establecimientos ---------- */

  showMap(event) {
    this.template.querySelector("c-map").show(event.detail.callback);
  }

  closeModal() {
    this.currentModal = null;
    this.modalCallback = null;
  }

  executeModal() {
    if (this.modalCallback) this.modalCallback();
  }

  remove(event) {
    if (this.establecimientos.length == 1)
      return this.onError("No puede borrar el único establecimiento restante");
    this.modalCallback = this.confirmDelete.bind(this, event.target);
    this.currentModal = "confirm-delete";
    return undefined;
  }

  async changeEstablecimiento(event) {
    const id = event.target.info.record.Establecimiento__r.Id;
    const idPph = event.target.info.id;
    await this.doRequest(async () => await deleteEstablecimiento({ id }));
    const idx = this.establecimientos.findIndex((e) => e.id === idPph);
    if (idx < 0) return;
    this.establecimientos[idx].lineas = this.establecimientos[idx].lineas.map((l) => ({
      ...l,
      record: { Cantidad_Declarada__c: l.record.Cantidad_Declarada__c }
    }));
    this.establecimientos[idx].record = {};
  }

  confirmDelete(toDelete) {
    this.closeModal();
    const id = toDelete.info.record.Establecimiento__r?.Id;

    if (id != null) {
      this.doRequest(() =>
        deleteEstablecimiento({ id }).then(() => this.removeEstablecimiento(toDelete))
      );
    } else {
      this.removeEstablecimiento(toDelete);
    }
  }

  removeEstablecimiento(establecimiento) {
    const id = establecimiento.info.id;
    const variedades = establecimiento.getData().variedades;
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

  /* ---------- Datos ---------- */

  get data() {
    const data = {
      establecimientos: [],
      account: this.account,
      plan: this.plan
    };

    for (const establecimiento of this.template.querySelectorAll("c-establecimiento-pph")) {
      const est = establecimiento.getData();
      est.origen = "Propio";

      if (establecimiento.info.record.Establecimiento__r) {
        est.id = establecimiento.info.record.Establecimiento__r.Id;
        est.pphId = establecimiento.info.id;
      }

      data.establecimientos.push(est);
    }

    data.total = this.totalHtCultivo;
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

  serializeSavePayload(data) {
    return {
      establecimientos: (data.establecimientos || []).map((est) => {
        const variedades = {};
        for (const [vid, v] of Object.entries(est.variedades || {})) {
          if (!this.isSalesforceId(vid)) continue;
          variedades[vid] = {
            id: this.isSalesforceId(v?.id) ? v.id : null,
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

  isValid(showError = false) {
    let valid = true;

    try {
      let cantidadSE = 0;
      for (const establecimiento of this.template.querySelectorAll("c-establecimiento-pph")) {
        if (!establecimiento.validate(showError)) valid = false;
        for (const variedadData of Object.values(establecimiento.getData().variedades)) {
          cantidadSE += variedadData.cantidad;
        }
      }
      if (cantidadSE == 0)
        throw new Error(
          "No se puede realizar la adhesión sin tener hectáreas SE en al menos un establecimiento"
        );
    } catch (e) {
      valid = false;
      if (showError) this.onError(e);
    }

    return valid;
  }

  async save() {
    if (!this.plan || !this.isDraft || !this.isValid()) return;
    this.saving = true;
    try {
      const payload = this.serializeSavePayload(this.data);
      const newData = await save({
        js: JSON.stringify(payload),
        planId: this.plan.Id
      });
      this.loadData(newData);
    } catch (e) {
      this.onError(e);
    }
    this.saving = false;

    if (this.doContinue) {
      this.doContinue = false;
      this.continuar();
    }
  }

  autosave() {
    this.pendingSave = this.save();
  }

  /* ---------- Pasos ---------- */

  continuar() {
    if (this.saving) {
      this.doContinue = true;
      return;
    }
    if (this.isValid(true)) {
      this.currentModal = "confirm-continue";
      this.modalCallback = this.goToNextStep.bind(this);
    }
  }

  goToNextStep() {
    this.closeModal();
    this.scrollTop();

    if (this.plan.Terminos_y_Condiciones__c != true) {
      this.step = "terminos";
    } else {
      this.step = "resumen";
    }
  }

  cancelTerms() {
    this.step = "adhesion";
    this.scrollTop();
  }

  async acceptTerms() {
    await this.doRequest(async () => {
      await acceptTerms({ planId: this.plan.Id });
      this.plan = { ...this.plan, Terminos_y_Condiciones__c: true };
      this.reportStep(4, "aceptacion");
    });
    if (this.plan.Terminos_y_Condiciones__c) this.enviarConfirm();
  }

  backToResumen() {
    if (this.isValid(true)) {
      this.step = "resumen";
      this.scrollTop();
    }
  }

  edit(e) {
    const hiding = {};
    for (const establecimiento of this.establecimientos) {
      if (establecimiento.record.Establecimiento__r?.Id !== e.detail.id) {
        hiding[establecimiento.id] = true;
      }
    }
    this.hiding = hiding;
    this.step = "edit";
    this.scrollTop();
  }

  enviarConfirm() {
    this.reportStep(5, "confirmacion");
    this.enviar();
  }

  rectificarConfirm() {
    this.modalCallback = this.rectificar.bind(this);
    this.currentModal = "confirm-continue-rectificar";
  }

  async enviar() {
    let enviado = false;
    await this.doRequest(async () => {
      await sendAdhesion({ planId: this.plan.Id });
      this.plan = { ...this.plan, Estado__c: "En Revisión" };
      this.currentModal = "en-revision";
      enviado = true;
      this.trackEnviado();
    });
    if (enviado && this.plan.Tiene_Hts_Pendientes__c == true) {
      this.onWarning(
        "La adhesión de las HTs que se encuentran pendientes de pago está atada al pago en tiempo y forma de las mismas"
      );
    }
  }

  trackEnviado() {
    const establecimientos = this.data.establecimientos;
    const cantidad_establecimientos = establecimientos.length;
    const hectareas_se = establecimientos.reduce(
      (acc, e) => acc + Object.values(e.variedades).reduce((a, v) => a + (v.cantidad || 0), 0),
      0
    );
    const hectareas_no_se = establecimientos.reduce((acc, e) => acc + (e.cantidadNoSE || 0), 0);
    trackGa4Event("pph_enviado", {
      cantidad_establecimientos,
      hectareas_se,
      hectareas_no_se
    });
  }

  get rectificacionWindow() {
    const params = this.plan?.Parametro_PPH__r;
    if (!params) return 0;
    const inWindow = (n) => {
      const start = params[`Fecha_Inicio_Rectificacion_${n}__c`];
      const end = params[`Fecha_Fin_Rectificacion_${n}__c`];
      if (!start || !end) return false;
      const now = new Date();
      return now >= new Date(start) && now <= new Date(end);
    };
    if (inWindow(1)) return 1;
    if (inWindow(2)) return 2;
    return 0;
  }

  async rectificar() {
    this.closeModal();
    await this.doRequest(async () => {
      if (this.rectificacionWindow === 2) {
        await rectificarAdhesion2({ planId: this.plan.Id });
      } else {
        await rectificarAdhesion({ planId: this.plan.Id });
      }
      window.location.reload();
    });
  }

  goHome() {
    goToCommunityPage(PAGES.home);
  }

  scrollTop() {
    try {
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (e) {
      window.scrollTo(0, 0);
    }
  }

  /* ---------- Modales ---------- */

  get isDeleteConfirm() {
    return this.currentModal == "confirm-delete";
  }

  get isContinueConfirm() {
    return this.currentModal == "confirm-continue";
  }

  get isRectificarConfirm() {
    return this.currentModal == "confirm-continue-rectificar";
  }

  get isEnRevision() {
    return this.currentModal == "en-revision";
  }

  get showModal() {
    return this.currentModal != null;
  }

  handleOnInformarPagoClick() {
    this.template.querySelector("c-informar-pago").show({
      title: "No veo mis HTs",
      subject: `CUIT: ${this.account.N_CUIT__c} - ${this.plan.Name} - PPH`,
      accountId: this.account.Id,
      variant: "sg"
    });
  }
}
