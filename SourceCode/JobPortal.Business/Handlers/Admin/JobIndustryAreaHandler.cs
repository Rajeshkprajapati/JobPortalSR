using JobPortal.Business.Interfaces.Admin;
using JobPortal.Business.Handlers.DataProcessorFactory;
using JobPortal.Data.Interfaces.Admin;
using System;
using System.Collections.Generic;
using System.Text;
using Microsoft.Extensions.Configuration;
using System.Data;
using JobPortal.Model.DataViewModel.Admin.JobIndustryArea;
using JobPortal.Data.DataModel.Admin.JobIndustryArea;

namespace JobPortal.Business.Handlers.Admin
{
   public class JobIndustryAreaHandler: IJobIndustryAreaHandler
    {
        private readonly IJobIndustryAreaRepository _jobIndustryAreaHandler;
        public JobIndustryAreaHandler(IConfiguration configuration)
        {
            var factory = new ProcessorFactoryResolver<IJobIndustryAreaRepository>(configuration);
            _jobIndustryAreaHandler = factory.CreateProcessor();
        }
        public List<JobIndustryAreaViewModel> GetJobIndustryAreaList()
        {
            DataTable dt = _jobIndustryAreaHandler.GetJobIndustryArea();
            List<JobIndustryAreaViewModel> jobIndustryAreaList = new List<JobIndustryAreaViewModel>();
            for (int i = 0; i < dt.Rows.Count; i++)
            {
                JobIndustryAreaViewModel jobIndustryArea = new JobIndustryAreaViewModel
                {
                    JobIndustryAreaId = Convert.ToInt32(dt.Rows[i]["JobIndustryAreaId"]),
                    JobIndustryAreaName = Convert.ToString(dt.Rows[i]["JobIndustryAreaName"]),
                    SerialNo = Convert.ToString(dt.Rows[i]["SerialNo"]),
                };
                jobIndustryAreaList.Add(jobIndustryArea);
            }
            return (jobIndustryAreaList);
        }
        public bool UpdateJobIndustryArea(JobIndustryAreaViewModel jobIndustryAreaViewModel)
        {
            JobIndustryAreaModel jobIndustryArea = new JobIndustryAreaModel
            {
                JobIndustryAreaId = jobIndustryAreaViewModel.JobIndustryAreaId,
                JobIndustryAreaName = jobIndustryAreaViewModel.JobIndustryAreaName,
            };
            var result = _jobIndustryAreaHandler.UpdateJobIndustryArea(jobIndustryArea);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to update data");
        }
        public bool DeleteJobIndustryArea(string jobIndustryAreaId, string deletedBy)
        {
            var result = _jobIndustryAreaHandler.DeleteJobIndustryArea(jobIndustryAreaId, deletedBy);
            if (result)
            {
                return true;
            }
            throw new Exception("Unable to delete data");
        }
    }
}
