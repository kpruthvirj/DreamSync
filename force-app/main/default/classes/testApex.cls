public with sharing class testApex {

    public class Result {
        public String contentDocumentId;
        public String downloadUrl;
        public String statusMessage;
        public Boolean isSuccess;
    }

    public static Result generateReport(Id predictionRecordId) {
        Result resp = new Result();
        try {
            // Render the Visualforce page as PDF
            PageReference pageRef = Page.EmissionReport;
            pageRef.getParameters().put('id', String.valueOf(predictionRecordId));

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF content');
            } else {
                pdfBlob = pageRef.getContentAsPDF();
            }

            // Save as a Salesforce File (ContentVersion)
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Emission_Report_' + predictionRecordId;
            cv.PathOnClient = 'Emission_Report_' + predictionRecordId + '.pdf';
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = predictionRecordId; // auto-links to the record
            insert cv;

            // Retrieve the resulting ContentDocumentId + a shareable URL
            ContentVersion inserted = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            resp.contentDocumentId = inserted.ContentDocumentId;
            resp.downloadUrl = URL.getOrgDomainUrl().toExternalForm()
                + '/sfc/servlet.shepherd/document/download/' + inserted.ContentDocumentId;
            resp.statusMessage = 'Report generated successfully.';
            resp.isSuccess = true;

        } catch (Exception e) {
            resp.statusMessage = 'Failed to generate report: ' + e.getMessage();
            resp.isSuccess = false;
        }
        return resp;
    }

    // Optional: bulk-friendly overload if you ever need to process many at once
    public static List<Result> generateReports(List<String> predictionRecordIds) {
        List<Result> results = new List<Result>();
        for (String id : predictionRecordIds) {
            results.add(generateReport(id));
        }
        return results;
    }
}