public with sharing class MetadataSelector {
    public static List<SObject> selectApexMetadata(String metadataType) {
        String query = 'SELECT Id, Name FROM ' + metadataType + ' ORDER BY Name';
        return Database.query(query);
    }

    public static List<Object> selectToolingApi(String metadataType) {
        String toolingQuery = 'SELECT Id, DeveloperName FROM ' + metadataType;
        return MetadataToolingApi.call(toolingQuery);
    }

    public static List<Object> selectDependecies(String metadata) {
        String toolingQuery  = 'SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType, ' +
        'RefMetadataComponentId, RefMetadataComponentName, RefMetadataComponentType ' +
        'FROM MetadataComponentDependency ' + 
        'WHERE RefMetadataComponentType = \'' + metadata + '\'';
        
        return MetadataToolingApi.call(toolingQuery);
    }
}