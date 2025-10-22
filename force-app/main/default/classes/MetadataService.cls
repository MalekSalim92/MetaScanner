public with sharing class MetadataService {
    public static final String BASE_URL = URL.getOrgDomainUrl().toExternalForm();

    @AuraEnabled (cacheable=true)
    public static List<MetadataItem> fetchMetadataItems(String metadataType) {
        List<MetadataItem> metadataItems = new List<MetadataItem>();

        try {
           
            if (!ALLOWED_METADATA_TYPES.contains(metadataType)) throw new AuraHandledException('Invalid metadata type: ' + metadataType);
            if (metadataType.startsWith('Apex')) return fetchApex(metadataType);
            else return metadataItems = fetchMetadataTooling(metadataType);
        
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching metadata: ' + e.getMessage());
        }

    }


    // Fetch APEX  
    private static List<MetadataItem> fetchApex(String metadataType) {
    
        List<MetadataItem> items = new List<MetadataItem>();
        List<SObject> apexItems = MetadataSelector.selectApexMetadata(metadataType);
        for (SObject sObj : apexItems) {
            items.add(new MetadataItem(
                (String)sObj.get('Id'),
                (String)sObj.get('Name'),
                BASE_URL + '/' + (String)sObj.get('Id')

            ));
        }
        
        return items;
    }
 

    //Fetch Metadata with tooling API 

    private static List<MetadataItem> fetchMetadataTooling(String metadataType) {
        List<MetadataItem> metadataList = new List<MetadataItem>();
       
        List<Object> records = MetadataSelector.selectToolingApi(metadataType);
        for (Object o : records) {
            Map<String, Object> r = (Map<String, Object>) o;
            metadataList.add(new MetadataItem(
                (String) r.get('Id'),
                (String) r.get('DeveloperName'),
                BASE_URL + '/' + (String)r.get('Id')

            ));
         
    }
    return metadataList;

}

@AuraEnabled (cacheable=true)
public static List<metadataDependecy> getDependencies(String metadataType){
    List<metadataDependecy> dependencyList = new List<metadataDependecy>();

    for(String metadata : ALLOWED_METADATA_TYPES){

        List<Object> records = MetadataSelector.selectDependecies(metadata);
      for (Object o : records) {
          Map<String, Object> r = (Map<String, Object>) o;
          dependencyList.add(new metadataDependecy(
              (String) r.get('MetadataComponentId'),
              (String) r.get('MetadataComponentName'),
              (String) r.get('MetadataComponentType'),
              (String) r.get('RefMetadataComponentId'),
              (String) r.get('RefMetadataComponentName'),
              (String) r.get('RefMetadataComponentType'),
              BASE_URL + '/' + (String)r.get('MetadataComponentId')

          ));
  }
    }

    return dependencyList;
                      
        }
                      

 
 // Wrapper class for metadata dependencies
 public class metadataDependecy{
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public String type { get; set; }
    @AuraEnabled public String refId { get; set; }
    @AuraEnabled public String refName { get; set; }
    @AuraEnabled public String refType { get; set; }
    @AuraEnabled public String link { get; set; }

     
    public metadataDependecy(String id, String name, String type, String refId, String refName, String refType, String link) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.refId = refId;
        this.refName = refName;
        this.refType = refType;
        this.link = link;
     }
}





 // Wrapper class for metadata items
 public class MetadataItem {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String developerName { get; set; }
    @AuraEnabled public String link { get; set; }
     
    public MetadataItem(String id, String developerName, String link) {
        this.id = id;
        this.developerName = developerName;
        this.link = link;
     }
}

@AuraEnabled(cacheable=true)
public static MetadataAccessResponse getMetadataAccess(String metadataType, String metadataId) {
    
    // Route to appropriate method based on metadata type
    if (metadataType == 'ApexClass') {
        return getApexClassAccess(metadataId);
    } else if (metadataType == 'CustomObject') {
        return getObjectAccess(metadataId);
    } else if (metadataType == 'CustomField') {
        return getFieldAccess(metadataId);
    }
    
    // For unsupported types
    return new MetadataAccessResponse('simple', new List<MetadataAccess>());
}

