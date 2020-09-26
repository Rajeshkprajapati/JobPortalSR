using System;
using System.Collections.Generic;
using System.Text;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Data.Interfaces.Admin;
using System.Data;
using Microsoft.Extensions.Configuration;
using JobPortal.Data.DataModel.Admin.JobTitle;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Data.Interfaces.Shared;
using JobPortal.Data.DataModel.Admin.JobIndustryArea;

namespace JobPortal.Business.Handlers.Admin
{
    public class JobTitleHandler:IJobTitleHandler
    {
        private readonly IJobTitleRepositroy jobTitleRepositroy;
        private readonly IMasterDataRepository masterRepository;
        public JobTitleHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IJobTitleRepositroy>(configuration);
            jobTitleRepositroy = factory.CreateProcessor();
            var masterFactory = new ProcessorFactoryResolver<IMasterDataRepository>(configuration);
            masterRepository = masterFactory.CreateProcessor();
        }
        public List<JobTitleViewModel> GetJobTitle()
        {
            DataTable dt = masterRepository.GetJobRoles();
            List<JobTitleViewModel> jobTitlesList = new List<JobTitleViewModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                JobTitleViewModel jobTitles = new JobTitleViewModel()
                {
                    JobTitleId = Convert.ToInt32(dt.Rows[i]["JobTitleId"]),
                    JobTitleName = Convert.ToString(dt.Rows[i]["JobTitleName"]),
                    JobIndustryAreaId = Convert.ToInt32(dt.Rows[i]["JobIndustryAreaId"])
                };
                jobTitlesList.Add(jobTitles);
            }
            return (jobTitlesList);
        }
        public bool InsertUpdateJobTile(JobTitleViewModel jobTitleViewModel)
        {
            JobTitleModel jobTitle = new JobTitleModel
            {
                JobTitleId = jobTitleViewModel.JobTitleId,
                JobTitleName = jobTitleViewModel.JobTitleName,
                JobIndustryAreaId = jobTitleViewModel.JobIndustryAreaId,
                UpdatedBy = jobTitleViewModel.UpdatedBy
            };
            var result = jobTitleRepositroy.InsertUpdateJobTile(jobTitle);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to update data");
        }
        public bool DeleteJobTitle(string jobTileId, string deletedBy)
        {
            var result = jobTitleRepositroy.DeleteJobTitle(jobTileId, deletedBy);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to delete data");
        }

        public List<JobIndustryAreaModel> JobIndustryArea()
        {
            DataTable dt = masterRepository.JobIndustryArea();
            List<JobIndustryAreaModel> jobIndustryArea = new List<JobIndustryAreaModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                JobIndustryAreaModel JobIndustry = new JobIndustryAreaModel()
                {
                    JobIndustryAreaId = Convert.ToInt32(dt.Rows[i]["JobIndustryAreaId"]),
                    JobIndustryAreaName = Convert.ToString(dt.Rows[i]["JobIndustryAreaName"]),
                };
                jobIndustryArea.Add(JobIndustry);
            }
            return (jobIndustryArea);
        }
    }
}
