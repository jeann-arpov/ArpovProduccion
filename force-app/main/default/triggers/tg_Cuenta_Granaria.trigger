/**
 * Cuenta_Granaria__c (after insert, after update).
 * Expedientes de negativos: CuentaGranariaTriggerHandler (cargas manuales con saldo < -3)
 * y ActualizarCuentaGranariaBatch (compensación de saldos negativos). Cada uno usa su
 * propio interruptor HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS.
 */
trigger tg_Cuenta_Granaria on Cuenta_Granaria__c (after insert, after update) {
    new CuentaGranariaTriggerHandler().run();
}