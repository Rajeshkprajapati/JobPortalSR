using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using JobPortal.Data.DataModel.Admin.JobIndustryArea;


namespace JobPortal.Data.Interfaces.Admin
{
   public interface IJobIndustryAreaRepository
    {
        DataTable GetJobIndustryArea();
        bool UpdateJobIndustryArea(JobIndustryAreaModel jobIndustry);
        bool DeleteJobIndustryArea(string jobIndustryAreaId,string deletedBy);
    }
}
