/**
* @author Maximo Martinez
* @date 07/08/2018
* @description Clase Batcheable que Genera Avisos de Vencimientos de Facturas
*/
global class SchedulableAvisoDeVencimientosDeFacturas implements Schedulable {
	
	global void execute(SchedulableContext sc) {
		
		Date startDate = Date.today().addDays(1);
    	Date endDate = Date.today().addDays(15);
    	Boolean isTest = false;
		
		Database.executeBatch(new BatchAvisoDeVencimientosDeFacturas(isTest,startDate,endDate),100);

	}

		/**
    * @author Maximo Martinez
    * @description Programa el Scheduler
    * @param baseHours : hora inicial en que corre el scheduler
    * @param hours : cada cuantas horas se ejecuta
    * @param minutes : minutos en que arranca a correr
	*/
	global static void start(Integer baseHours, Integer hours, Integer minutes) {
        System.schedule('Envio de Emails de Aviso de Vencimiento de Facturas'+ (Test.isRunningTest() ? '_test' : ''), '0 ' + minutes + ' ' + baseHours + '/' + hours + ' ? * MON-SUN', new SchedulableAvisoDeVencimientosDeFacturas());
    }
}