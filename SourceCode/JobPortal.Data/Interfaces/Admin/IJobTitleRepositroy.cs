using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using JobPortal.Data.DataModel.Admin.JobTitle;

namespace JobPortal.Data.Interfaces.Admin
{
   public interface IJobTitleRepositroy
    {
        DataTable GetJobTitle();
        bool InsertUpdateJobTile(JobTitleModel jobTitle);
        bool DeleteJobTitle(string jobTileId, string deletedBy);
    }
}
