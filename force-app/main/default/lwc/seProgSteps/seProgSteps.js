import { LightningElement, api } from 'lwc';

/**
 * Stepper compartido Productor.
 * Mobile: barra lima + labels.
 * Desktop: círculos + línea verde entre pasos completados.
 *
 * @fires stepclick { detail: { step: number } }
 */
export default class SeProgSteps extends LightningElement {
    /** Texto corto (mobile), ej. "Paso 1 de 3" */
    @api labelShort = '';
    /** Texto largo (desktop), ej. "Cuenta Granaria · Paso 1 de 3" */
    @api labelLong = '';
    @api currentStep = 1;
    /** Labels por paso, ej. ['Cultivo','Plataforma','Campaña'] */
    @api stepLabels = [];
    /** Labels cortos mobile; si vacío usa stepLabels */
    @api mobStepLabels = [];
    /** 'panel' = card suelta · 'inline' = chrome de wizard mobile */
    @api appearance = 'panel';

    get rootClass() {
        return (
            'se-prog' +
            (this.appearance === 'inline' ? ' se-prog--inline' : ' se-prog--panel')
        );
    }

    get resolvedLabelShort() {
        return this.labelShort || this.wizardProgressLabel;
    }

    get resolvedLabelLong() {
        return this.labelLong || this.resolvedLabelShort;
    }

    get totalSteps() {
        const fromLabels = (this.stepLabels || []).length;
        return fromLabels > 0 ? fromLabels : 1;
    }

    get wizardProgressLabel() {
        return `Paso ${this.currentStep} de ${this.totalSteps}`;
    }

    get progressPctLabel() {
        return `${Math.round((Number(this.currentStep) / this.totalSteps) * 100)}%`;
    }

    get progressBarStyle() {
        return `width: ${Math.round((Number(this.currentStep) / this.totalSteps) * 100)}%`;
    }

    get mobSteps() {
        const current = Number(this.currentStep) || 1;
        const labels =
            this.mobStepLabels && this.mobStepLabels.length
                ? this.mobStepLabels
                : this.stepLabels || [];
        return labels.map((label, index) => ({
            key: `mob-step-${index}`,
            label,
            className: 'se-mob-step' + (index + 1 === current ? ' is-active' : '')
        }));
    }

    get deskSteps() {
        const current = Number(this.currentStep) || 1;
        const labels = this.stepLabels || [];
        const total = this.totalSteps;

        return labels.map((label, index) => {
            const num = index + 1;
            const isActive = num === current;
            const isDone = num < current;
            return {
                key: `desk-step-${num}`,
                num,
                label,
                disabled: num > current,
                showLine: num < total,
                circleText: isDone ? '✓' : String(num),
                ariaCurrent: isActive ? 'step' : 'false',
                wrapClass:
                    'se-prog-item' +
                    (num === total ? ' se-prog-item-last' : '') +
                    (isDone ? ' is-done' : ''),
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

    handleDeskStepClick(event) {
        const step = Number(event.currentTarget.dataset.step);
        if (!step || step >= Number(this.currentStep)) return;
        this.dispatchEvent(new CustomEvent('stepclick', { detail: { step } }));
    }
}
