public class ReportExporterQueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        ContentVersion content = new ContentVersion();
        content.Title = 'test.csv';
        content.PathOnClient = 'test.csv';
        content.IsMajorVersion = true;
        content.versionData = Blob.valueOf(ReportExporter.getReportCsv());
        insert content;       
    }
}