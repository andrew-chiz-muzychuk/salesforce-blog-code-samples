public class PicklistDependencyHandler {
    
    /**
     * Retrieves dependent picklist values for a given record type
     * Uses the new Spring '26 ConnectApi.RecordUi.getPicklistValuesByRecordType method
     * 
     * @param objectApiName - API name of the object (e.g., 'Account', 'CustomObject__c')
     * @param recordTypeApiName - API name of the record type (e.g., 'Master', 'RecordTypeA')
     * @param picklistFieldApiName - API name of the controlling picklist field
     * @param dependentPicklistFieldApiName - API name of the dependent picklist field
     * @return Map where key is controlling picklist value, value is list of dependent picklist values
     */
    public static Map<String, List<String>> getPicklistDependencies(
        String objectApiName,
        String recordTypeApiName,
        String picklistFieldApiName,
        String dependentPicklistFieldApiName
    ) {
        Map<String, List<String>> dependencyMap = new Map<String, List<String>>();
        
        try {
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
                return dependencyMap;
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
            
        } catch (Exception e) {
            System.debug('Error retrieving picklist dependencies: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return dependencyMap;
    }
    
    /**
     * Example usage and test method
     */
    public static void exampleUsage() {
        // Example: Get dependencies for a custom object
        Map<String, List<String>> dependencies = getPicklistDependencies(
            'CustomObject__c',      // Object API Name
            'RecordTypeA',          // Record Type API Name
            'PicklistA__c',         // Controlling Picklist Field
            'PicklistB__c'          // Dependent Picklist Field
        );
        
        // Print results
        System.debug('Picklist Dependencies:');
        for (String controllingValue : dependencies.keySet()) {
            System.debug('Controlling Value: ' + controllingValue);
            System.debug('  Dependent Values: ' + dependencies.get(controllingValue));
        }
    }
}