// Apex Class Access - Simple Yes/No
private static MetadataAccessResponse getApexClassAccess(String apexClassId) {
    List<PermissionSet> permSets = [
        SELECT Id, Name, ProfileId, Profile.Name 
        FROM PermissionSet
    ];
    
    Map<Id, String> permSetNames = new Map<Id, String>();
    Map<Id, String> permSetTypes = new Map<Id, String>();
    
    for (PermissionSet ps : permSets) {
        if (ps.ProfileId != null) {
            permSetNames.put(ps.Id, ps.Profile.Name);
            permSetTypes.put(ps.Id, 'Profile');
        } else {
            permSetNames.put(ps.Id, ps.Name);
            permSetTypes.put(ps.Id, 'Permission Set');
        }
    }

    List<SetupEntityAccess> accessList = [
        SELECT ParentId, SetupEntityId 
        FROM SetupEntityAccess
        WHERE SetupEntityType = 'ApexClass'
          AND SetupEntityId = :apexClassId
          AND ParentId IN :permSetNames.keySet()
    ];

    Set<Id> accessParentIds = new Set<Id>();
    for (SetupEntityAccess sea : accessList) {
        accessParentIds.add(sea.ParentId);
    }

    List<MetadataAccess> result = new List<MetadataAccess>();
    for (Id psId : permSetNames.keySet()) {
        Boolean hasAccess = accessParentIds.contains(psId);
        result.add(new MetadataAccess(
            psId,
            permSetNames.get(psId),
            permSetTypes.get(psId),
            hasAccess,
            null, null, null, null
        ));
    }

    return new MetadataAccessResponse('simple', result);
}

// Custom Object Access - CRUD permissions
private static MetadataAccessResponse getObjectAccess(String objectId) {
    // Get the SObject API name from the CustomObject Id
    String objectApiName;
    try {
        List<EntityDefinition> entities = [
            SELECT QualifiedApiName 
            FROM EntityDefinition 
            WHERE DurableId = :objectId 
            LIMIT 1
        ];
        if (entities.isEmpty()) return new MetadataAccessResponse('crud', new List<MetadataAccess>());
        objectApiName = entities[0].QualifiedApiName;
    } catch (Exception e) {
        return new MetadataAccessResponse('crud', new List<MetadataAccess>());
    }

    List<PermissionSet> permSets = [
        SELECT Id, Name, ProfileId, Profile.Name 
        FROM PermissionSet
    ];
    
    Map<Id, String> permSetNames = new Map<Id, String>();
    Map<Id, String> permSetTypes = new Map<Id, String>();
    
    for (PermissionSet ps : permSets) {
        if (ps.ProfileId != null) {
            permSetNames.put(ps.Id, ps.Profile.Name);
            permSetTypes.put(ps.Id, 'Profile');
        } else {
            permSetNames.put(ps.Id, ps.Name);
            permSetTypes.put(ps.Id, 'Permission Set');
        }
    }

    // Query ObjectPermissions for this object
    List<ObjectPermissions> objPerms = [
        SELECT ParentId, 
               PermissionsRead, 
               PermissionsCreate, 
               PermissionsEdit, 
               PermissionsDelete
        FROM ObjectPermissions
        WHERE SobjectType = :objectApiName
          AND ParentId IN :permSetNames.keySet()
    ];

    Map<Id, ObjectPermissions> permsByParentId = new Map<Id, ObjectPermissions>();
    for (ObjectPermissions op : objPerms) {
        permsByParentId.put(op.ParentId, op);
    }

    List<MetadataAccess> result = new List<MetadataAccess>();
    for (Id psId : permSetNames.keySet()) {
        ObjectPermissions op = permsByParentId.get(psId);
        
        result.add(new MetadataAccess(
            psId,
            permSetNames.get(psId),
            permSetTypes.get(psId),
            null, // hasAccess not used for CRUD
            op != null ? op.PermissionsRead : false,
            op != null ? op.PermissionsCreate : false,
            op != null ? op.PermissionsEdit : false,
            op != null ? op.PermissionsDelete : false
        ));
    }

    return new MetadataAccessResponse('crud', result);
}

