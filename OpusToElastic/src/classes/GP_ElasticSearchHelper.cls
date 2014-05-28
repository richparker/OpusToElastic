global class GP_ElasticSearchHelper {
    
    public static string indexName { get { return GR_Constants.ELASTIC_SEARCH_INDEX; } }
    public static string indexType { get { return GR_Constants.ELASTIC_SEARCH_TYPE; } }
    public static string indexEndPoint { 
        get { 
            string ep = GR_Constants.ELASTIC_SEARCH_ENDPOINT;
            return ep + (ep.endsWith('/') ? '' : '/') + '_bulk';            
        } 
    }
    
    public static void insertProjects(List<GR_Project__c> projects){      
        List<string> projectIds = new List<string>();
        for (GR_Project__c project : projects){
            projectIds.add(project.Id);
        }
        insertProjects(projectIds);
        
        // why can't i upload this to git?
    }
    
    public static void insertProjects(List<string> projectIds){                     
        string jsonProjects = mapProjects(projectIds, indexName, indexType, 'create');
        if (!string.isBlank(jsonProjects)){
            indexApply(jsonProjects, indexEndPoint, 'create');
        }
    }
    
    public static void updateProjects(List<GR_Project__c> projects){ 
        List<string> projectIds = new List<string>();
        for (GR_Project__c project : projects){
            projectIds.add(project.Id);
        }
        updateProjects(projectIds);
    }
    
    public static void updateProjects(List<string> projectIds){ 
        string jsonProjects = mapProjects(projectIds, indexName, indexType, 'update');
        system.debug('RP: GR_ElasticSearchHelper.updateProjects() - jsonProjects = ' + jsonProjects);
        if (!string.isBlank(jsonProjects)){         
            indexApply(jsonProjects, indexEndPoint, 'update');
        }
    }
    
    public static void insertProject(string projectId){                     
        List<string> projectIds = new List<string>();
        projectIds.add(projectId);
        string jsonProjects = mapProjects(projectIds, indexName, indexType, 'create');
        if (!string.isBlank(jsonProjects)){
            indexApply(jsonProjects, indexEndPoint, 'create');
        }
    }
    
    public static void updateProject(string projectId){             
        List<string> projectIds = new List<string>();
        projectIds.add(projectId);
        string jsonProjects = mapProjects(projectIds, indexName, indexType, 'update');
        system.debug('RP: GR_ElasticSearchHelper.updateProjects() - jsonProjects = ' + jsonProjects);
        if (!string.isBlank(jsonProjects)){         
            indexApply(jsonProjects, indexEndPoint, 'update');
        }
    }
    
    @future (callout=true)
    private static void indexApply(string jsonProjects, string endPoint, string operation){
        Http http = new Http();
        HttpRequest req = new HttpRequest();            
        req.setEndPoint(endPoint);
        
        // set auth credentials  
        Blob authHeaderValue = Blob.valueOf(GR_Constants.ELASTIC_SEARCH_USERNAME+':'+GR_Constants.ELASTIC_SEARCH_PASSWORD);
        string authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(authHeaderValue);
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Content-Type','application/json');
        req.setHeader('Accept','application/json');
        req.setMethod('PUT');
        req.setBody(jsonProjects); 
        //req.setCompressed(true); // otherwise we hit a limit of 32000, must support gzip
        
        GR_ElasticIndexHistory__c history = new GR_ElasticIndexHistory__c();
        history.ObjectName__c = 'GR_Project__c';
        history.Operation__c = operation;
        history.Json__c = jsonProjects;
        
        try{
            HTTPResponse resp = http.send(req);
            if(resp.getStatusCode() == 200){ 
                system.debug('Authentication success!!!' + resp);    
                history.Status__c =  resp.getStatusCode();
                history.HttpResponse__c = resp.toString(); 
            } else {
            }    
        } catch(exception e){
            system.debug('Insert failed!!!' + e.getMessage());
            history.Error__c = e.getMessage();
        }       
        insert history;
    }
    
    private static string mapProjects(List<string> projectIds, string elasticIndexName, string elasticItemTypeName, string operation){      
        List<GR_Project__c> projects = [SELECT Id, ProjectIdPublish__c, Name, Value__c, ValueType__c, ProjectSize__c, DevelopmentType__c, ProjectStatus__r.Name,
                                                    EndDateType__c, StartDateType__c, ContractStage__c, PlanningStage__c, Units__c, Storeys__c,
                                                    (SELECT Category__r.CategoryGroup__c, Category__r.Name, CategoryRankNumber__c FROM ProjectProjectCategories__r),
                                                    (SELECT Material__c, Material__r.Name, Material__r.MaterialGroup__r.Name FROM ProjectProjectMaterials__r),
                                                    (SELECT CreatedDate, CreatedById, NewValue__c, OldValue__c, Event__r.ExternalId__c FROM ProjectProjectEvents__r)
                                                        FROM GR_Project__c
                                                        WHERE Id IN :projectIds];
        
        List<GR_SiteProjectLink__c> siteProjLinks = [SELECT ActiveProposal__c, Project__c,
                                                            Proposal__r.PlanningReference__c, Proposal__r.LeadApplication__c, Proposal__r.Name, Proposal__r.ApplicationDate__c, Proposal__r.PlanningStage__c, Proposal__r.PlanningType__c, Proposal__r.Description__c,
                                                            Proposal__r.LocalAuthority__r.Name, Proposal__r.Applicant__r.Name, Proposal__r.Applicant__r.Company__r.Name, Proposal__r.Applicant__r.Address1__c, Proposal__r.Applicant__r.Postcode__c,
                                                            Proposal__r.Applicant__r.TownName__c, Proposal__r.Applicant__r.SubDistrict__c, Proposal__r.Applicant__r.CountyName__c, Proposal__r.Applicant__r.Phone1__c, Proposal__r.Applicant__r.OfficeGeoLocation__Latitude__s, Proposal__r.Applicant__r.OfficeGeolocation__Longitude__s, 
                                                            Site__r.Address1__c, Site__r.CountyName__c, Site__r.PostCode__c, Site__r.District__c, Site__r.TownName__c, Site__r.SiteGeoLocation__Latitude__s, Site__r.SiteGeoLocation__Longitude__s
                                                        FROM GR_SiteProjectLink__c
                                                        WHERE Project__c IN :projectIds];
                                                        
        Map<String, List<GR_RoleHelper.ContactInfo>> contactListMap = new Map<String, List<GR_RoleHelper.ContactInfo>>();
        Map<String, GR_Contact__c> contactMap = new Map<String, GR_Contact__c>();
        Map<String, GR_Office__c> officeMap = new Map<String, GR_Office__c>();
        //List<GR_RoleHelper.RoleGroupInfo> contracts = GR_RoleHelper.GetRoleGroupsForProjects(projectIds, contactListMap, contactMap, officeMap);
        Map<string, List<GR_RoleHelper.RoleGroupInfo>> contracts = GR_RoleHelper.GetRoleGroupsForProjects(projectIds, contactListMap, contactMap, officeMap);
        
        Map<Id, List<GR_SiteProjectLink__c>> mapSiteProjectLinks = new Map<Id, List<GR_SiteProjectLink__c>>();
        for (GR_Project__c project : projects){         
            for (GR_SiteProjectLink__c spl : siteProjLinks){
                if (spl.Project__c == project.Id){                  
                    List<GR_SiteProjectLink__c> projLinks = mapSiteProjectLinks.get(project.Id);
                    
                    if (projLinks != null){
                        projLinks.add(spl);
                    } else {
                        projLinks = new List<GR_SiteProjectLink__c>();
                        projLinks.add(spl);
                    }                                       
                    mapSiteProjectLinks.put(project.Id, projLinks);
                }
            }
        }
        
        string jsonProjects = '';   
        for (GR_Project__c project : projects){  
            GR_SiteProjectLink__c activeProposal = new GR_SiteProjectLink__c(); 
            Id latestApplicationId = null;
            Date latestApplicationDate = null;
            
            List<GR_SiteProjectLink__c> projLinks = mapSiteProjectLinks.get(project.Id);
            if (projLinks != null){
                for (GR_SiteProjectLink__c spl : projLinks){
                    if (spl.ActiveProposal__c == true){
                        activeProposal = spl;
                    }
                    
                    if (latestApplicationDate == null || latestApplicationDate > spl.Proposal__r.ApplicationDate__c){
                        latestApplicationDate = spl.Proposal__r.ApplicationDate__c;
                        latestApplicationId = spl.Proposal__c;
                    }
                }
            }
            
            List<Note> latestNotes = [SELECT Body FROM Note WHERE ParentId = :project.Id AND Title = :GR_Constants.LATAST_NOTES];
            
            ElasticProject eProject = new ElasticProject();

            eProject.ProjectId = project.ProjectIdPublish__c;
            eProject.Heading = project.Name;
            //eProject.IsArchived = ; //TODO
            eProject.Value = project.Value__c;
            eProject.ValueType = project.ValueType__c;
            eProject.ProjectSize = project.ProjectSize__c;
            //eProject.ContractType = ; //TODO
            //eProject.ContractPeriod = ; //TODO
            eProject.DevelopmentTypeId = project.DevelopmentType__c;
            eProject.ProjectStatusId = project.ProjectStatus__r.Name;
            eProject.EndDateType = project.EndDateType__c;
            eProject.StartDateType = project.StartDateType__c;
            eProject.ContractStageId = project.ContractStage__c;
            eProject.PlanningStageId = project.PlanningStage__c;
            eProject.SiteArea = activeProposal.Site__r.Area__c;
            eProject.Units = project.Units__c;
            eProject.Storeys = project.Storeys__c;
            eProject.Address = activeProposal.Site__r.Address1__c;
            eProject.Borough = activeProposal.Proposal__r.LocalAuthority__r.Name;
            eProject.County = activeProposal.Site__r.CountyName__c;
            eProject.Postcode = activeProposal.Site__r.PostCode__c;
            eProject.Region = activeProposal.Site__r.District__c;
            eProject.Town = activeProposal.Site__r.TownName__c;
            eProject.Latitude = activeProposal.Site__r.SiteGeoLocation__Latitude__s;
            eProject.Longitude = activeProposal.Site__r.SiteGeoLocation__Longitude__s;
            eProject.LatestInformation = (latestNotes.size() > 0 ? latestNotes[0].Body : '');
            eProject.PlanningDescription = activeProposal.Proposal__r.Description__c;
            //eProject.NotificationText = ; //TODO
            //eProject.TenderInformation = ; //TODO
            //eProject.SchemeDescription = ; //TODO
            //eProject.FirstPublished = ; //TODO
            //eProject.Updated = ; //TODO
            //eProject.RecallDate = ; //TODO
            //eProject.Funding = ; //TODO
            
            eProject.Breeam = new ElasticBreeam();
            eProject.Breeam.Test = ''; //TODO
            
            eProject.Ceequal = new ElasticCeequal(); //TODO
            eProject.Ceequal.Code = '';
            eProject.Ceequal.ForecastFinalVerification = '';
            eProject.Ceequal.AwardType = '';
            eProject.Ceequal.Version = '';
            eProject.Ceequal.InterimGrade = '';
            eProject.Ceequal.FinalGrade = '';
            eProject.Ceequal.InterimPercentage = '';
            eProject.Ceequal.FinalPercentage = '';
            
            //Categories
            eProject.Sectors = new List<ElasticSectorGroup>();
            if (project.ProjectProjectCategories__r.size() > 0){                            
                Map<string, List<GR_ProjectCategory__c>> mapCategories = new Map<string, List<GR_ProjectCategory__c>>();
                for (GR_ProjectCategory__c projCat : project.ProjectProjectCategories__r){
                    List<GR_ProjectCategory__c> cats;
                    if (mapCategories.containsKey(projCat.Category__r.CategoryGroup__c)){
                        cats = mapCategories.get(projCat.Category__r.CategoryGroup__c);
                        cats.add(projCat);
                    } else {
                        cats = new List<GR_ProjectCategory__c>();
                        cats.add(projCat);
                    }
                    mapCategories.put(projCat.Category__r.CategoryGroup__c, cats);                              
                }
                
                if (mapCategories.size() > 0){
                    eProject.Sectors = new List<ElasticSectorGroup>();
                    for (string catGroupName : mapCategories.keyset()){                     
                        ElasticSectorGroup sectorGroup = new ElasticSectorGroup();
                        sectorGroup.Name = catGroupName;
                        sectorGroup.Sectors = new List<ElasticSector>();
                        
                        for (GR_ProjectCategory__c projCat : mapCategories.get(catGroupName)){
                            ElasticSector sector = new ElasticSector();
                            sector.Name = projCat.Category__r.Name;
                            sector.Priority = projCat.CategoryRankNumber__c;
                            sector.IsPrimary = (projCat.CategoryRankNumber__c == 1 ? true : false);
                            sectorGroup.Sectors.add(sector);
                        }
                        eProject.Sectors.add(sectorGroup);
                    }
                }
            }               
                            
            //Materials
            eProject.Materials = new List<ElasticMaterialGroup>();
            if (project.ProjectProjectMaterials__r.size() > 0){                         
                Map<string, List<GR_lu_Material__c>> mapMaterials = new Map<string, List<GR_lu_Material__c>>();
                for (GR_ProjectMaterial__c projMaterial : project.ProjectProjectMaterials__r){
                    List<GR_lu_Material__c> materials;
                    if (mapMaterials.containsKey(projMaterial.Material__r.MaterialGroup__r.Name)){
                        materials = mapMaterials.get(projMaterial.Material__r.MaterialGroup__r.Name);
                        materials.add(projMaterial.Material__r);
                    } else {
                        materials = new List<GR_lu_Material__c>();
                        materials.add(projMaterial.Material__r);
                    }
                    mapMaterials.put(projMaterial.Material__r.MaterialGroup__r.Name, materials);                                
                }
                
                if (mapMaterials.size() > 0){
                    for (string materialGroupName : mapMaterials.keyset()){
                        ElasticMaterialGroup materialGroup = new ElasticMaterialGroup();
                        materialGroup.MaterialGroupName = materialGroupName;
                        materialGroup.Materials = new List<ElasticMaterial>();
                        
                        for (GR_lu_Material__c groupMaterial : mapMaterials.get(materialGroupName)){
                            ElasticMaterial material = new ElasticMaterial();
                            material.Name = groupMaterial.Name;
                            materialGroup.Materials.add(material);
                        }               
                        eProject.Materials.add(materialGroup);  
                    }
                }
            }
                            
            //Roles 
            eProject.Roles = new List<ElasticRoleGroup>();
            if (contracts.size() > 0 && contracts.containsKey(project.Id)){
                for (GR_RoleHelper.RoleGroupInfo projectRoleGroup : contracts.get(project.Id)){
                    ElasticRoleGroup roleGroup = new ElasticRoleGroup();
                    roleGroup.RoleGroupDescription = projectRoleGroup.groupName;
                    roleGroup.Roles = new List<ElasticRole>();
                                        
                    if (projectRoleGroup.offices.size() > 0){                                                   
                        //group office by role
                        Map<string, List<GR_RoleHelper.RoleOfficeInfo>> mapRoleOffice = new Map<string, List<GR_RoleHelper.RoleOfficeInfo>>();
                        for (GR_RoleHelper.RoleOfficeInfo roleOffice : projectRoleGroup.officeList){
                            List<GR_RoleHelper.RoleOfficeInfo> roleOffices;
                            if (mapRoleOffice.containsKey(roleOffice.roleName)){
                                roleOffices = mapRoleOffice.get(roleOffice.roleName);
                            }else {
                                roleOffices = new List<GR_RoleHelper.RoleOfficeInfo>();
                            }
                            roleOffices.add(roleOffice);
                            mapRoleOffice.put(roleOffice.roleName, roleOffices);
                        }
                        
                        for (string roleName : mapRoleOffice.keySet()){
                            ElasticRole role = new ElasticRole();
                            role.Role = roleName;
                            role.Companies = new List<ElasticCompany>();
                            
                            for (GR_RoleHelper.RoleOfficeInfo roleOffice : mapRoleOffice.get(roleName)){
                                ElasticCompany company = new ElasticCompany();
                                company.OfficeId = new ElasticOffice();
                                company.Contacts = new List<ElasticContact>();
                                
                                company.OfficeId.CompanyName = ''; //TODO
                                company.OfficeId.OfficeName = roleOffice.officeName;
                                company.OfficeId.AddressLine1 = roleOffice.officeAddress1;
                                //company.OfficeId.Postcode = roleOffice.officePostcode;
                                //company.OfficeId.Town = roleOffice.officeTown;
                                //company.OfficeId.Region = roleOffice.officeRegion;
                                //company.OfficeId.County = roleOffice.officeCounty;
                                company.OfficeId.PhoneNumber = roleOffice.sitePhone;
                                //company.OfficeId.Latitude = roleOffice.officeLatitude;
                                //company.OfficeId.Longitude = roleOffice.officeLongitude;
                                                                                                                        
                                for (GR_RoleHelper.ContactInfo contact : roleOffice.contacts){
                                    ElasticContact c = new ElasticContact();
                                    c.Salutation = contact.title;
                                    c.FirstName = contact.firstName;
                                    c.LastName = contact.lastName;
                                    c.JobTitle = contact.jobTitle;
                                    c.Email = contact.contractEmail;    
                                    company.Contacts.add(c);
                                }
                                role.Companies.add(company);
                            }
                            roleGroup.Roles.add(role);
                        }
                    }
                }
            }
                                    
            //Histories
            eProject.Histories = new List<ElasticHistory>();
            if (project.ProjectProjectEvents__r.size() > 0){
                for (GR_ProjectEvent__c projEvent : project.ProjectProjectEvents__r){
                    ElasticHistory history = new ElasticHistory();
                    history.Event = projEvent.Event__r.ExternalId__c;
                    history.Modified = projEvent.CreatedDate;
                    history.ModifiedBy = projEvent.CreatedById;
                    history.NewValue = projEvent.NewValue__c;
                    history.OldValue = projEvent.OldValue__c;
                    eProject.Histories.add(history);                                
                }
            }
                            
            //Applications
            eProject.Applications = new List<ElasticProposal>();
            if (projLinks != null){
                for (GR_SiteProjectLink__c spl : projLinks){
                    ElasticProposal proposal = new ElasticProposal();
                    proposal.ApplicationNumber = spl.Proposal__r.PlanningReference__c;
                    proposal.IsLatest = (spl.Proposal__c == latestApplicationId ? true : false);
                    proposal.IsLead = spl.Proposal__r.LeadApplication__c;
                    proposal.CouncilName = spl.Proposal__r.LocalAuthority__r.Name;
                    proposal.OfficeId = new ElasticOffice();                    
                    proposal.OfficeId.CompanyName = spl.Proposal__r.Applicant__r.Company__r.Name; //TODO
                    proposal.OfficeId.OfficeName = spl.Proposal__r.Applicant__r.Name;
                    proposal.OfficeId.AddressLine1 = spl.Proposal__r.Applicant__r.Address1__c;
                    proposal.OfficeId.Postcode = spl.Proposal__r.Applicant__r.Postcode__c;
                    proposal.OfficeId.Town = spl.Proposal__r.Applicant__r.TownName__c;
                    proposal.OfficeId.Region = spl.Proposal__r.Applicant__r.SubDistrict__c;
                    proposal.OfficeId.County = spl.Proposal__r.Applicant__r.CountyName__c;
                    proposal.OfficeId.PhoneNumber = spl.Proposal__r.Applicant__r.Phone1__c;
                    proposal.OfficeId.Latitude = spl.Proposal__r.Applicant__r.OfficeGeoLocation__Latitude__s;
                    proposal.OfficeId.Longitude = spl.Proposal__r.Applicant__r.OfficeGeolocation__Longitude__s;                                 
                    proposal.Heading = spl.Proposal__r.Name;
                    proposal.ApplicationDate = spl.Proposal__r.ApplicationDate__c;
                    proposal.PlanningStageDescription = spl.Proposal__r.PlanningStage__c;
                    proposal.PlanningTypeDescription = spl.Proposal__r.PlanningType__c;
                    proposal.ApplicationDescription = spl.Proposal__r.Description__c;
                    eProject.Applications.add(proposal);    
                }
            }
            jsonProjects += '{ "' + operation + '" : { "_index" : "' + elasticIndexName + '", "_type" : "' + elasticItemTypeName + '", "_id" : "' + project.ProjectIdPublish__c + '" } }\n';
            if (operation == 'update'){
                jsonProjects += '{ "doc" : ' + JSON.serialize(eProject) + ' }\n';
            }else{
                jsonProjects += JSON.serialize(eProject) + '\n';
            }
        }
        return jsonProjects;
    }
   
    private class ElasticProject{
        private string ProjectId { get; set; }
        private string Heading { get; set; }
        private string IsArchived { get; set; }
        private decimal Value { get; set; }
        private string ValueType { get; set; }
        private string ProjectSize { get; set; }
        private string ContractType { get; set; }
        private string ContractPeriod { get; set; }
        private string DevelopmentTypeId { get; set; }
        private string ProjectStatusId { get; set; }
        private string EndDateType { get; set; }
        private string StartDateType { get; set; }
        private string ContractStageId { get; set; }
        private string PlanningStageId { get; set; }
        private decimal SiteArea { get; set; }
        private decimal Units { get; set; }
        private decimal Storeys { get; set; }
        private string Address { get; set; }
        private string Borough { get; set; }
        private string County { get; set; }
        private string Postcode { get; set; }
        private string Region { get; set; }
        private string Town { get; set; }
        private decimal Latitude { get; set; }
        private decimal Longitude { get; set; }
        private string LatestInformation { get; set; }
        private string PlanningDescription { get; set; }
        private string NotificationText { get; set; }
        private string TenderInformation { get; set; }
        private string SchemeDescription { get; set; }
        private string FirstPublished { get; set; }
        private string Updated { get; set; }
        private string RecallDate { get; set; }
        private string Funding { get; set; }
        private ElasticBreeam Breeam { get; set; }
        private ElasticCeequal Ceequal { get; set; }
        private List<ElasticSectorGroup> Sectors { get; set; }
        private List<ElasticMaterialGroup> Materials { get; set; }
        private List<ElasticRoleGroup> Roles { get; set; }
        private List<ElasticHistory> Histories { get; set; }
        private List<ElasticProposal> Applications { get; set; }
    }
   
    private class ElasticBreeam{
        private string Test { get; set; } //TODO
    }
  
    private class ElasticCeequal{
        private string Code { get; set; }
        private string ForecastFinalVerification { get; set; }
        private string AwardType { get; set; }
        private string Version { get; set; }
        private string InterimGrade { get; set; }
        private string FinalGrade { get; set; }
        private string InterimPercentage { get; set; }
        private string FinalPercentage { get; set; }
   }
  
   private class ElasticSectorGroup{
        private string Name { get; set; }
        private List<ElasticSector> Sectors { get; set; }       
   }
  
   private class ElasticSector{
        private string Name { get; set; }
        private decimal Priority { get; set; }  
        private boolean IsPrimary { get; set; } 
   }
   
   private class ElasticMaterialGroup{
        private string MaterialGroupName { get; set; }
        private List<ElasticMaterial> Materials { get; set; }
   }
   
   private class ElasticMaterial{
        private string Name { get; set; }
   }
  
   private class ElasticRoleGroup{
        private string RoleGroupDescription { get; set; }
        private List<ElasticRole> Roles { get; set; }       
   }
  
   private class ElasticRole{
        private string Role { get; set; }
        private List<ElasticCompany> Companies { get; set; }
   }
  
   private class ElasticCompany{
        private ElasticOffice OfficeId { get; set; }
        private List<ElasticContact> Contacts { get; set; }
   }
   
   private class ElasticOffice{         
        private string CompanyName { get; set; }
        private string OfficeName { get; set; }
        private string AddressLine1 { get; set; }
        private string Postcode { get; set; }
        private string Town { get; set; }
        private string Region { get; set; }
        private string County { get; set; }
        private string PhoneNumber { get; set; }
        private Decimal Latitude { get; set; }
        private Decimal Longitude { get; set; }
   }
   
   private class ElasticContact{        
        private string Salutation { get; set; }
        private string FirstName { get; set; }
        private string LastName { get; set; }
        private string JobTitle { get; set; }
        private string Email { get; set; }
   }
   
   private class ElasticHistory{
        private string Event { get; set; }
        private DateTime Modified { get; set; }
        private string ModifiedBy { get; set; }
        private string NewValue { get; set; }
        private string OldValue { get; set; }
   }
  
   private class ElasticProposal{
        private string ApplicationNumber { get; set; }
        private boolean IsLatest { get; set; }
        private boolean IsLead { get; set; }
        private string CouncilName { get; set; }
        private ElasticOffice OfficeId { get; set; }
        private string Heading { get; set; }
        private Date ApplicationDate { get; set; }
        private string PlanningStageDescription { get; set; }
        private string PlanningTypeDescription { get; set; }
        private string ApplicationDescription { get; set; }
   }
}