using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Jobseeker
{
    public interface ISearchJobRepository
    {
        DataTable GetSearchJobList(JobSearchModel searches,int UserId);
        void LogSearchJob(string searche, string userip, string location, int userid);
    }
}