// Custom Field Access - CRUD permissions
private static MetadataAccessResponse getFieldAccess(String fieldId) {
    // Get the field's object and field API name
    String objectApiName;
    String fieldApiName;
    
    try {
        List<FieldDefinition> fields = [
            SELECT QualifiedApiName, EntityDefinition.QualifiedApiName
            FROM FieldDefinition 
            WHERE DurableId = :fieldId 
            LIMIT 1
        ];
        if (fields.isEmpty()) return new MetadataAccessResponse('crud', new List<MetadataAccess>());
        
        objectApiName = fields[0].EntityDefinition.QualifiedApiName;
        fieldApiName = fields[0].QualifiedApiName;
    } catch (Exception e) {
        return new MetadataAccessResponse('crud', new List<MetadataAccess>());
    }

    List<PermissionSet> permSets = [
        SELECT Id, Name, ProfileId, Profile.Name 
        FROM PermissionSet
    ];
    
    Map<Id, String> permSetNames = new Map<Id, String>();
    Map<Id, String> permSetTypes = new Map<Id, String>();
    
    for (PermissionSet ps : permSets) {
        if (ps.ProfileId != null) {
            permSetNames.put(ps.Id, ps.Profile.Name);
            permSetTypes.put(ps.Id, 'Profile');
        } else {
            permSetNames.put(ps.Id, ps.Name);
            permSetTypes.put(ps.Id, 'Permission Set');
        }
    }

    // Query FieldPermissions for this field
    List<FieldPermissions> fieldPerms = [
        SELECT ParentId, 
               PermissionsRead, 
               PermissionsEdit
        FROM FieldPermissions
        WHERE SobjectType = :objectApiName
          AND Field = :fieldApiName
          AND ParentId IN :permSetNames.keySet()
    ];

    Map<Id, FieldPermissions> permsByParentId = new Map<Id, FieldPermissions>();
    for (FieldPermissions fp : fieldPerms) {
        permsByParentId.put(fp.ParentId, fp);
    }

    List<MetadataAccess> result = new List<MetadataAccess>();
    for (Id psId : permSetNames.keySet()) {
        FieldPermissions fp = permsByParentId.get(psId);
        
        result.add(new MetadataAccess(
            psId,
            permSetNames.get(psId),
            permSetTypes.get(psId),
            null, // hasAccess not used for fields
            fp != null ? fp.PermissionsRead : false,
            null, // Fields don't have Create permission
            fp != null ? fp.PermissionsEdit : false,
            null  // Fields don't have Delete permission
        ));
    }

    return new MetadataAccessResponse('crud', result);
}

// Wrapper class for the response
public class MetadataAccessResponse {
    @AuraEnabled public String displayType { get; set; } // 'simple' or 'crud'
    @AuraEnabled public List<MetadataAccess> records { get; set; }
    
    public MetadataAccessResponse(String displayType, List<MetadataAccess> records) {
        this.displayType = displayType;
        this.records = records;
    }
}

// Updated wrapper class for access records
public class MetadataAccess {
    @AuraEnabled public String id { get; set; }
    @AuraEnabled public String name { get; set; }
    @AuraEnabled public String type { get; set; }
    @AuraEnabled public Boolean hasAccess { get; set; }  // For simple access (Apex)
    @AuraEnabled public Boolean permRead { get; set; }    // For CRUD
    @AuraEnabled public Boolean permCreate { get; set; }  // For CRUD
    @AuraEnabled public Boolean permEdit { get; set; }    // For CRUD
    @AuraEnabled public Boolean permDelete { get; set; }  // For CRUD

    public MetadataAccess(String id, String name, String type, Boolean hasAccess, 
                          Boolean permRead, Boolean permCreate, Boolean permEdit, Boolean permDelete) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.hasAccess = hasAccess;
        this.permRead = permRead;
        this.permCreate = permCreate;
        this.permEdit = permEdit;
        this.permDelete = permDelete;
    }
}

private static final Set<String> ALLOWED_METADATA_TYPES = new Set<String>{
    'ApexClass',
    'ApexTrigger',
    'CustomObject',
    'CustomField',
    'FlowDefinition',
    'LightningComponentBundle'
};

}