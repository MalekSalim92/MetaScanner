public with sharing class MetadataToolingApi {
    public static List<Object> call(String toolingQuery) {
        List<Object> metadataList = new List<Object>();
 
        // Build REST endpoint for Tooling API query,
        // Prepare HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:toolingApi/services/data/v58.0/tooling/query/?q=' + EncodingUtil.urlEncode(toolingQuery,'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        System.debug('req ' + req);

        HttpResponse res = http.send(req);
        System.debug('res ' + res);

        if (res.getStatusCode() == 200) {
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            metadataList = (List<Object>) resultMap.get('records');
 
        } else {
            throw new AuraHandledException('Tooling API call failed: ' + res.getStatus() + ' ' + res.getBody());
        }

        return metadataList;
    }


}