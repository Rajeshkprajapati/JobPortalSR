using JobPortal.Data.DataModel.Shared;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.TrainingPartner
{
    public interface ITrainingPartnerProfileRepository
    {
        DataTable GetTPDetail(int userid);
        bool UpdateTPDetail(UserModel user);
    }
}
