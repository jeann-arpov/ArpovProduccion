import { LightningElement, api } from 'lwc';

/**
 * Shell mobile reutilizable (Compra HT, Cesiones, etc.).
 * @fires back @fires close @fires continue
 */
export default class SeMobWizard extends LightningElement {
    @api title = '';
    @api subtitle = '';
    /** Pill en header (ej. cultivo SOJA en cesiones paso 2+) */
    @api titleBadge = '';
    @api currentStep = 1;
    @api totalSteps = 1;
    /** Labels de cada paso, ej. ['Cultivo','Tipo','Marca'] */
    @api stepLabels = [];
    @api footerStatus = '';
    @api continueLabel = 'Continuar →';
    @api continueDisabled = false;
    @api showFooter = false;
    @api confirmFooter = false;
    @api footerStepLabel = '';
    /** 'status' = footer oscuro con copy · 'dual' = Cancelar/Atrás + Continuar (SG cesiones) */
    @api footerVariant = 'status';
    @api cancelLabel = 'Cancelar';
    /** Título H1 en desktop (Compra HT pattern) */
    @api deskTitle = '';
    @api deskSubtitle = '';

    get resolvedFooterStepLabel() {
        return this.footerStepLabel || this.wizardProgressLabel;
    }

    get wizardProgressLabel() {
        return `Paso ${this.currentStep} de ${this.totalSteps}`;
    }

    get progressPctLabel() {
        const total = Number(this.totalSteps) || 1;
        const step = Number(this.currentStep) || 1;
        return `${Math.round((step / total) * 100)}%`;
    }

    get progressBarStyle() {
        const total = Number(this.totalSteps) || 1;
        const step = Number(this.currentStep) || 1;
        return `width: ${Math.round((step / total) * 100)}%`;
    }

    get mobSteps() {
        const current = Number(this.currentStep) || 1;
        return (this.stepLabels || []).map((label, index) => ({
            key: `mob-step-${index}`,
            label,
            className: 'se-mob-step' + (index + 1 === current ? ' is-active' : '')
        }));
    }

    get deskSteps() {
        const current = Number(this.currentStep) || 1;
        const labels = this.stepLabels || [];
        const total = Number(this.totalSteps) || labels.length || 1;

        return labels.map((label, index) => {
            const num = index + 1;
            const isActive = num === current;
            const isDone = num < current;
            const disabled = num > current;

            return {
                key: `desk-step-${num}`,
                num,
                label,
                disabled,
                showLine: num < total,
                circleText: isDone ? '✓' : String(num),
                ariaCurrent: isActive ? 'step' : 'false',
                wrapClass: 'se-prog-item' + (num === total ? ' se-prog-item-last' : ''),
                btnClass:
                    'se-prog-btn' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : ''),
                circleClass:
                    'se-prog-circle' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : ''),
                labelClass:
                    'se-prog-label' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : '')
            };
        });
    }

    get shellClass() {
        let cls = 'shell';
        if (this.showFooter) cls += ' shell--footer';
        return cls;
    }

    get mainClass() {
        return 'main' + (this.showFooter ? ' main--footer' : '');
    }

    get footerClass() {
        let cls = 'se-mob-footer';
        if (this.confirmFooter) cls += ' se-mob-footer--confirm';
        if (this.isDualFooter) cls += ' se-mob-footer--dual';
        return cls;
    }

    get isDualFooter() {
        return this.footerVariant === 'dual';
    }

    get isStatusFooter() {
        return !this.isDualFooter;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleContinue() {
        this.dispatchEvent(new CustomEvent('continue'));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleDeskStepClick(event) {
        const step = Number(event.currentTarget.dataset.step);
        if (!step || step >= Number(this.currentStep)) return;
        this.dispatchEvent(new CustomEvent('stepclick', { detail: { step } }));
    }
}
