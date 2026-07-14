global class SchedulableGeneracionComprobantesVentas implements Schedulable {
	
	global void execute(SchedulableContext sc) {
		BatchApexGeneracionComprobantesVentas b = new BatchApexGeneracionComprobantesVentas();
		Database.executebatch(b, BatchApexGeneracionComprobantesVentas.BATCH_SIZE);
	}

	/**
    * @author Maximo Martinez
    * @description Programa el Scheduler
    * @param baseHours : hora inicial en que corre el scheduler
    * @param hours : cada cuantas horas se ejecuta
    * @param minutes : minutos en que arranca a correr
	*/
	global static void start(Integer baseHours, Integer hours, Integer minutes) {
        System.schedule('Generar Comprobantes de Venta'+ (Test.isRunningTest() ? '_test' : ''), '0 ' + minutes + ' ' + baseHours + '/' + hours + ' ? * MON-SUN', new SchedulableGeneracionComprobantesVentas());
    }

}