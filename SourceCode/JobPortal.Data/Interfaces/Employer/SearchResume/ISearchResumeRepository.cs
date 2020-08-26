using JobPortal.Data.DataModel.Shared;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Employer.SearchResume
{
    public interface ISearchResumeRepository
    {
        DataTable GetSearchResumeList(SearchResumeModel searches);
        DataTable ShowCandidateDetails(int employerId, int jobSeekerId);
    }
}

