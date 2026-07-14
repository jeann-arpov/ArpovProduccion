public class SchdBatchGenerarCvsDesdeOportunidad implements Schedulable {
	//BatchGenerarCvsDesdeOportunidadTest
	public void execute(SchedulableContext sc) {
		BatchGenerarCvsDesdeOportunidad b = new BatchGenerarCvsDesdeOportunidad();
		Database.executebatch(b, BatchGenerarCvsDesdeOportunidad.BATCH_SIZE);
	}

	/**
    * @description Programa el Scheduler
    * @param baseHours : hora inicial en que corre el scheduler
    * @param hours : cada cuantas horas se ejecuta
    * @param minutes : minutos en que arranca a correr
	*/
	public static void start(Integer baseHours, Integer hours, Integer minutes) {
        System.schedule('Generar Cvs desde Oportunidad'+ (Test.isRunningTest() ? '_test' : ''), '0 ' + minutes + ' ' + baseHours + '/' + hours + ' ? * MON-SUN', new SchedulableGeneracionComprobantesVentas());
    }
}