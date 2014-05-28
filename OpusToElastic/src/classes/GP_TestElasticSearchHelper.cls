@isTest
global class GP_TestElasticSearchHelper{
    
    /*static testMethod void testInsert() {
        List<GR_Project__c> projects = new List<GR_Project__c>();
        projects.add(GR_TestDataHelper.createAndInsertProject('Test Project 1'));  
        
        string ep = GR_Constants.ELASTIC_SEARCH_ENDPOINT;
        ep += (ep.endsWith('/') ? '' : '/') + '_bulk';  
    
        // Set mock callout class 
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('PUT', ep));
    
        // Call method to test. This causes a fake response to be sent from the class that implements HttpCalloutMock. 
        GP_ElasticSearchHelper.insertProjects(projects);
    }*/
    
    static testMethod void testUpdate() {       
        Test.startTest();
        string ep = GR_Constants.ELASTIC_SEARCH_ENDPOINT;
        ep += (ep.endsWith('/') ? '' : '/') + '_bulk';  
        
        // Set mock callout class 
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('PUT', ep));
        
        GR_TestDataHelper.addProjectEvents();
            
        GR_Project__c project = new GR_Project__c(Name='Test project 1', RecordTypeId=GR_RecordTypeHelper.getProjectProjectRTId(), Publish__c=false);
        insert project;
        
        List<GR_Project__c> projects = new List<GR_Project__c>();
        projects.add(project);
                        
        //project name, proposal, site      
        GR_Office__c defaultOffice = GR_TestDataHelper.createAndInsertOffice(GR_Constants.DEFAULT_OFFICE, 12345);
        GR_lu_County__c county = GR_TestDataHelper.createAndInsertCounty('1', 'Test county');
        GR_lu_Town__c town = GR_TestDataHelper.createAndInsertTown('Test town', '1', county.Id);
        GR_Site__c site = GR_TestDataHelper.createAndInsertSite(town.Id);
                
        GR_Proposal__c proposal1 = GR_TestDataHelper.createAndInsertProposal('Test planning ref 1');
        GR_Proposal__c proposal2 = GR_TestDataHelper.createAndInsertProposal('Test planning ref 2');        
        GR_SiteProjectLink__c spl1 = GR_TestDataHelper.createAndInsertSiteProjectLink(projects[0].Id, site.Id, proposal1.Id);
        GR_SiteProjectLink__c spl2 = GR_TestDataHelper.createAndInsertSiteProjectLink(projects[0].Id, site.Id, proposal2.Id);
        
        spl2.ActiveProposal__c = true;
        update proposal2;
        
        //categories
        GR_lu_Category__c category1 = GR_TestDataHelper.createAndInsertCategory('My test category 1', false);
        GR_lu_Category__c category2 = GR_TestDataHelper.createAndInsertCategory('My test category 2', false);
        GR_lu_RecallSector__c sector = new GR_lu_RecallSector__c (Name = 'Indistrial', Description__c = 'description1', ExternalId__c=33);
        insert sector;
        category1.RecallSector__c = sector.Id;
        category2.RecallSector__c = sector.Id;
        update category1;
        update category2;
        GR_ProjectCategory__c projectCategory1 = GR_TestDataHelper.createAndInsertProjectCategory(projects[0].Id, category1.Id);
        GR_ProjectCategory__c projectCategory2 = GR_TestDataHelper.createAndInsertProjectCategory(projects[0].Id, category2.Id);
        projectCategory1.CategoryRankNumber__c = 1;
        update projectCategory1;
        
        //materials
        GR_lu_Material__c  material1 = GR_TestDataHelper.createAndInsert_lu_Material('mat11');
        GR_lu_Material__c  material2 = GR_TestDataHelper.createAndInsert_lu_Material('mat12');
        GR_TestDataHelper.createAndInsertProjectMaterial(material1.Id, projects[0].Id);
        GR_TestDataHelper.createAndInsertProjectMaterial(material2.Id, projects[0].Id);
        
        //roles        
        GR_lu_RoleGroup__c prom = GR_TestDataHelper.createAndInsertRoleGroup('Promoters', 10);
        GR_lu_Role__c role = GR_TestDataHelper.createAndInsertRole('Test role', prom.id, 923);
        GR_lu_ContractStage__c stage = GR_TestDataHelper.createAndInsertContractStage('TestStage', 34);
        GR_Contract__c contract1 = GR_TestDataHelper.createAndInsertContract(projects[0].Id, defaultOffice.Id, role.Id);
        
        GR_Office__c newOffice = GR_TestDataHelper.createAndInsertOffice('New Office', 67890);
        GR_Contract__c contract2 = GR_TestDataHelper.createAndInsertContract(projects[0].Id, newOffice.Id, role.Id);
        
        //contacts
        GR_Contact__c contact1 = GR_TestDataHelper.createAndAddContactToOffice('Test contact 1', 'testcontact1@alamo.com', defaultOffice.Id);
        GR_ContractContact__c contractcontact1 = GR_TestDataHelper.createAndInsertContractContact(contract1.Id, contact1.Id);
        
        GR_Contact__c contact3 = GR_TestDataHelper.createAndAddContactToOffice('Test contact 3', 'testcontact3@alamo.com', newOffice.Id);
        GR_ContractContact__c contractcontact3 = GR_TestDataHelper.createAndInsertContractContact(contract2.Id, contact3.Id);
                
        //project events
        GR_ProjectEvent__c newEvent = GR_ProjectEventUpdater.GetEvent_NewProject(projects[0].Id);
        insert newEvent;
        
        projects[0].Name = 'Test project 1a';
        update projects[0];
                
        //GP_ElasticSearchHelper.updateProjects(projects);      
        Test.stopTest(); //ensure @future calls have completed before asserting
    }
    
    global class MockHttpResponseGenerator implements HttpCalloutMock {
        private string verb;
        private string endpoint;
        
        public MockHttpResponseGenerator(string v, string ep){
            verb = v;
            endpoint = ep;
        }
        
        // Implement this interface method
        global HTTPResponse respond(HTTPRequest req) {
            // Optionally, only send a mock response for a specific endpoint and method.
            System.assertEquals(endpoint, req.getEndpoint());
            System.assertEquals(verb, req.getMethod());
    
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"foo":"bar"}');
            res.setStatusCode(200);
            return res;
        }
    }
}