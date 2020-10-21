using JobPortal.Business.Handlers.Auth;
using JobPortal.Business.Interfaces.Auth;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Data.Interfaces.Auth;
using JobPortal.Data.Interfaces.Employer.JobPost;
using JobPortal.Data.Interfaces.Employer.Profile;
using JobPortal.Data.Interfaces.Employer.SearchResume;
using JobPortal.Data.Interfaces.Home;
using JobPortal.Data.Interfaces.Jobseeker;
using JobPortal.Data.Interfaces.Shared;
using JobPortal.Data.Interfaces.TrainingPartner;
using JobPortal.Data.Repositories.Admin;
using JobPortal.Data.Repositories.Auth;
using JobPortal.Data.Repositories.Employer.JobPost;
using JobPortal.Data.Repositories.Employer.Profile;
using JobPortal.Data.Repositories.Employer.SearchResume;
using JobPortal.Data.Repositories.Home;
using JobPortal.Data.Repositories.Jobseeker;
using JobPortal.Data.Repositories.Shared;
using JobPortal.Data.Repositories.TrainingPartner;
using Microsoft.Extensions.Configuration;
using System;

namespace JobPortal.Business.Handlers.DataProcessorFactory
{
    public class ProcessorFactoryResolver<T> : ProcessorFactory<T>
    {
        private readonly IConfiguration config;
        public ProcessorFactoryResolver(IConfiguration configuration)
        {
            config = configuration;
        }
        public override T CreateProcessor()
        {
            switch (typeof(T).Name)
            {
                case "IAuthRepository":
                    IAuthRepository _processor = new AuthRepository(config);
                    return (T)_processor;
                case "IJobPostRepository":
                    IJobPostRepository _jobPostprocessor = new JobPostRepository(config);
                    return (T)_jobPostprocessor;
                case "IHomeRepositories":
                    IHomeRepositories _homeRepositories = new HomeRepositories(config);
                    return (T)_homeRepositories;
                case "ISearchJobRepository":
                    ISearchJobRepository _searchJobRepository = new SearchJobRepository(config);
                    return (T)_searchJobRepository;
                case "IUserProfileRepository":
                    IUserProfileRepository _userProfileRepository = new UserProfileRepository(config);
                    return (T)_userProfileRepository;
                case "ISearchResumeRepository":
                    ISearchResumeRepository _searchResumeRepository = new SearchResumeRepository(config);
                    return (T)_searchResumeRepository;
                case "IManageUserRepository":
                    IManageUserRepository _manageUserRepository = new ManageUsersRepository(config);
                    return (T)_manageUserRepository;
                case "IEmpProfileRepository":
                    IEmpProfileRepository _empProfileRepository = new EmpProfileRepository(config);
                    return (T)_empProfileRepository;
                case "IJobIndustryAreaRepository":
                    IJobIndustryAreaRepository _jobIndustryAreaRepository = new JobIndustryAreaRepositroy(config);
                    return (T) _jobIndustryAreaRepository;
                case "IJobTitleRepositroy":
                    IJobTitleRepositroy _jobTitleRepositroy  = new JobTitleRepository(config);
                    return (T)_jobTitleRepositroy;
                case "IDesignationRepository":
                    IDesignationRepository _designationRepository = new DesignationRepository(config);
                    return (T)_designationRepository;
                case "IResumeBuilderRepository":
                    IResumeBuilderRepository rBuilderRepository = new ResumeBuilderRepository(config);
                    return (T)rBuilderRepository;
                case "IMasterDataRepository":
                    IMasterDataRepository masterDataRepository = new MasterDataRepository(config);
                    return (T)masterDataRepository;
                case "ISuccessStoryVideoRepository":
                    ISuccessStoryVideoRepository successStoryVideoRepository = new SuccessStoryVideoRepository(config);
                    return (T)successStoryVideoRepository;
                case "IBulkJobPostRepository":
                    IBulkJobPostRepository bulkJobRepository = new BulkJobPostRepository(config);
                    return (T)bulkJobRepository;
                case "IEmailRepository":
                    IEmailRepository _emailRepository = new EmailRepository(config);
                    return (T)_emailRepository;
                case "IUsersReviewsRepository":
                    IUsersReviewsRepository usersReviewsRepository = new UsersReviewsRepository(config);
                    return (T)usersReviewsRepository;
                case "IManageJobsRepository":
                    IManageJobsRepository manageJobsRepository = new ManageJobsRepository(config);
                    return (T)manageJobsRepository;
                case "IDashboardRepository":
                    switch (typeof(T).FullName)
                    {
                        case "JobPortal.Data.Interfaces.Employer.IDashboardRepository":
                            Data.Interfaces.Employer.IDashboardRepository employerDashboard = new Data.Repositories.Employer.DashboardRepository(config);
                            return (T)employerDashboard;
                        case "JobPortal.Data.Interfaces.TrainingPartner.IDashboardRepository":
                            Data.Interfaces.TrainingPartner.IDashboardRepository tpDashboard = new Data.Repositories.TrainingPartner.DashboardRepository(config);
                            return (T)tpDashboard;
                        case "JobPortal.Data.Interfaces.Admin.IDashboardRepository":
                            Data.Interfaces.Admin.IDashboardRepository adminDashboard = new Data.Repositories.Admin.DashboardRepository(config);
                            return (T)adminDashboard;
                        default:
                            throw new Exception("Can not create object");
                    }
                case "ITrainingPartnerProfileRepository":
                    ITrainingPartnerProfileRepository trainingPartnerProfileRepository = new TrainingPartnerProfileRepository(config);
                    return (T)trainingPartnerProfileRepository;
                case "IManageCityStateRepository":
                    IManageCityStateRepository manageCityStateRepository = new ManageCityStateRepository(config);
                    return (T)manageCityStateRepository;
                case "INotificationRepository":
                    INotificationRepository nRepository = new NotificationRepository(config);
                    return (T)nRepository;
                case "IPlacedCandidateRepository":
                    IPlacedCandidateRepository placedCandidateRepository = new PlacedCandidateRepository(config);
                    return (T)placedCandidateRepository;
                case "IAdvertisementsRepository":
                    IAdvertisementsRepository advertisementsRepository = new AdvertisementsRepository(config);
                    return (T)advertisementsRepository;
                case "IEmailTemplateRepository":
                    IEmailTemplateRepository emailTemplateRepository = new EmailTemplateRepository(config);
                    return (T)emailTemplateRepository;
                default:                   
                    throw new Exception("Can not create object");
            }
        }
    }
}
