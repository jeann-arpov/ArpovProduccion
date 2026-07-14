global class ReportExporterScheduler implements Schedulable{
    global void execute(SchedulableContext sc) {
        ReportExporter.exportReportAndUpload('Licencias_Enlist_Aprobadas_LnP');
     }
}