using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.TrainingPartner
{
    public interface IDashboardRepository
    {
        DataTable GetCandidates(int tpId);
        DataTable GetCandidateDetails(int userid);
        bool DeleteCandidate(int userid);
        bool UpdateCandidateDetails(UserModel model);
    }
}
