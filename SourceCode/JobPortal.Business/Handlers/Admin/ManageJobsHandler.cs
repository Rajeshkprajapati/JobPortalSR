using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Data.Interfaces.Admin;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Handlers.Admin
{
    public class ManageJobsHandler : IManageJobsHandler
    {
        private readonly IManageJobsRepository manageJobsRepository;
        public ManageJobsHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IManageJobsRepository>(configuration);
            manageJobsRepository = factory.CreateProcessor();
        }
        public bool UpdateFeaturedJobDisplayOrder(int jobpostid,int displayorder)
        {
            bool result = false;
            try
            {
                result = manageJobsRepository.UpdateFeaturedJobDisplayOrder(jobpostid,displayorder);
            }
            catch (Exception ex)
            {
                result = false;
            }
            return result;
        }
        public bool DeleteFeaturedJob(int jobpostid)
        {
            bool result = false;
            try
            {
                result = manageJobsRepository.DeleteFeaturedJob(jobpostid);
            }
            catch (Exception ex)
            {
                result = false;
            }
            return result;
        }
    }
}
