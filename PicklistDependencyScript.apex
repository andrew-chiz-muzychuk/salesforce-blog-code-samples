
String objectApiName = 'CustomObject__c';
String recordTypeApiName = 'RecordTypeA';
// String picklistFieldApiName = 'PicklistA__c';
String picklistFieldApiName = 'PicklistB__c';
// String dependentPicklistFieldApiName = 'PicklistB__c';
String dependentPicklistFieldApiName = 'PicklistC__c';

Map<String, List<String>> dependencyMap = new Map<String, List<String>>();

// Get the Record Type Id from the API name
Id recordTypeId = Schema.getGlobalDescribe()
    .get(objectApiName)
    .getDescribe()
    .getRecordTypeInfosByName()
    .get(recordTypeApiName)
    .getRecordTypeId();

// Call the new Spring '26 method to get picklist values by record type
ConnectApi.PicklistValuesCollection picklistCollection = 
    ConnectApi.RecordUi.getPicklistValuesByRecordType(objectApiName, recordTypeId);

// Get the controlling picklist field values
ConnectApi.PicklistValues controllingPicklist = 
    picklistCollection.picklistFieldValues.get(picklistFieldApiName);

// Get the dependent picklist field values
ConnectApi.PicklistValues dependentPicklist = 
    picklistCollection.picklistFieldValues.get(dependentPicklistFieldApiName);

if (controllingPicklist == null || dependentPicklist == null) {
    System.debug('One or both picklist fields not found in record type');
    return;
}

// Check if there's actually a dependency configured
// If no dependent value has a validFor property, there's no dependency
Boolean hasDependency = false;
for (ConnectApi.PicklistValue dependentValue : dependentPicklist.values) {
    if (dependentValue.validFor != null && !dependentValue.validFor.isEmpty()) {
        hasDependency = true;
        break;
    }
}

// Build the dependency map
// First, initialize the map with all controlling values
for (ConnectApi.PicklistValue controllingValue : controllingPicklist.values) {
    dependencyMap.put(controllingValue.value, new List<String>());
}

if (hasDependency) {
    // There is a configured dependency - map dependent values to their controlling values
    for (ConnectApi.PicklistValue dependentValue : dependentPicklist.values) {
        if (dependentValue.validFor != null && !dependentValue.validFor.isEmpty()) {
            // validFor contains the indices of controlling values that this dependent value is valid for
            for (Integer validForIndex : dependentValue.validFor) {
                String controllingValueKey = controllingPicklist.values[validForIndex].value;
                if (dependencyMap.containsKey(controllingValueKey)) {
                    dependencyMap.get(controllingValueKey).add(dependentValue.value);
                }
            }
        }
    }
} else {
    // No dependency configured - return all dependent values for each controlling value
    List<String> allDependentValues = new List<String>();
    for (ConnectApi.PicklistValue dependentValue : dependentPicklist.values) {
        allDependentValues.add(dependentValue.value);
    }
    
    // Assign all dependent values to each controlling value
    for (String controllingValue : dependencyMap.keySet()) {
        dependencyMap.put(controllingValue, allDependentValues.clone());
    }
}

System.debug('dependencyMap: ' + dependencyMap);