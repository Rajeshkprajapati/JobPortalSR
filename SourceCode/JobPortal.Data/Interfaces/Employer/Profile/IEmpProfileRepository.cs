using JobPortal.Data.DataModel.Shared;
using JobPortal.Model.DataViewModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Employer.Profile
{
    public interface IEmpProfileRepository
    {
        DataTable GetEmpUserDetails(int userId);
        bool InsertUpdateEmpDetails(UserModel model);
    }
}
