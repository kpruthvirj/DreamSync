public with sharing class EmissionReportPdfGenerator {

    public class Request {
        @InvocableVariable(required=true label='Batch ID' description='The Batch ID to generate a report for, e.g. BATCH-1006. This matches the Name field on Emission_Prediction__c.')
        public String batchId;
    }

    public class Response {
        @InvocableVariable(label='Content Document Id')
        public String contentDocumentId;

        @InvocableVariable(label='Download URL')
        public String downloadUrl;

        @InvocableVariable(label='Status Message')
        public String statusMessage;
    }

    @InvocableMethod(
        label='Generate Emission Report PDF'
        description='Looks up an Emission Prediction record by Batch ID (Name field) and generates a downloadable PDF report summarizing its prediction, drivers, and recommendations.'
    )
    public static List<Response> generateReport(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response resp = new Response();
            try {
                if (String.isBlank(req.batchId)) {
                    resp.statusMessage = 'No Batch ID was provided. Please provide a valid Batch ID, e.g. BATCH-1006.';
                    responses.add(resp);
                    continue;
                }

                // Look up the Emission_Prediction__c record by Name (the Batch ID)
                List<Emission_Prediction__c> matches = [
                    SELECT Id, Name
                    FROM Emission_Prediction__c
                    WHERE Name = :req.batchId
                    LIMIT 1
                ];

                if (matches.isEmpty()) {
                    resp.statusMessage = 'No prediction record found for Batch ID "' + req.batchId + '". Please check the Batch ID and try again.';
                    responses.add(resp);
                    continue;
                }

                Id predictionRecordId = matches[0].Id;

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
                cv.Title = 'Emission_Report_' + req.batchId;
                cv.PathOnClient = 'Emission_Report_' + req.batchId + '.pdf';
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
                resp.statusMessage = 'Report generated successfully for Batch ID ' + req.batchId + '.';

            } catch (Exception e) {
                resp.statusMessage = 'Failed to generate report for Batch ID "' + req.batchId + '": ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }
}